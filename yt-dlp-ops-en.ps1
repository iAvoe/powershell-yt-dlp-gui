. "$PSScriptRoot\Core.ps1"

# Warn user about unrecognized input format
function Send-BadInputWarning {
    Write-Warning "`r`n✕ Bad input, try again"
}

Clear-Host

Write-Host "Short link can result in download failure.`nRecommending to open all short links, and then bulk copy the full link with tools like [github.com/EuanRiggans/BulkURLOpener].`n"

# Step 1: Collect download links from user (multi-line input dialog)
$links = ""
Do {
    $links = Read-MultiLineInputDialog -Message "★ Paste all your downloading links, separated by line-breaks" -WindowTitle "★ yt-dlp-ops-en Downloading input box" -DefaultText ""
    if (($links -notmatch "http") -and ($links -notmatch "=") -and ($links -notmatch "ftp") -and ($links -notmatch "localhost")) {
        Send-BadInputWarning
    } else {
        "`r`n✓ Input determined as normal video link"
    }
} While ($links -eq "") # Continue even if unusual input is detected

# Step 2: Select paths (download folder, yt-dlp.exe, batch export folder)
Do {
    $downloadPath = Select-Folder -Description "Select [Download Path]" -InitialPath $PSScriptRoot
    $downloadPath

    $ytDlpPath = Join-Path $PSScriptRoot "yt-dlp.exe"
    if ((Test-Path -LiteralPath $ytDlpPath -PathType Leaf) -eq $false) {
        $ytDlpPath = Select-File -Title "Locate [yt-dlp.exe]" -ExeOnly -InitialDirectory $PSScriptRoot
        Write-Host "You can skip this by placing this script in the same path as yt-dlp"
    }
    $ytDlpPath

    $batchExportPath = Select-Folder -Description "Select [Script Exporting Path]" -InitialPath $PSScriptRoot
    $batchExportPath

    ""
    if (Test-Path $ytDlpPath)      { Write-Host "✓ yt-dlp.exe path is valid"         } else { Write-Error "✕ yt-dlp.exe path is invalid";     pause; exit }
    if (Test-Path $downloadPath)   { Write-Host "✓ Video download path is valid"     } else { Write-Error "✕ Video download path is invalid"; pause; exit }
    if (Test-Path $batchExportPath){ Write-Host "✓ Batch export path is valid"       } else { Write-Error "✕ Batch export path is invalid";   pause; exit }
    ""
} While ((Test-Path $ytDlpPath) + (Test-Path $downloadPath) + (Test-Path $batchExportPath) -ne 3) # $true+$true+$true = 3

# Step 3: Ask whether to download audio only
$audioOnly = $false
Switch (Read-Host "`nInput 'y' to [Only download audio], otherwise press Enter to download entire video") {
    y {
        $audioOnly = $true
        Write-Host "✓ Only download audio"
    }
    Default { Write-Host "✓ Download video with audio" }
}

# Step 4: Detect JS runtime for YouTube links that require EJS
$jsRuntimeParam = ""
if ($links -match "youtu\.be|youtube\.") {
    $jsRuntimeParam = "--js-runtimes `"$(Get-JSRuntimeParam)`""
    Write-Host "✓ YouTube link detected, using JS runtime parameter" -ForegroundColor Green
}

# Step 5: Browser cookie parameter setup
$cookieBrowserParam = Get-CookiesFromBrowserParam -langCode "en"

# Step 6: Build batch file content
$batchFilePath = $batchExportPath + "yt-dlp-download.bat"
"`r`nExporting batch script at: $batchFilePath"

# Remove old batch file (write mode is append >>, so we must clear stale content first)
if (Test-Path $batchFilePath) { Remove-Item $batchFilePath }

$batchContent = @()
$batchContent += @"
chcp 65001

@echo off
"@

$batchContent += @"
@ECHO Downloading videos with random gaps between each task
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
Write-Output "`r`nDone, exported batch script as $batchFilePath, run by double-clicking it`r`n"

pause
