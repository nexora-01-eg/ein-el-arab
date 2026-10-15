param(
    [Parameter(Mandatory=$true)][string]$Manifest,
    [string]$OutDir = "",
    [int]$MaxFiles = 200
)

# 3ain el-Arab - screenshot-images.ps1
# Opens each image in stitched HTML preview and screenshots via headless Chrome
# Usage: & '<skilldir>\scripts\screenshot-images.ps1' -Manifest 'path\to\manifest.json'

$ErrorActionPreference = 'Stop'

$chrome = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $chrome) {
    Write-Error "Chrome not found. Cannot capture previews."
    exit 1
}

$manifestObj = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json

if ($OutDir -eq "") {
    $OutDir = Join-Path (Split-Path -Parent $Manifest) 'screenshots'
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$files = @($manifestObj) | Select-Object -First $MaxFiles
$workdir = Join-Path $OutDir '_work'
New-Item -ItemType Directory -Path $workdir -Force | Out-Null

$i = 0
$captured = 0
foreach ($f in $files) {
    $i++
    $src = $f.path
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $baseNoExt = [IO.Path]::GetFileNameWithoutExtension($f.name)
    $safeName = $i.ToString('D4') + '_' + $baseNoExt + '_preview.png'
    $outPath = Join-Path $OutDir $safeName
    if (Test-Path -LiteralPath $outPath) { $captured++; continue }

    # Build a tiny HTML with the image + filename so we can screenshot it
    $fileUri = [System.Uri]::new($src).AbsoluteUri
    $fn = [System.Security.SecurityElement]::Escape($f.name)
    $html = "<html><head><meta charset='utf-8'><style>body{margin:0;background:#111;font-family:Arial;color:#eee;display:flex;flex-direction:column;align-items:flex-start;min-height:100vh}.bar{padding:8px 12px;font-size:13px;background:#222;width:100%;box-sizing:border-box;border-bottom:1px solid #333}.img{max-width:100%;}img{max-width:100%;height:auto;display:block}</style></head><body><div class='bar'>$fn</div><div class='img'><img src='$fileUri'></div></body></html>"
    $htmlPath = Join-Path $workdir ('v_' + $i.ToString('D4') + '.html')
    [IO.File]::WriteAllText($htmlPath, $html, [System.Text.Encoding]::UTF8)
    $htmlUri = [System.Uri]::new($htmlPath).AbsoluteUri

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $chrome --headless --disable-gpu --hide-scrollbars --window-size=1366,900 --screenshot=$outPath --default-background-color=111111 $htmlUri 2>&1 | Out-Null
    $ErrorActionPreference = $prevEAP
    if ($global:Error.Count -gt 0) { $global:Error.RemoveAt(0) }
    if (Test-Path -LiteralPath $outPath) {
        $captured++
        Write-Output "OK $($f.name)"
    } else {
        Write-Output "FAIL $($f.name)"
    }
}

Remove-Item -LiteralPath $workdir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Captured: $captured/$($files.Count)"
