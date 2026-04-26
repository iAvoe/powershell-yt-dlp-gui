Function badinputwarning {Write-Warning "`r`n×Bad input, try again"}

Function whereisit($startPath='DESKTOP', [string]$Filter="EXE Files |*.exe", [string]$WindowTitle) {
    #Enabling System.Windows.Forms file selection Windows Form GUI，using SelectedPath to locate Desktop
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
    Add-Type -AssemblyName System.Windows.Forms
    $startPath = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('DESKTOP')
        Filter = $Filter
        Title = $WindowTitle
    }
    Do {$dInput = $startPath.ShowDialog()} While ($dInput -eq "Cancel") #Open this Windows Form GUI, re-open if user clicks "Close/Cancel"
    return $startPath.FileName
}
Function whichlocation($startPath='DESKTOP', [string]$Message="Select directory. drag border to resize") {
    #System.Windows.Forms directory selection Windows Form GUI
    Add-Type -AssemblyName System.Windows.Forms
    $startPath = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        Description=$Message
        SelectedPath=[Environment]::GetFolderPath($startPath)
        RootFolder='MyComputer'
        ShowNewFolderButton=$true
    }#Open this Windows Form GUI, re-open if user clicks "Close/Cancel"
    Do {$dInput = $startPath.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost=$true}))} While ($dInput -eq "Cancel") #Small window - enabling TopMost property, though it may not work
    #Selecting root directory returns a path with ending "\", yet branch directories returns a path without ending "\", therefore an auto string compensation is needed
    if (($startPath.SelectedPath.SubString($startPath.SelectedPath.Length-1) -eq "\") -eq $false) {$startPath.SelectedPath+="\"}
    return $startPath.SelectedPath
}

# First do DPI aware setting to get correct window size
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();      
}
'@
$null = [ProcessDPI]::SetProcessDPIAware()

