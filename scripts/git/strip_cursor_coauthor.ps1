# Rewrite commit messages to drop Cursor co-author trailers (Windows).
# After success: git push --force-with-lease origin main
param(
    [string]$ProjectRoot = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$stripPy = Join-Path $PSScriptRoot "strip_cursor_msg.py"
if (-not (Test-Path -LiteralPath $stripPy)) {
    throw "Missing $stripPy"
}

$before = @(git log --all --grep="Co-authored-by: Cursor" --oneline 2>$null).Count
Write-Host "[strip] Commits mentioning Cursor co-author (before): $before"

if ($DryRun) {
    Write-Host "[strip] Dry run only - no rewrite." -ForegroundColor DarkGray
    exit 0
}

$env:FILTER_BRANCH_SQUELCH_WARNING = "1"
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
if (-not $py) {
    throw "Python not found. Install Python 3 or run from Git Bash: scripts/git/strip_cursor_coauthor.sh"
}

git filter-branch -f --msg-filter "`"$py`" `"$stripPy`"" --tag-name-filter cat -- --all
if ($LASTEXITCODE -ne 0) {
    throw "filter-branch failed (exit $LASTEXITCODE)"
}

git for-each-ref --format="%(refname)" refs/original/ 2>$null | ForEach-Object {
    git update-ref -d $_ 2>$null
}

$after = @(git log --all --grep="Co-authored-by: Cursor" --oneline 2>$null).Count
Write-Host "[strip] Commits mentioning Cursor co-author (after): $after"
Write-Host ""
Write-Host "[strip] Verify:  .\scripts\git\verify_no_cursor_attribution.ps1"
Write-Host "[strip] Push (rewrites GitHub history):"
Write-Host "  git push --force-with-lease origin main"
Write-Host ""
Write-Host "Contributors sidebar may take days to update; if still wrong with 0 commits at"
Write-Host "  https://github.com/est4ever/AcouLM/commits?author=cursoragent"
Write-Host "  file a GitHub Support ticket to refresh contributor stats."
