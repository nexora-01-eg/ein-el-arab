param(
    [Parameter(Mandatory=$true)][string]$Classification,  # JSON array with {path, suggested_name}
    [string]$Mode = "dryrun",                              # dryrun | apply
    [switch]$Backup = $true
)

# 3ain el-Arab - rename-images.ps1
# Renames images based on classification JSON (suggested_name).
# Usage:
#   dryrun: & '<skilldir>\scripts\rename-images.ps1' -Classification 'path\to\classifications.json' -Mode dryrun
#   apply:  & '<skilldir>\scripts\rename-images.ps1' -Classification 'path\to\classifications.json' -Mode apply

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Classification)) { Write-Error "Classification file not found"; exit 1 }

$items = @(Get-Content -LiteralPath $Classification -Raw -Encoding UTF8 | ConvertFrom-Json)

$backupDir = if ($Backup -and $Mode -eq 'apply') {
    $b = Join-Path (Split-Path -Parent $Classification) 'renamed-backup'
    New-Item -ItemType Directory -Path $b -Force | Out-Null
    $b
} else { $null }

function Make-SafeName([string]$base, [string]$ext, [string]$dir) {
    $candidate = $base + $ext
    $i = 1
    while (Test-Path -LiteralPath (Join-Path $dir $candidate)) {
        $candidate = "$base-$i$ext"
        $i++
    }
    return $candidate
}

$renamedCount = 0
$results = @()

foreach ($it in $items) {
    $path = $it.path
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $dir = Split-Path -Parent $path
    $ext = [IO.Path]::GetExtension($path)
    $suggested = [string]$it.suggested_name
    if ([string]::IsNullOrWhiteSpace($suggested)) { $suggested = $it.name }

    # use the suggested name WITHOUT any extension, then attach the original ext
    $safeBase = [IO.Path]::GetFileNameWithoutExtension($suggested)
    $safeBase = $safeBase -replace '[\\/:*?"<>|]', '_'
    $safeBase = $safeBase.Trim()
    if ([string]::IsNullOrWhiteSpace($safeBase)) { $safeBase = [IO.Path]::GetFileNameWithoutExtension($it.name) }
    $newName = Make-SafeName -base $safeBase -ext $ext -dir $dir
    $newPath = Join-Path $dir $newName

    $results += [PSCustomObject]@{
        old_name = $it.name
        new_name = $newName
        status   = if ($newPath -eq $path) { 'same' } else { 'rename' }
    }

    if ($Mode -eq 'apply' -and $newPath -ne $path) {
        if ($backupDir) {
            Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir $it.name) -Force
        }
        Rename-Item -LiteralPath $path -NewName $newName -Force
        $renamedCount++
    }
}

$results | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path (Split-Path -Parent $Classification) 'rename-results.json') -Encoding UTF8

Write-Output "Mode: $Mode | total: $($items.Count) | renamed(apply): $renamedCount"
Write-Output "Preview:"
$results | Format-Table -AutoSize | Out-String -Width 200
