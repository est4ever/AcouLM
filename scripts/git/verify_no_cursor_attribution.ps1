# Scan all refs for Cursor co-author trailers or cursoragent email in commit objects.
param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    throw "Not a git repo: $ProjectRoot"
}

$pattern = 'cursoragent@cursor\.com|Co-authored-by:\s*Cursor'
$hits = New-Object System.Collections.Generic.List[string]

git for-each-ref --format="%(refname)" refs/ | ForEach-Object {
    $ref = $_
    git log $ref --format="%H" 2>$null | ForEach-Object {
        $body = git cat-file -p $_ 2>$null
        if ($body -match $pattern) {
            $hits.Add("$ref $_")
        }
    }
}

Write-Host ""
Write-Host "Project: $ProjectRoot"
Write-Host "Commits with Cursor attribution (all refs): $($hits.Count)"
if ($hits.Count -gt 0) {
    $hits | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Fix: run scripts\git\strip_cursor_coauthor.ps1 then force-push (see script output)." -ForegroundColor Cyan
    exit 1
}

Write-Host "OK - no Cursor trailers in this clone." -ForegroundColor Green
Write-Host ""
Write-Host "If GitHub still lists 'cursoragent' under Contributors:" -ForegroundColor DarkYellow
Write-Host "  1. Open https://github.com/est4ever/AcouLM/commits?author=cursoragent"
Write-Host "     (if commits appear, remote history still has them - force-push after strip)"
Write-Host "  2. If that URL is empty, it is GitHub cache - open a support ticket:"
Write-Host "     https://support.github.com/contact"
Write-Host "     Topic: remove stale contributor / incorrect attribution on public repo"
Write-Host "  3. Uninstalling the Cursor GitHub App does NOT update the Contributors list."
exit 0
