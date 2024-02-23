Function badinputwarning {Write-Warning "`r`n×输入错误, 重试"}

Function whereisit($startPath='DESKTOP', [string]$Filter="EXE Files |*.exe", [string]$WindowTitle) {
    #启用System.Windows.Forms选择文件的GUI交互窗，通过SelectedPath将GUI交互窗锁定到桌面文件夹, 效果一般
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
    Add-Type -AssemblyName System.Windows.Forms
    $startPath = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('DESKTOP')
        Filter = $Filter
        Title = $WindowTitle
    }
    Do {$dInput = $startPath.ShowDialog()} While ($dInput -eq "Cancel") #打开选择文件的GUI交互窗, 通过重新打开选择窗来反取消用户的取消
    return $startPath.FileName
}
Function whichlocation($startPath='DESKTOP', [string]$Message="选择路径用的窗口. 拖拽边角可放大以便操作") {
    #启用System.Windows.Forms选择文件夹的GUI交互窗
    Add-Type -AssemblyName System.Windows.Forms
    $startPath = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        Description=$Message
        SelectedPath=[Environment]::GetFolderPath($startPath)
        RootFolder='MyComputer'
        ShowNewFolderButton=$true
    }#打开选择文件的GUI交互窗, 通过重新打开选择窗来反取消用户的取消
    Do {$dInput = $startPath.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost=$true}))} While ($dInput -eq "Cancel") #窗口小, TopMost开
    #由于选择根目录时路径变量含"\", 而文件夹时路径变量缺"\", 所以要自动判断并补上
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
#「@MrNetTek」高DPI显示渲染模式的Windows Form, 否则会被双线性插值成一坨
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();      
}
'@
$null = [ProcessDPI]::SetProcessDPIAware()

clear

Write-Host "短链接可能会导致下载失败，建议用如 github.com/EuanRiggans/BulkURLOpener 的批量链接管理器打开并拷贝解析出的完整链接`n"

$link=""
Do {($link = Read-MultiLineInputDialog -Message "★ 粘贴所有要下载的视频链接，多个链接通过换行区分" -WindowTitle "★ yt-dlp-ops 下载链接输入窗口" -DefaultText "")
    if (($link -notmatch "http") -and ($link -notmatch "=") -and ($link -notmatch "ftp") -and ($link -notmatch "localhost")) {badinputwarning} else {"`r`n√ 行223: 判断为正常下载链接"}
} While ($link -eq "") #检测到下载链接可能有错后仍然继续

Do {$DownloadPath = whichlocation -Message "选择[下载路径]";         $DownloadPath
    $ytdlpAppPath = ((Get-Location).ToString()+"\yt-dlp.exe")                      #初始yt-dlp下载器路径 - 位于.ps1同目录下
    if ((Test-Path -Path $ytdlpAppPath -PathType Leaf) -eq $false) {
        whereisit -WindowTitle "定位[yt-dlp.exe]"
    };                                                               $ytdlpAppPath #手动定位yt-dlp下载器路径, 如果定位失败
    $CmdPrintPath = whichlocation -Message "选择[导出批处理的路径]"; $CmdPrintPath #导出批处理路径
    ""
    if (Test-Path $DownloadPath) {Write-Host "√ yt-dlp.exe路径正常"} else {Write-Error "× yt-dlp.exe路径异常"; pause; exit}
    if (Test-Path $ytdlpAppPath) {Write-Host "√ 视频文件夹路径正常"} else {Write-Error "× 视频文件夹路径异常"; pause; exit}
    if (Test-Path $CmdPrintPath) {Write-Host "√ 导出批处理路径正常"} else {Write-Error "× 导出批处理路径异常"; pause; exit}
    ""
} While ((Test-Path $ytdlpAppPath) + (Test-Path $DownloadPath) + (Test-Path $CmdPrintPath) -ne 3) #$true+$true+$true=3

$CookieIOPath = $DownloadPath+"ytdlpCookies.txt"                                   #导出和后来导入Cookie用的txt

$brwsrSelect=$cookieExp=""
Switch (Read-Host "输入y以添加一行[导出当前浏览器cookie]的命令，或按Enter跳过") {
    y {
        $brwsrSelect = Switch (Read-Host "选择之前登录过视频平台，含账户Cookie的浏览器:
    [A: Chrome | B: Brave | C: Chromium | E: Edge | F: Firefox | O: Opera | S: Safari | V: Vivaldi]") {
           a {"Chrome"} b {"Brave"} c {"Chromium"} o {"Opera"}
           e {"Edge"} f {"Firefox"} s {"Safari"} v {"Vivaldi"} default {"Chromium"}
       }
       $cookieExp = "$ytdlpAppPath --ignore-errors --cookies-from-browser $brwsrSelect --cookies $CookieIOPath"
       Write-Output "！仅导出Cookies的命令会导致yt-dlp弹出没有视频下载链接的报错，无视即可`n"
    }
    Default {"√ 跳过"}
}

$cookieImp = "--cookies $CookieIOPath" #此处完成yt-dlp导出以及导入cookies的命令
$CmdPrint = $CmdPrintPath+"yt-dlp-download.bat"; "`r`n将导出批处理文件：$CmdPrint" #此处完成批处理导出路径的搭建
if (Test-Path $CmdPrint) {Remove-Item $CmdPrint} #由于写入使用了 >> 所以需要通过检测删除机制覆盖原始文件

$ctrl_gen = @()
$ctrl_gen += "
chcp 65001

@echo off"
if ($brwsrSelect -ne "") {
    $ctrl_gen+="
@ECHO 从浏览器生成cookies到$CookieIOPath"
    $ctrl_gen+=$cookieExp
} #将导出cookie的命令写入控制批处理

$ctrl_gen += "
@ECHO 下载视频与随机间隔"
$link.Split("`r`n").Trim() | where {$_ -ne ""} | ForEach-Object {
    $ctrl_gen+="timeout /nobreak /t "+(Get-Random -InputObject 1,2,3,4,5,6,7).ToString() #每个下载随机间隔1~7秒以降低对视频平台的压力，从而实现对普通观看过程的模拟，并降低被拦截的概率
    $ctrl_gen+="$ytdlpAppPath --newline --ignore-errors -o `"$DownloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieImp " #批处理中需要%%而不是常规%(title)
}

$ctrl_gen += "
pause
"
$utf8NoBOM=New-Object System.Text.UTF8Encoding $false #导出utf-8NoBOM文本编码用
[IO.File]::WriteAllLines($CmdPrint, $ctrl_gen, $utf8NoBOM) #强制导出utf-8NoBOM编码
Write-Output "`r`n完成, 批处理已导出为$CmdPrint, 双击即可运行`r`n"

pause