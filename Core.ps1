# UTF-8 No BOM
if (-not ('System.Windows.Forms.Form' -as [type])) {
    Add-Type -AssemblyName System.Windows.Forms
}
if (-not ('System.Drawing.Point' -as [type])) {
    Add-Type -AssemblyName System.Drawing
}

# WinAPI P/Invoke for console window focus management
if (-not ('WinAPI' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class WinAPI {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
}

# DPI awareness for proper high-DPI display of WinForms dialogs
if (-not ('ProcessDPI' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;

public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();
}
'@
}
$null = [ProcessDPI]::SetProcessDPIAware()

# UTF-8 encodings
$Global:utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
$Global:utf8BOM = New-Object System.Text.UTF8Encoding($true)

function Show-Error {
    param([Parameter(Mandatory = $true)]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Show-Warning {
    param([Parameter(Mandatory = $true)]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Show-Success {
    param([Parameter(Mandatory = $true)]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Show-Debug {
    param([Parameter(Mandatory = $true)]$Message)
    Write-Host $Message -ForegroundColor DarkGray
}

function Select-File(
        [string]$Title = "Select file",
        [string]$InitialDirectory = [Environment]::GetFolderPath('Desktop'),
        [switch]$ScriptOnly,
        [switch]$ExeOnly,
        [switch]$DllOnly,
        [switch]$IniOnly,
        [switch]$BatOnly
    ) {
    Write-Host " Command window may lose focus; click it to restore input" -ForegroundColor DarkGray

    if ($InitialDirectory) {
        if (Test-Path -LiteralPath $InitialDirectory -PathType Leaf) {
            $InitialDirectory = Split-Path -LiteralPath $InitialDirectory -Parent
        }
        if (-not (Test-Path -LiteralPath $InitialDirectory -PathType Container)) {
            $InitialDirectory = [Environment]::GetFolderPath('Desktop')
        }
    }
    else {
        $InitialDirectory = [Environment]::GetFolderPath('Desktop')
    }

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.InitialDirectory = $InitialDirectory
    $dialog.Multiselect = $false
    $dialog.Filter = if ($ScriptOnly) { 'Script files (*.avs, *.vpy)|*.avs;*.vpy' }
        elseif ($ExeOnly) { 'exe files (*.exe)|*.exe' }
        elseif ($DllOnly) { 'dll files (*.dll)|*.dll' }
        elseif ($IniOnly) { 'ini files (*.ini)|*.ini' }
        elseif ($BatOnly) { 'bat Files (*.bat)|*.bat' }
        else { 'All files (*.*)|*.*' }

    $form = New-Object System.Windows.Forms.Form
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.WindowState = 'Minimized'

    while ($true) {
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.FileName
        }

        $hwnd = [WinAPI]::GetConsoleWindow()
        [WinAPI]::SetForegroundWindow($hwnd) | Out-Null

        if ('q' -eq (Read-Host "No file selected. Press Enter to retry or type 'q' to quit")) {
            exit 1
        }
    }
}

function Select-Folder(
        [string]$Description = "Select folder",
        [string]$InitialPath = [Environment]::GetFolderPath('Desktop')
    ) {
    Write-Host " Command window may lose focus; click it to restore input" -ForegroundColor DarkGray

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.SelectedPath = $InitialPath
    $dialog.ShowNewFolderButton = $true

    $form = New-Object System.Windows.Forms.Form
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.WindowState = 'Minimized'

    while ($true) {
        $result = $dialog.ShowDialog($form)

        $hwnd = [WinAPI]::GetConsoleWindow()
        [WinAPI]::SetForegroundWindow($hwnd) | Out-Null

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $path = $dialog.SelectedPath
            if (-not $path.EndsWith('\')) {
                $path += '\'
            }
            return $path
        }

        if ((Read-Host "No folder selected. Press Enter to retry or type 'q' to quit") -eq 'q') {
            exit 1
        }
    }
}

function Read-MultiLineInputDialog(
        [string]$WindowTitle,
        [string]$Message,
        [string]$InboxType = "txt",
        [int]$FontSize = 12,
        [string]$ReturnType = "str",
        [bool]$ShowDebug = $false,
        [string]$DefaultText = ""
    ) {
    $DebugPreference = 'Continue'

    [int]$mWidth  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
    [int]$mHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height

    if ($ShowDebug) { Write-Debug "Resolution: $mWidth x $mHeight" }

    [int]$LBStartX = [math]::Round($mWidth / 192)
    [int]$LBStartY = [math]::Round($mHeight / 108)
    [int]$LblSizeX = [math]::Round($mWidth / 19)
    [int]$LblSizeY = [math]::Round($mHeight / 54)

    $label = New-Object System.Windows.Forms.Label -Property @{
        AutoSize = $true
        Text     = $Message
        Location = New-Object System.Drawing.Size($LBStartX, $LBStartY)
        Size     = New-Object System.Drawing.Size($LblSizeX, $LblSizeY)
    }

    [int]$LBStartX = [int]$TBStartX = [math]::Round($mWidth / 192)
    [int]$LBStartY = [int]$TBStartY = [math]::Round($mHeight / 27)
    [int]$TblSizeX = [math]::Round($mWidth / 3.728)
    [int]$LblSizeX = [math]::Round($mWidth / 3.792)
    [int]$LblSizeY = [int]$TblSizeY = [math]::Round($mHeight / 2.6)

    if (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        $textBox = New-Object System.Windows.Forms.TextBox -Property @{
            Location      = New-Object System.Drawing.Size($TBStartX, $TBStartY)
            Size          = New-Object System.Drawing.Size($TblSizeX, $TblSizeY)
            Font          = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name, $FontSize)
            AcceptsReturn = $true
            AcceptsTab    = $false
            Multiline     = $true
            ScrollBars    = 'Both'
            Text          = $DefaultText
        }
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        $listBox = New-Object Windows.Forms.ListBox -Property @{
            Location            = New-Object System.Drawing.Size($LBStartX, $LBStartY)
            Size                = New-Object System.Drawing.Size($LblSizeX, $LblSizeY)
            Font                = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name, $FontSize)
            Anchor              = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top)
            AutoSize            = $true
            IntegralHeight      = $false
            AllowDrop           = $true
            ScrollAlwaysVisible = $false
        }
        $listBox_DragOver = [System.Windows.Forms.DragEventHandler]{
            if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = 'Copy' } else { $_.Effect = 'None' }
        }
        $listBox_DragDrop = [System.Windows.Forms.DragEventHandler]{
            foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) { $listBox.Items.Add($filename) }
        }
        $listBox.Add_KeyDown({
            if (($PSItem.KeyCode -eq "Delete") -and ($listBox.Items.Count -gt 0)) { $listBox.Items.Remove($listBox.SelectedItems[0]) }
        })
    }

    [int]$OKStartX = [math]::Round($mWidth / 4.7)
    [int]$OKStartY = [math]::Round($mHeight / 108)
    [int]$OKbSizeX = [math]::Round($mWidth / 34.92)
    [int]$OKbSizeY = [math]::Round($mHeight / 47)

    $okButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Size($OKStartX, $OKStartY)
        Size         = New-Object System.Drawing.Size($OKbSizeX, $OKbSizeY)
        DialogResult = [System.Windows.Forms.DialogResult]::OK
        Text         = "OK"
    }

    [int]$ClStartX = [math]::Round($mWidth / 4.08)
    [int]$ClStartY = $OKStartY
    [int]$ClbSizeX = $OKbSizeX
    [int]$ClbSizeY = $OKbSizeY

    $cancelButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Size($ClStartX, $ClStartY)
        Size         = New-Object System.Drawing.Size($ClbSizeX, $ClbSizeY)
        Text         = "Cancel"
        DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    }

    [int]$formSizeX = [math]::Round($mWidth / 3.56)
    [int]$formSizeY = [math]::Round($mHeight / 2.18)

    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = $WindowTitle
        Size = New-Object System.Drawing.Size($formSizeX, $formSizeY)
        FormBorderStyle = 'FixedSingle'
        StartPosition = "CenterScreen"
        AutoSizeMode = 'GrowAndShrink'
        Topmost = $false
        AcceptButton = $okButton
        CancelButton = $cancelButton
        ShowInTaskbar = $true
    }

    if (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        $okButton.Add_Click({ $form.Tag = $textBox.Text; $form.Close() })
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        $okButton.Add_Click({ $form.Tag = $listBox.Items; $form.Close() })
    }

    $cancelButton.Add_Click({ $form.Tag = $null; try { $listBox.Items.Clear() } catch {}; $form.Close() })

    $form.Controls.Add($label)
    $form.Controls.Add($okButton)
    $form.Controls.Add($cancelButton)
    if (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        $form.Controls.Add($textBox)
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        $form.Controls.Add($listBox)
        $form_FormClosed = {
            try {
                $listBox.remove_DragOver($listBox_DragOver)
                $listBox.remove_DragDrop($listBox_DragDrop)
            } catch {}
        }
        $listBox.Add_DragOver($listBox_DragOver)
        $listBox.Add_DragDrop($listBox_DragDrop)
        $form.Add_FormClosed($form_FormClosed)
    }

    $form.Add_Shown({ $form.Activate() })
    $form.Add_KeyDown({
        if ($PSItem.KeyCode -eq "Escape") { $cancelButton.PerformClick() }
    })

    $form.ShowDialog() | Out-Null

    if ((($InboxType -eq "txt") -or ($InboxType -eq "1")) -and ($textBox.Text -eq "")) {
        if (($ReturnType -eq "str") -or ($ReturnType -eq "1")) { return "" }
        if (($ReturnType -eq "ary") -or ($ReturnType -eq "2")) { return $null }
    }
    elseif ((($InboxType -eq "dnd") -or ($InboxType -eq "2")) -and ($listBox.Items.Count -eq 0)) {
        if (($ReturnType -eq "str") -or ($ReturnType -eq "1")) { return "" }
        if (($ReturnType -eq "ary") -or ($ReturnType -eq "2")) { return $null }
    }

    if ($null -eq $form.Tag) { return $null }
    [array]$dialogResults = ($form.Tag.ToString().Split("`r`n")).Trim() | Where-Object { $_ -ne "" }
    if (($ReturnType -eq "str") -or ($ReturnType -eq "1")) { return ($dialogResults -join "`r`n") }
    elseif (($ReturnType -eq "ary") -or ($ReturnType -eq "2")) { return $dialogResults }
}

