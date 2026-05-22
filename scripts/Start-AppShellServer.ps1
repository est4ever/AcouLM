# Serve app_shell on :5173 with /v1/* proxied to the AcouLM API (same-origin for the browser UI).
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [int]$Port = 5173,
    [ValidateSet("Hidden", "Normal", "Minimized")]
    [string]$WindowStyle = "Hidden"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$pythonExe = Join-Path $ProjectRoot "venv\Scripts\python.exe"
$pythonCmd = if (Test-Path -LiteralPath $pythonExe) { "& '$pythonExe'" } else { "python" }
$appServer = Join-Path $ProjectRoot "scripts\linux\appshell_server.py"
if (-not (Test-Path -LiteralPath $appServer)) {
    throw "Missing $appServer"
}
$appCmd = "Set-Location '$ProjectRoot'; `$env:ACOULM_HOME='$ProjectRoot'; $pythonCmd '$appServer' --port $Port"
$args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $appCmd)
if ($WindowStyle -eq "Normal") {
    $args = @("-NoExit") + $args
}
Start-Process -FilePath "powershell" -ArgumentList $args -WindowStyle $WindowStyle | Out-Null
