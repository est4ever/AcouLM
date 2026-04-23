param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceHook = Join-Path $scriptDir ".githooks\pre-commit"
$gitDir = Join-Path $scriptDir ".git"
$targetDir = Join-Path $gitDir "hooks"
$targetHook = Join-Path $targetDir "pre-commit"

if (-not (Test-Path -LiteralPath $gitDir)) {
    throw "Not a git repository root: $scriptDir"
}
if (-not (Test-Path -LiteralPath $sourceHook)) {
    throw "Missing hook template: $sourceHook"
}

if (-not (Test-Path -LiteralPath $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Copy-Item -LiteralPath $sourceHook -Destination $targetHook -Force

try {
    Unblock-File -LiteralPath $targetHook -ErrorAction SilentlyContinue
} catch {}

Write-Host "[Security] Installed pre-commit hook at $targetHook" -ForegroundColor Green
Write-Host "[Security] Requirement: gitleaks must be available in PATH." -ForegroundColor Cyan