Function Read-MultiLineInputDialog([string]$WindowTitle, [string]$Message, [string]$InboxType="txt", [int]$FontSize=12, [string]$ReturnType="str", [bool]$ShowDebug=$false) {
    $DebugPreference = 'Continue'
    
    # Use SystemInformation instead of WMI (gwmi), which is unstable
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    [int]$mWidth  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
    [int]$mHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
    
    if ($ShowDebug) { Write-Debug "√ Resolution: $mWidth x $mHeight" }

    # Window size processing
    [int]$LBStartX = [math]::Round($mWidth /192)
    [int]$LBStartY = [math]::Round($mHeight/108)
    [int]$LblSizeX = [math]::Round($mWidth /19)
    [int]$LblSizeY = [math]::Round($mHeight/54)

    $label = New-Object System.Windows.Forms.Label -Property @{
        AutoSize = $true
        Text     = $Message
        Location = New-Object System.Drawing.Size($LBStartX,$LBStartY)
        Size     = New-Object System.Drawing.Size($LblSizeX,$LblSizeY)
    }

    [int]$LBStartX = [int]$TBStartX = [math]::Round($mWidth /192)
    [int]$LBStartY = [int]$TBStartY = [math]::Round($mHeight/27)
    [int]$TblSizeX = [math]::Round($mWidth /3.728)
    [int]$LblSizeX = [math]::Round($mWidth /3.792)
    [int]$LblSizeY = [int]$TblSizeY = [math]::Round($mHeight/2.6)
    
    # 移除针对 consolehost 的硬编码补偿，因为 DPIAware 已经处理了缩放
    if (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        $textBox = New-Object System.Windows.Forms.TextBox -Property @{
            Location      = New-Object System.Drawing.Size($TBStartX,$TBStartY)
            Size          = New-Object System.Drawing.Size($TblSizeX,$TblSizeY)
            Font          = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,$FontSize)
            AcceptsReturn = $true
            AcceptsTab    = $false
            Multiline     = $true
            ScrollBars    = 'Both'
            Text          = ""
        }
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        $listBox = New-Object Windows.Forms.ListBox -Property @{
            Location            = New-Object System.Drawing.Size($LBStartX,$LBStartY)
            Size                = New-Object System.Drawing.Size($LblSizeX,$LblSizeY)
            Font                = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,$FontSize)
            Anchor              = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top)
            AutoSize            = $true
            IntegralHeight      = $false
            AllowDrop           = $true
            ScrollAlwaysVisible = $false
        }
        $listBox_DragOver = [System.Windows.Forms.DragEventHandler]{
            if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {$_.Effect = 'Copy'} else {$_.Effect = 'None'}
        }
        $listBox_DragDrop = [System.Windows.Forms.DragEventHandler]{
            foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) {$listBox.Items.Add($filename)}
        }
        $listBox.Add_KeyDown({
            if (($PSItem.KeyCode -eq "Delete") -and ($listBox.Items.Count -gt 0)) {$listBox.Items.Remove($listBox.SelectedItems[0])}
        })
    }

    [int]$OKStartX = [math]::Round($mWidth /4.7)
    [int]$OKStartY = [math]::Round($mHeight/108)
    [int]$OKbSizeX = [math]::Round($mWidth /34.92)
    [int]$OKbSizeY = [math]::Round($mHeight/47)

    $okButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Size($OKStartX,$OKStartY)
        Size         = New-Object System.Drawing.Size($OKbSizeX,$OKbSizeY)
        DialogResult = [System.Windows.Forms.DialogResult]::OK
        Text         = "OK"
    }
    if (($InboxType -eq "txt") -or ($InboxType -eq "1")) {$okButton.Add_Click({$form.Tag = $textBox.Text;  $form.Close()})}
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {$okButton.Add_Click({$form.Tag = $listBox.Items; $form.Close()})}

    [int]$ClStartX = [math]::Round($mWidth /4.08)
    [int]$ClStartY = $OKStartY
    [int]$ClbSizeX = $OKbSizeX
    [int]$ClbSizeY = $OKbSizeY

    $cancelButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Size($ClStartX,$ClStartY)
        Size         = New-Object System.Drawing.Size($ClbSizeX,$ClbSizeY)
        Text         = "Cancel"
        DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    }
    $cancelButton.Add_Click({$form.Tag = $null; Try{$listBox.Items.Clear()}Catch {}; $form.Close()})

    [int]$formSizeX = [math]::Round($mWidth /3.56)
    [int]$formSizeY = [math]::Round($mHeight/2.18)

    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = $WindowTitle
        Size = New-Object System.Drawing.Size($formSizeX,$formSizeY)
        FormBorderStyle = 'FixedSingle'
        StartPosition = "CenterScreen"
        AutoSizeMode = 'GrowAndShrink'
        Topmost = $false
        AcceptButton = $okButton
        CancelButton = $cancelButton
        ShowInTaskbar = $true
    }

    $form.Controls.Add($label); $form.Controls.Add($okButton); $form.Controls.Add($cancelButton)
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

    $form.Add_Shown({$form.Activate()})
    $form.Add_KeyDown({
        if ($PSItem.KeyCode -eq "Escape") {$cancelButton.PerformClick()}
    })

    $form.ShowDialog() | Out-Null

    if ((($InboxType -eq "txt")-or($InboxType -eq "1")) -and ($textBox.Text -eq "")) {
        if (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ""}
        if (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return $null}
    }
    elseif ((($InboxType -eq "dnd")-or($InboxType -eq "2")) -and ($listBox.Items.Count -eq 0)) {
        if (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ""}
        if (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return $null}
    }

    # Return processed data
    if ($null -eq $form.Tag) { return $null }
    [array]$ScrbDiagRslt = ($form.Tag.ToString().Split("`r`n")).Trim() | where {$_ -ne ""}
    if (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ($ScrbDiagRslt -join "`r`n")}
    elseif (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return $ScrbDiagRslt}
}





clear

Write-Host "Short link can result in download failure.`nRecommending to open all short links, and then bulk copy the full link with tools like [github.com/EuanRiggans/BulkURLOpener].`n"

$link=""
Do {($link = Read-MultiLineInputDialog -Message "★ Paste all your downloading links，separated by line-breaks" -WindowTitle "★ yt-dlp-ops-en Downloading input box" -DefaultText "")
    if (($link -notmatch "http") -and ($link -notmatch "=") -and ($link -notmatch "ftp") -and ($link -notmatch "localhost")) {badinputwarning} else {"`r`n√ Line 223: Determining input as normal video link"}
} While ($link -eq "") #Continue executing even unusal input was detected

