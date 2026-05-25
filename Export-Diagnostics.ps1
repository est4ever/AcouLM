param(
    [string]$ProjectRoot = ""
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$exportDir = Join-Path $ProjectRoot "export"
if (-not (Test-Path -LiteralPath $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$work = Join-Path $env:TEMP ("acoulm-diag-" + $stamp)
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Redact-Path {
    param([string]$Line)
    return [regex]::Replace($Line, '([A-Za-z]:\\Users\\)([^\\]+)', { param($m) $m.Groups[1].Value + "<user>\\" })
}

# Registry examples + redacted copies of local registries if present
$regDir = Join-Path $ProjectRoot "registry"
foreach ($name in @("models_registry.json", "backends_registry.json")) {
    $p = Join-Path $regDir $name
    if (Test-Path -LiteralPath $p) {
        $raw = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
        if ($raw) {
            Redact-Path $raw | Set-Content -Path (Join-Path $work ("redacted_" + $name)) -Encoding UTF8
        }
    }
}
Get-ChildItem -Path $regDir -Filter "*.example.json" -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $work $_.Name) -Force
}

# Metrics tail
$metrics = Join-Path $ProjectRoot "metrics.ndjson"
if (Test-Path -LiteralPath $metrics) {
    Get-Content -LiteralPath $metrics -Tail 80 -ErrorAction SilentlyContinue | Set-Content (Join-Path $work "metrics-tail.txt") -Encoding UTF8
}

# dist file list (names only)
$dist = Join-Path $ProjectRoot "dist"
if (Test-Path -LiteralPath $dist) {
    Get-ChildItem -LiteralPath $dist -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name |
        Set-Content (Join-Path $work "dist-files.txt") -Encoding UTF8
}

# Status snapshot for support (no secrets)
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/v1/health" -Method Get -TimeoutSec 3 -ErrorAction Stop
    ($health | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $work "health-snapshot.json") -Encoding UTF8
} catch {
    "health unreachable: $($_.Exception.Message)" | Set-Content (Join-Path $work "health-snapshot.txt") -Encoding UTF8
}
try {
    $st = Invoke-RestMethod -Uri "http://127.0.0.1:8000/v1/cli/status" -Method Get -TimeoutSec 3 -ErrorAction Stop
    ($st | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $work "cli-status-snapshot.json") -Encoding UTF8
} catch {
    "cli status unreachable: $($_.Exception.Message)" | Set-Content (Join-Path $work "cli-status-snapshot.txt") -Encoding UTF8
}

$runlog = Join-Path $ProjectRoot "runlog.txt"
if (Test-Path -LiteralPath $runlog) {
    Get-Content -LiteralPath $runlog -Tail 120 -ErrorAction SilentlyContinue |
        ForEach-Object { Redact-Path $_ } |
        Set-Content (Join-Path $work "runlog-tail.txt") -Encoding UTF8
}

$zipName = "acoulm-diagnostics-$stamp.zip"
$zipPath = Join-Path $exportDir $zipName
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
$items = @(Get-ChildItem -LiteralPath $work -Force -ErrorAction SilentlyContinue)
if ($items.Count -eq 0) {
    "AcouLM diagnostics export (no optional files found)" | Set-Content (Join-Path $work "README.txt") -Encoding UTF8
}
Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zipPath -Force
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $zipPath)) {
    throw "Compress-Archive did not create $zipPath"
}

$marker = Join-Path $exportDir "last-export.txt"
$zipPath | Set-Content -LiteralPath $marker -Encoding ASCII
Write-Host "[Export-Diagnostics] $zipPath"
