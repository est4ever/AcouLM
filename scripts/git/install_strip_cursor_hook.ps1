# Install prepare-commit-msg hook so future commits never get Cursor trailers.
param([string]$ProjectRoot = "")

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$gitDir = Join-Path ([System.IO.Path]::GetFullPath($ProjectRoot)) ".git\hooks"
$null = New-Item -ItemType Directory -Force -Path $gitDir
$hook = Join-Path $gitDir "prepare-commit-msg"

@'
#!/bin/sh
# Drop Cursor co-author lines (repo-local hook).
msgfile="$1"
[ -f "$msgfile" ] || exit 0
tmp="${msgfile}.acoulm.$$"
grep -vi 'cursoragent@cursor.com' "$msgfile" | grep -vi '^Co-authored-by: Cursor' > "$tmp" || true
mv "$tmp" "$msgfile"
'@ | Set-Content -LiteralPath $hook -Encoding ASCII -NoNewline
Add-Content -LiteralPath $hook -Value "`n"

Write-Host "Installed: $hook" -ForegroundColor Green
Write-Host "Re-run after fresh clone (.git/hooks is not versioned)."
