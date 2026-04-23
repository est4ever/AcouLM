param()

$ErrorActionPreference = "Stop"

function Resolve-GitleaksPath {
    $cmd = Get-Command gitleaks -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\gitleaks.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Gitleaks\gitleaks.exe"),
        (Join-Path $env:ProgramFiles "gitleaks\gitleaks.exe")
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$gitleaksPath = Resolve-GitleaksPath
if (-not $gitleaksPath) {
    throw "gitleaks is not installed or not discoverable. Install it with: winget install gitleaks.gitleaks"
}

& $gitleaksPath detect --verbose --redact --source .

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "[Security] No leaks detected by gitleaks." -ForegroundColor Green
