param(
    [Parameter(Mandatory=$true)][string]$Classification,   # JSON array: [{path,name,category,score,notes,extracted_text}]
    [string]$OutDir = "",
    [int]$MaxPages = 6,
    [int]$PerPage = 12
)

# 3ain el-Arab - make-report.ps1
# Builds a visual feedback report as PNG images from classification JSON.
# Usage:
#   & '<skilldir>\scripts\make-report.ps1' -Classification 'path\to\classifications.json'

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Classification)) { Write-Error "Classification file not found"; exit 1 }

$chrome = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $chrome) { Write-Error "Chrome not found"; exit 1 }

$items = @(Get-Content -LiteralPath $Classification -Raw -Encoding UTF8 | ConvertFrom-Json)

if ($OutDir -eq "") {
    $OutDir = Join-Path (Split-Path -Parent $Classification) 'ein-report'
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$workdir = Join-Path $OutDir '_work'
New-Item -ItemType Directory -Path $workdir -Force | Out-Null

function Esc([string]$s) { [System.Security.SecurityElement]::Escape([string]$s) }
function FnEsc([string]$s) { ([string]$s).Replace('\','/') }

# Safe small on-page thumbnail: use the captured previews if present, else the source image
$previewDir = Join-Path (Split-Path -Parent $Classification) 'screenshots'

$pages = [Math]::Ceiling($items.Count / $PerPage)
$pageCount = [Math]::Min($pages, $MaxPages)
$pageIdx = 0

for ($p = 0; $p -lt $pageCount; $p++) {
    $chunk = $items | Select-Object -Skip ($p * $PerPage) -First $PerPage
    $rows = ""
    foreach ($it in $chunk) {
        $path = FnEsc $it.path
        $name = Esc $it.name
        $cat = Esc $it.category
        $score = $it.score
        $notes = Esc $it.notes
        $text = Esc $it.extracted_text

        # find a preview image matching this original name
        $preview = $null
        $previewBase = [IO.Path]::GetFileNameWithoutExtension($it.name)
        if (Test-Path -LiteralPath $previewDir) {
            $preview = Get-ChildItem -LiteralPath $previewDir -Filter "*$previewBase*_preview.png" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($preview) {
            $thumb = FnEsc $preview.FullName
            $imgSrc = [System.Uri]::new($thumb).AbsoluteUri
        } else {
            $imgSrc = [System.Uri]::new($it.path).AbsoluteUri
        }
        $scoreColor = if ([double]$score -ge 0.7) { '#3ec46d' } elseif ([double]$score -ge 0.4) { '#e6b93f' } else { '#e06045' }

        $rows += "<div class='card'><div class='thumb'><img src='$imgSrc'></div><div class='body'><div class='n'>$name</div><div class='cat' style='--sc:$scoreColor'>$cat <span class='sc'>$([Math]::Round([double]$score,2))</span></div><div class='notes'>$notes</div><div class='text'>$text</div></div></div>"
    }

    $html = @"
<!DOCTYPE html><html lang='ar' dir='rtl'><head><meta charset='utf-8'>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0e0e10;color:#e8e8ea;font-family:Arial,'Segoe UI',sans-serif;padding:24px}
h1{font-size:22px;margin-bottom:4px;color:#f3c862}
.sub{font-size:12px;color:#888;margin-bottom:20px}
.tbl{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px}
.card{background:#1a1a1f;border:1px solid #2c2c33;border-radius:10px;overflow:hidden}
.thumb{height:160px;background:#000;overflow:hidden}
.thumb img{width:100%;height:100%;object-fit:contain}
.body{padding:10px}
.n{font-size:13px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cat{font-size:11px;color:var(--sc,#ccc);margin:6px 0 6px}
.cat .sc{color:#aaa}
.notes{font-size:11px;color:#c9c9ce;line-height:1.5}
.text{font-size:10px;color:#7fce7f;margin-top:6px;white-space:pre-wrap;word-break:break-word}
.foot{margin-top:20px;font-size:11px;color:#666;text-align:center}
</style></head><body>
<h1>&#9656; EYA X &mdash; &#1593;&#1610;&#1606; &#1575;&#1603;&#1587; &mdash; &#1578;&#1602;&#1585;&#1610;&#1585; &#1578;&#1589;&#1606;&#1610;&#1601; &#1575;&#1604;&#1589;&#1608;&#1585;</h1>
<div class='sub'>&#1575;&#1604;&#1589;&#1601;&#1581;&#1577; $($p+1) / $pageCount &mdash; &#1605;&#1580;&#1605;&#1608;&#1593; $($items.Count) &#1589;&#1608;&#1585;&#1577;</div>
<div class='tbl'>$rows</div>
<div class='foot'>EYA X &mdash; &#1593;&#1610;&#1606; &#1575;&#1603;&#1587; &copy; &#1578;&#1602;&#1585;&#1610;&#1585; &#1578;&#1604;&#1602;&#1575;&#1574;&#1610;</div>
</body></html>
"@

    $htmlPath = Join-Path $workdir "report_p$($p+1).html"
    [IO.File]::WriteAllText($htmlPath, $html, [System.Text.Encoding]::UTF8)
    $htmlUri = [System.Uri]::new($htmlPath).AbsoluteUri
    $outPng = Join-Path $OutDir "report_page_$($p+1).png"

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $chrome --headless --disable-gpu --hide-scrollbars --window-size=1366,900 --screenshot=$outPng --default-background-color=0e0e10 $htmlUri 2>&1 | Out-Null
    $ErrorActionPreference = $prevEAP
    if ($global:Error.Count -gt 0) { $global:Error.RemoveAt(0) }
    if (Test-Path -LiteralPath $outPng) {
        Write-Output "Report page $($p+1) -> $outPng"
        $pageIdx++
    } else {
        Write-Output "FAIL page $($p+1)"
    }
}

Remove-Item -LiteralPath $workdir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Done. $pageIdx pages written to $OutDir"