# Write UTF-8 text with CRLF line endings.
function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [bool]$UseBOM = $true
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Show-Error "Write-TextFile - write failed: empty path"
        return
    }
    if ([string]::IsNullOrWhiteSpace($Content)) {
        Show-Error "Write-TextFile - write failed: empty content"
        return
    }

    $normalizedContent = $Content -replace "`r?`n", "`r`n"
    $encoding = if ($UseBOM) { $Global:utf8BOM } else { $Global:utf8NoBOM }

    [System.IO.File]::WriteAllText($Path, $normalizedContent, $encoding)
    Show-Debug "Encoding: $($encoding.EncodingName), line ending: CRLF"
    Show-Success "File written: $Path"
}

# Validate CRLF-only text files.
function Test-TextFileFormat {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Show-Error "File not found: $Path"
        return $false
    }

    try {
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)

        $hasUnixLF = $content -match "(?<!`r)`n"
        if ($hasUnixLF) {
            Write-Host "Detected Unix (LF) line endings"
        }
        $hasMacCR = $content -match "`r(?!`n)"
        if ($hasMacCR) {
            Write-Host "Detected Mac (CR) line endings"
        }

        $crCount = ($content -split "`r").Count - 1
        $lfCount = ($content -split "`n").Count - 1
        if ($crCount -ne $lfCount) {
            Show-Warning "CR($crCount) and LF($lfCount) counts differ; execution may break"
        }

        $isValid = (-not $hasUnixLF) -and (-not $hasMacCR) -and ($crCount -eq $lfCount)
        if ($isValid) {
            Show-Success "File format is valid (CRLF: $crCount)"
        }
        else {
            Show-Warning "File format is invalid"
        }
        return $isValid
    }
    catch {
        Show-Error $_
        return $false
    }
}

