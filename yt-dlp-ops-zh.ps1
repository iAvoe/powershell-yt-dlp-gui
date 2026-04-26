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

# 先处理 DPI，防止窗体模糊或尺寸计算偏差
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
    
    # 使用 SystemInformation，WMI (gwmi) 不稳定
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    [int]$mWidth  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
    [int]$mHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
    
    if ($ShowDebug) { Write-Debug "√ Resolution: $mWidth x $mHeight" }

    # 窗口大小计算逻辑
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

    # 处理结果返回
    if ($null -eq $form.Tag) { return $null }
    [array]$ScrbDiagRslt = ($form.Tag.ToString().Split("`r`n")).Trim() | where {$_ -ne ""}
    if (($ReturnType -eq "str")-or($ReturnType -eq "1")) {return ($ScrbDiagRslt -join "`r`n")}
    elseif (($ReturnType -eq "ary")-or($ReturnType -eq "2")) {return $ScrbDiagRslt}
}

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

$audioOnly = $false
$audioFormat = ""
Switch (Read-Host "`n输入y以[仅下载音频]，或按Enter下载完整视频") {
    y {
        $audioOnly = $true
        Write-Host "√ 将使用音频模式下载"
    }
    Default {
        Write-Host "√ 将下载完整视频"
    }
}

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
    $ctrl_gen+="timeout /nobreak /t "+(Get-Random -InputObject 1,2,3,4,5,6,7).ToString()

    # 根据用户选择构建命令
    if ($audioOnly) {
        # 仅下载音频
        $ctrl_gen+="$ytdlpAppPath --newline --ignore-errors -x --audio-format best --no-keep-video -o `"$DownloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieImp "
    }
    else {
        # 下载完整视频
        $ctrl_gen+="$ytdlpAppPath --newline --ignore-errors -o `"$DownloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieImp "
    }
}

$ctrl_gen += "
pause
"
$utf8NoBOM=New-Object System.Text.UTF8Encoding $false #导出utf-8NoBOM文本编码用
[IO.File]::WriteAllLines($CmdPrint, $ctrl_gen, $utf8NoBOM) #强制导出utf-8NoBOM编码
Write-Output "`r`n完成, 批处理已导出为$CmdPrint, 双击即可运行`r`n"

pause