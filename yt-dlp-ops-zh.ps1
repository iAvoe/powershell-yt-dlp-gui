. "$PSScriptRoot\Core.ps1"

# 输入格式异常警告
function Send-BadInputWarning {
    Write-Warning "`r`n✕ 输入错误，重试"
}

Clear-Host

Write-Host "短链接可能会导致下载失败，建议用如 github.com/EuanRiggans/BulkURLOpener 的批量链接管理器打开并拷贝解析出的完整链接`n"

# 步骤 1：通过多行输入框收集下载链接
$links = ""
Do {
    $links = Read-MultiLineInputDialog -Message "★ 粘贴所有要下载的视频链接，多个链接通过换行区分" -WindowTitle "★ yt-dlp-ops 下载链接输入窗口" -DefaultText ""
    if (($links -notmatch "http") -and ($links -notmatch "=") -and ($links -notmatch "ftp") -and ($links -notmatch "localhost")) {
        Send-BadInputWarning
    } else {
        "`r`n✓ 判断为正常下载链接"
    }
} While ($links -eq "") # 检测到异常格式后仍然继续

# 步骤 2：选择下载路径、yt-dlp.exe 位置、批处理导出路径
Do {
    $downloadPath = Select-Folder -Description "选择 [下载路径]" -InitialPath $PSScriptRoot
    $downloadPath

    $ytDlpPath = Join-Path $PSScriptRoot "yt-dlp.exe"
    if ((Test-Path -LiteralPath $ytDlpPath -PathType Leaf) -eq $false) {
        $ytDlpPath = Select-File -Title "定位 [yt-dlp.exe]" -ExeOnly -InitialDirectory $PSScriptRoot
    }
    $ytDlpPath

    $batchExportPath = Select-Folder -Description "选择 [导出批处理的路径]" -InitialPath $PSScriptRoot
    $batchExportPath

    ""
    if (Test-Path $ytDlpPath)       { Write-Host "✓ yt-dlp.exe 路径正常"       } else { Write-Error "✕ yt-dlp.exe 路径异常";     pause; exit }
    if (Test-Path $downloadPath)    { Write-Host "✓ 视频文件夹路径正常"        } else { Write-Error "✕ 视频文件夹路径异常";    pause; exit }
    if (Test-Path $batchExportPath) { Write-Host "✓ 导出批处理路径正常"        } else { Write-Error "✕ 导出批处理路径异常";    pause; exit }
    ""
} While ((Test-Path $ytDlpPath) + (Test-Path $downloadPath) + (Test-Path $batchExportPath) -ne 3) # $true+$true+$true = 3

# 步骤 3：询问是否仅下载音频
$audioOnly = $false
Switch (Read-Host "`n输入 y 以「仅下载音频」，或按 Enter 下载完整视频") {
    y {
        $audioOnly = $true
        Write-Host "✓ 将使用音频模式下载"
    }
    Default {
        Write-Host "✓ 将下载完整视频"
    }
}

# 步骤 4：检测 YouTube 链接并配置 JS 运行时
$jsRuntimeParam = ""
if ($links -match "youtu\.be|youtube\.") {
    $jsRuntimeParam = "--js-runtimes `"$(Get-JSRuntimeParam)`""
    Write-Host "✓ 检测到 YouTube 链接，传入 JS 运行时参数" -ForegroundColor Green
}

# 步骤 5：浏览器 Cookie 参数配置
$cookieBrowserParam = Get-CookiesFromBrowserParam -langCode "zh"

# 步骤 6：构建批处理文件内容
$batchFilePath = $batchExportPath + "yt-dlp-download.bat"
"`r`n将导出批处理文件：$batchFilePath"

# 清理旧批处理文件（写入使用 >> 追加模式，需先删除旧文件以免内容叠加）
if (Test-Path $batchFilePath) { Remove-Item $batchFilePath }

$batchContent = @()
$batchContent += @"
chcp 65001

@echo off
"@

$batchContent += @"
@ECHO 下载视频与随机间隔
"@

$links.Split("`r`n").Trim() | Where-Object { $_ -ne "" } | ForEach-Object {
    $batchContent += "timeout /nobreak /t " + (Get-Random -InputObject 1, 2, 3).ToString()

    if ($audioOnly) {
        $batchContent += "$ytDlpPath --newline --ignore-errors -x --audio-format best --no-keep-video -o `"$downloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieBrowserParam $jsRuntimeParam"
    } else {
        $batchContent += "$ytDlpPath --newline --ignore-errors -o `"$downloadPath%%(title)s.%%(ext)s`" --ignore-config --hls-prefer-native --no-playlist $_ $cookieBrowserParam $jsRuntimeParam"
    }
}

$batchContent += @"

pause
"@

Write-TextFile -Path $batchFilePath -Content ($batchContent -join "`r`n") -UseBOM:$false
Write-Output "`r`n完成，批处理已导出为 $batchFilePath，双击即可运行`r`n"

pause
