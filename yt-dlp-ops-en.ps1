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
Function Read-MultiLineInputDialog([string]$WindowTitle, [string]$Message, [string]$InboxType="txt", [int]$FontSize=12, [string]$ReturnType="str", [bool]$ShowDebug=$false) {#「@Daniel Schroeder」
    #-WindowTitle "Str Value"  == Title of the prompt window
    #-Message     "Str Value"  == Prompt text shown above textbox and below title box
    #-InboxType   "1" / "txt"  == Default MultiLine Input Dialog
    #-InboxType   "2" / "dnd"  == Drag & Drop MultiLine Path Input Dialog
    #-FontSize    (Default 12) == Default textbox font size
    #-ReturnType  "1" / "str"  == Return a multi-line string of items, empty lines are scrubbed
    #-ReturnType  "2" / "ary"  == Return an array of items, empty array items are scrubbed
    $DebugPreference = 'Continue'
    if (($host.name -match 'consolehost')) {
        if ($ShowDebug -eq $true) {Write-Debug "√ Running inside PowerShell Console, using resolution data from GWMI"}
        $oWidth  = gwmi win32_videocontroller | select-object CurrentHorizontalResolution -first 1
        $oHeight = gwmi win32_videocontroller | select-object CurrentVerticalResolution -first 1
        [int]$mWidth  = [Convert]::ToInt32($oWidth.CurrentHorizontalResolution)
        [int]$mHeight = [Convert]::ToInt32($oHeight.CurrentVerticalResolution)
        #Write-Debug "√ $mWidth x $mHeight"
    }
    else {
        if ($ShowDebug -eq $true) {Write-Debug "√ Running inside PowerShell ISE, using resolution data from SysInfo"}
        [int]$mWidth  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
        [int]$mHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
    }
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms

    #Converting from monitor resolution: position of window label text
    [int]$LBStartX = [math]::Round($mWidth /192)
    [int]$LBStartY = [math]::Round($mHeight/108)
    [int]$LblSizeX = [math]::Round($mWidth /19)
    [int]$LblSizeY = [math]::Round($mHeight/54)
    #Label text under the GUI title, with content from $Message
    $label = New-Object System.Windows.Forms.Label -Property @{
        AutoSize = $true
        Text     = $Message
        Location = New-Object System.Drawing.Size($LBStartX,$LBStartY) #Label text starting position
        Size     = New-Object System.Drawing.Size($LblSizeX,$LblSizeY) #Label text box size
    }
    #Converting from monitor resolution: position & size of input textbox & listbox
    [int]$LBStartX = [int]$TBStartX = [math]::Round($mWidth /192)
    [int]$LBStartY = [int]$TBStartY = [math]::Round($mHeight/27)
    [int]$TblSizeX = [math]::Round($mWidth /3.728)
    [int]$LblSizeX = [math]::Round($mWidth /3.792)
    [int]$LblSizeY = [int]$TblSizeY = [math]::Round($mHeight/2.6)
    if (($host.name -match 'consolehost')) {$TblSizeX-=3; $LblSizeX-=3} #Compensate width rendering difference in PowerShell Console
    
    #Drawing textbox 1 / listbox 2
    if     (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        $textBox               = New-Object System.Windows.Forms.TextBox -Property @{
            Location      = New-Object System.Drawing.Size($TBStartX,$TBStartY) #Draw starting postiton
            Size          = New-Object System.Drawing.Size($TblSizeX,$TblSizeY) #Size of textbox
            Font          = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,$FontSize)
            AcceptsReturn = $true
            AcceptsTab    = $false
            Multiline     = $true
            ScrollBars    = 'Both'
            Text          = "" #Leave default text blank in order to check if user has typed / pasted nothing and (accidentally) clicks OK, which can mitigated userby Do-While loop checking and prevents a script startover of frustration
        }
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        $listBox = New-Object Windows.Forms.ListBox -Property @{
            Location            = New-Object System.Drawing.Size($LBStartX,$LBStartY) #Draw starting postiton
            Size                = New-Object System.Drawing.Size($LblSizeX,$LblSizeY) #Size of textbox
            Font                = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,$FontSize)
            Anchor              = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top)
            AutoSize            = $true
            IntegralHeight      = $false
            AllowDrop           = $true
            ScrollAlwaysVisible = $false
        }
        #Create Drag-&-Drop events with effects to actually get the GUI working, not the copy-to-CLI side
        $listBox_DragOver = [System.Windows.Forms.DragEventHandler]{
	        if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {$_.Effect = 'Copy'}                       #$_=[System.Windows.Forms.DragEventArgs]
	        else                                                               {$_.Effect = 'None'}
        }
        $listBox_DragDrop = [System.Windows.Forms.DragEventHandler]{
	        foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) {$listBox.Items.Add($filename)} #$_=[System.Windows.Forms.DragEventArgs]
        }
        #Create "Delete" keydown event to delete selected items in listBox mode
        $listBox.Add_KeyDown({
            if (($PSItem.KeyCode -eq "Delete") -and ($listBox.Items.Count -gt 0)) {$listBox.Items.Remove($listBox.SelectedItems[0])}
        })
    }
    #Converting from monitor resolution: OK button's starting position & size
    [int]$OKStartX = [math]::Round($mWidth /4.7)
    [int]$OKStartY = [math]::Round($mHeight/108)
    [int]$OKbSizeX = [math]::Round($mWidth /34.92)
    [int]$OKbSizeY = [math]::Round($mHeight/47)
    if (($host.name -match 'consolehost')) {$OKStartX-=3} #Compensate width rendering difference in PowerShell Console
    #Drawing the OK button
    $okButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Size($OKStartX,$OKStartY) #OK button position
        Size         = New-Object System.Drawing.Size($OKbSizeX,$OKbSizeY) #OK button size
        DialogResult = [System.Windows.Forms.DialogResult]::OK
        Text         = "OK"
    }
    if     (($InboxType -eq "txt") -or ($InboxType -eq "1")) {$okButton.Add_Click({$form.Tag = $textBox.Text;  $form.Close()})}
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {$okButton.Add_Click({$form.Tag = $listBox.Items; $form.Close()})}

    #Converting from monitor resolution: Cancel button's starting position
    [int]$ClStartX = [math]::Round($mWidth /4.08)
    [int]$ClStartY = $OKStartY #Same Height as the OK button
    [int]$ClbSizeX = $OKbSizeX #Same size as the OK button
    [int]$ClbSizeY = $OKbSizeY #Same size as the OK button
    if (($host.name -match 'consolehost')) {$ClStartX-=3} #Compensate width rendering difference in PowerShell Console
    #Drawing the Cancel / Clear button
    $cancelButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Size($ClStartX,$ClStartY)
        Size         = New-Object System.Drawing.Size($ClbSizeX,$ClbSizeY)
        Text         = "Cancel"
        DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    }
    $cancelButton.Add_Click({$form.Tag = $null; Try{$listBox.Items.Clear()}Catch [Exception]{}; $form.Close()})

    #Converting from monitor resolution: size of the prompt/form window
    [int]$formSizeX = [math]::Round($mWidth /3.56)
    [int]$formSizeY = [math]::Round($mHeight/2.18)
    if (($host.name -match 'consolehost')) {$formSizeX+=2} #Compensate width rendering difference in PowerShell Console
    #Draw the form window
    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = $WindowTitle
        Size = New-Object System.Drawing.Size($formSizeX,$formSizeY) #Form window size
        FormBorderStyle = 'FixedSingle'
        StartPosition = "CenterScreen"
        AutoSizeMode = 'GrowAndShrink'
        Topmost = $false
        AcceptButton = $okButton
        CancelButton = $cancelButton
        ShowInTaskbar = $true
    }
    #Add control elements to the prompt/form window
    $form.Controls.Add($label); $form.Controls.Add($okButton); $form.Controls.Add($cancelButton)
    if     (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        if ($ShowDebug -eq $true) {Write-Debug "! Mode == MultiLine textBox Form"}
        $form.Controls.Add($textBox)
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        if ($ShowDebug -eq $true) {Write-Debug "! Mode == Drag&Drop listBox From"}
        $form.Controls.Add($listBox)
        #Add form Closing events for drag-&-drop events only, basically to remove data from listBox
        $form_FormClosed = {
	        try {
                $listBox.remove_Click($button_Click)
		        $listBox.remove_DragOver($listBox_DragOver)
		        $listBox.remove_DragDrop($listBox_DragDrop)
                $listBox.remove_DragDrop($listBox_DragDrop)
		        $form.remove_FormClosed($Form_Cleanup_FormClosed)
	        }
	        catch [Exception] {}
        }
        #Load Drag-&-Drop events into the form
        $listBox.Add_DragOver($listBox_DragOver)
        $listBox.Add_DragDrop($listBox_DragDrop)
        $form.Add_FormClosed($form_FormClosed)
    }
    #Load Add_Shown event used by both textbox & drag-&-drop events into form
    $form.Add_Shown({$form.Activate()})
    #Load Key_Down event for closing with ESC button
    $form.Add_KeyDown({
        if ($PSItem.KeyCode -eq "Escape") {$cancelButton.PerformClick()}
    })
    #Normal prompting, user can proceed with $null return by clicking Cancel or ×, or empty string by clicking OK
    $form.ShowDialog() | Out-Null #Supress "OK/Cancel" text from returned in Dialog

    #An early-skip to prevent an empty listBox from not come with all of available methods
    if     ((($InboxType -eq "txt")-or($InboxType -eq "1")) -and ($textBox.Text -eq ""))       {
        if (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ""}
        if (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return $null}
    }
    elseif  ((($InboxType -eq "dnd")-or($InboxType -eq "2")) -and ($listBox.Items.Count -eq 0)) {
        if (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ""}
        if (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return $null}
    }

    #Scrub Empty lines & DialogResult (OK) from returning
    [array]$ScrbDiagRslt = ($form.Tag.Split("`r`n").Trim()) | where {$_ -ne ""} #Where filtering is very important here because otherwise each line would be followed by an empty line

    #Format result into multi-line string / array based on user definition
    if     (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ($ScrbDiagRslt | Out-String).TrimEnd()} #String out, TrimEnd is very important as output would otherwise have an empty line in the end
    elseif (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return  $ScrbDiagRslt }                        #Array out
}
#「@MrNetTek」Enabling high-dpi Window Form for high ppi monitors, otherwise it will be an unholy bilinear interpolation mess
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();      
}
'@
$null = [ProcessDPI]::SetProcessDPIAware()

clear

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
    $ctrl_gen+="timeout /nobreak /t "+(Get-Random -InputObject 1,2,3,4,5,6,7).ToString() #Reducing some load on video platform side by a sleep procedure inbetween each downloading task for 1~7 seconds, to somewhat mimic a normal watching behavior
    $ctrl_gen+="$ytdlpAppPath --newline --ignore-errors -o `"$DownloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieImp " #The %% is required for batch script instead of %(title) specified in yt-dlp docs
}

$ctrl_gen += "
pause
"
$utf8NoBOM=New-Object System.Text.UTF8Encoding $false #Exporting utf-8NoBOM coded text file
[IO.File]::WriteAllLines($CmdPrint, $ctrl_gen, $utf8NoBOM)
Write-Output "`r`nDone, exprted batch script as $CmdPrint, run by double-clicking it`r`n"

pause