Do {$DownloadPath = whichlocation -Message "Select[Download Path]";         $DownloadPath
    $ytdlpAppPath = ((Get-Location).ToString()+"\yt-dlp.exe")                             #Initial yt-dlp downloader path - under the same directory as yt-dlp
    if ((Test-Path -Path $ytdlpAppPath -PathType Leaf) -eq $false) {                      #If yt-dlp.exe is not found as above, start a selecting task
        whereisit -WindowTitle "Locate [yt-dlp.exe]"
        Write-Host "You can skip this by placing this script in the same path as yt-dlp"
    };                                                                      $ytdlpAppPath
    $CmdPrintPath = whichlocation -Message "Select[Script Exporting Path]"; $CmdPrintPath #Path for exporting batch script
    ""
    if (Test-Path $DownloadPath) {Write-Host "√ yt-dlp.exe path is valid"}     else {Write-Error "× yt-dlp.exe path is invalid";     pause; exit}
    if (Test-Path $ytdlpAppPath) {Write-Host "√ Video download path is valid"} else {Write-Error "× Video download path is invalid"; pause; exit}
    if (Test-Path $CmdPrintPath) {Write-Host "√ Batch export path is valid"}   else {Write-Error "× Batch export path is invalid";   pause; exit}
    ""
} While ((Test-Path $ytdlpAppPath) + (Test-Path $DownloadPath) + (Test-Path $CmdPrintPath) -ne 3) #$true+$true+$true=3

$audioOnly = $false
$audioFormat = ""
Switch (Read-Host "`nInput `"y`" to [Only download audio], otherwise press Enter to download entire video") {
    y {
        $audioOnly = $true
        Write-Host "√ Only download audio"
    }
    Default { Write-Host "√ Download video with audio" }
}

$CookieIOPath = $DownloadPath+"ytdlpCookies.txt"                                          #Export & later importing path for cookies, since yt-dlp with cookie tends to success

$brwsrSelect=$cookieExp=""
Switch (Read-Host "Input `"y`" to add procedure for [Export current browser cookie] for website logged-user identification, or hit Enter to skip") {
    y {
        $brwsrSelect = Switch (Read-Host "`r`nSelect the browser that has your account Cookie (previous logged in to the video platform):
    [A: Chrome | B: Brave | C: Chromium | E: Edge | F: Firefox | O: Opera | S: Safari | V: Vivaldi]") {
           a {"Chrome"} b {"Brave"} c {"Chromium"} o {"Opera"}
           e {"Edge"} f {"Firefox"} s {"Safari"} v {"Vivaldi"} default {"Chromium"}
       }
       #Build commandlines for yt-dlp to write cookies
       $cookieExp = "$ytdlpAppPath --ignore-errors --cookies-from-browser $brwsrSelect --cookies $CookieIOPath"
       Write-Output "`r`n！There will be a Cookie-exporting commadline which triggers an error in yt-dlp, please ignore that`n"
    }
    Default {"√ Skipped"}
}

$cookieImp = "--cookies $CookieIOPath" #Build command for yt-dlp to read cookies, which will be added to each downloading command later
$CmdPrint = $CmdPrintPath+"yt-dlp-download.bat"; "`r`nExporting Batch Script at：$CmdPrint" #Completing and noticing user about the script file that is being generated
#Clear previously generated file, it may not exist which gives an error when trying to delete
#Because of the usage of append writing ">>" an detect-&-delete procedure is required to clear, othervise new files will be appended into the old file
if (Test-Path $CmdPrint) {Remove-Item $CmdPrint}

$ctrl_gen = @()
$ctrl_gen += "
chcp 65001

@echo off"
if ($brwsrSelect -ne "") {
    $ctrl_gen+="
@ECHO Generating Cookies to $CookieIOPath"
    $ctrl_gen+=$cookieExp
} #Write cookie exporting commandline to batch script

$ctrl_gen += "
@ECHO Downloading videos with random gaps inbetween each task"
$link.Split("`r`n").Trim() | where {$_ -ne ""} | ForEach-Object {
    $ctrl_gen+="timeout /nobreak /t "+(Get-Random -InputObject 1,2,3,4,5,6,7).ToString()

    # Build commandline based on user's selection (audio only or not)
    if ($audioOnly) {
        # Audio only
        $ctrl_gen+="$ytdlpAppPath --newline --ignore-errors -x --audio-format best --no-keep-video -o `"$DownloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieImp "
    }
    else {
        # Video with audio
        $ctrl_gen+="$ytdlpAppPath --newline --ignore-errors -o `"$DownloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieImp "
    }
}

$ctrl_gen += "
pause
"
$utf8NoBOM=New-Object System.Text.UTF8Encoding $false #Exporting utf-8NoBOM coded text file
[IO.File]::WriteAllLines($CmdPrint, $ctrl_gen, $utf8NoBOM)
Write-Output "`r`nDone, exprted batch script as $CmdPrint, run by double-clicking it`r`n"

pause