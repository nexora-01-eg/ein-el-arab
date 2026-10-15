param(
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$OutJson = ""
)

# 3ain el-Arab - scan-images.ps1
# Scans a folder for image files and writes a manifest.json
# Usage: & '<skilldir>\scripts\scan-images.ps1' -Root 'D:\images'

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Error "Path not found: $Root"
    exit 1
}

$exts = @('.jpg','.jpeg','.png','.webp','.gif','.bmp','.svg','.tiff','.tif','.heic','.avif')
$resolved = (Resolve-Path -LiteralPath $Root).Path

$outDir = if ($OutJson -ne "") {
    (Split-Path -Parent (Resolve-Path -LiteralPath $OutJson))
} else {
    $resolved
}
$outJsonPath = if ($OutJson -ne "") {
    $OutJson
} else {
    Join-Path $outDir 'manifest.json'
}
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$files = Get-ChildItem -LiteralPath $resolved -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $exts -contains $_.Extension.ToLower() -and $_.FullName -notmatch '\\(node_modules|\.git|screenshots|ein-report)\\' } |
    Sort-Object FullName

$manifest = @()
foreach ($f in $files) {
    $manifest += [PSCustomObject]@{
        path       = $f.FullName
        name       = $f.Name
        extension  = $f.Extension
        size_bytes = $f.Length
        modified   = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        folder     = $f.DirectoryName
    }
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outJsonPath -Encoding UTF8

Write-Output "Images found: $($manifest.Count)"
Write-Output "Manifest written to: $outJsonPath"