# Detect JavaScript Runtime and return "name:full-path" for yt-dlp --js-runtimes
function Get-JSRuntimeParam {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        return "node:$($nodeCmd.Source)"
    }

    $denoCmd = Get-Command deno -ErrorAction SilentlyContinue
    if ($denoCmd) {
        return "deno:$($denoCmd.Source)"
    }

    $quickjsCmd = Get-Command quickjs -ErrorAction SilentlyContinue
    if ($quickjsCmd) {
        return "quickjs:$($quickjsCmd.Source)"
    }

    Write-Error "JavaScript runtime not found. Please install Deno (recommended), Node.js or QuickJS
    https://github.com/yt-dlp/yt-dlp/wiki/EJS#deno
    https://github.com/yt-dlp/yt-dlp/wiki/EJS#node
    https://github.com/yt-dlp/yt-dlp/wiki/EJS#quickjs--quickjs-ng
    "
    exit 1
}

# Get cookie parameter for yt-dlp.
function Get-CookiesFromBrowserParam {
    param([Parameter()][string]$langCode = "en")
    $prompts = Switch ($langCode) {
        zh {
            @("输入 y 以添加浏览器 cookie 参数，或按 Enter 跳过",
            "`r`n选择之前登录过视频平台，含账户 Cookie 的浏览器:`r`n [A: Chrome | B: Brave | C: Chromium | E: Edge | F: Firefox | O: Opera | S: Safari | V: Vivaldi]",
            "✓ 跳过")
        }
        Default {
            @("Input 'y' to add browser cookie parameter, or hit Enter to skip",
            "`r`nSelect the browser that has your account Cookie:`r`n [A: Chrome | B: Brave | C: Chromium | E: Edge | F: Firefox | O: Opera | S: Safari | V: Vivaldi]",
            "✓ Skipped")
        }
    }

    $cookieParam = ""
    Switch (Read-Host $prompts[0]) {
        y {
            $browser = Switch (Read-Host $prompts[1]) {
                a { "Chrome" } b { "Brave" } c { "Chromium" } o { "Opera" }
                e { "Edge" } f { "Firefox" } s { "Safari" } v { "Vivaldi" } default { "Chromium" }
            }
            $cookieParam = "--cookies-from-browser $browser"
        }
        Default {
            Write-Output $prompts[2]
            return ""
        }
    }

    return $cookieParam
}
