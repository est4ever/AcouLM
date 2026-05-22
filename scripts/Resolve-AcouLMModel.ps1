# Pick a runnable model for the built-in backend and update registry (IR > small > GGUF).
# Called by acoulm before launch so users are not stuck on a slow/broken default.
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$modelsRoot = Join-Path $ProjectRoot "models"
$regPath = Join-Path $ProjectRoot "registry\models_registry.json"
$regExample = Join-Path $ProjectRoot "registry\models_registry.example.json"
$backReg = Join-Path $ProjectRoot "registry\backends_registry.json"
$backExample = Join-Path $ProjectRoot "registry\backends_registry.example.json"

function Test-DirHasOpenVINOIr {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath -PathType Container)) { return $false }
    return $null -ne @(Get-ChildItem -LiteralPath $FullPath -Filter "*.xml" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Get-PathSizeMB {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath)) { return 0.0 }
    try {
        if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
            return [math]::Round(((Get-Item -LiteralPath $FullPath).Length / 1MB), 2)
        }
        $sum = (Get-ChildItem -LiteralPath $FullPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0.0 }
        return [math]::Round(($sum / 1MB), 2)
    } catch { return 0.0 }
}

function Test-RunnableBuiltinPath {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath)) { return $false }
    if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
        return $FullPath -match '\.(?i)gguf$'
    }
    if (Test-DirHasOpenVINOIr -FullPath $FullPath) { return $true }
    $ggufs = @(Get-ChildItem -LiteralPath $FullPath -Filter "*.gguf" -File -ErrorAction SilentlyContinue)
    return ($ggufs.Count -eq 1)
}

function To-RelModelPath {
    param([string]$FullPath)
    $t = [System.IO.Path]::GetFullPath($FullPath)
    if (-not $t.StartsWith($ProjectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath
    }
    $rest = $t.Substring($ProjectRoot.Length).TrimStart([char[]]@('\', '/'))
    return "./" + ($rest -replace '\\', '/')
}

function Get-RunnableDiscoveries {
    $found = @{}
    $add = {
        param([string]$FullPath, [string]$Format, [string]$IdHint)
        if (-not (Test-RunnableBuiltinPath -FullPath $FullPath)) { return }
        $rel = To-RelModelPath -FullPath $FullPath
        if ($found.ContainsKey($rel)) { return }
        $id = $IdHint
        if ([string]::IsNullOrWhiteSpace($id)) {
            $id = ([System.IO.Path]::GetFileName($FullPath.TrimEnd('\', '/')) -replace '[^a-zA-Z0-9]+', '-').ToLower()
        }
        $found[$rel] = [pscustomobject]@{
            Id     = $id
            Path   = $rel
            Format = $Format
            SizeMb = Get-PathSizeMB -FullPath $FullPath
            Full   = $FullPath
        }
    }

    if (Test-Path -LiteralPath $modelsRoot) {
        foreach ($dir in @(Get-ChildItem -LiteralPath $modelsRoot -Directory -ErrorAction SilentlyContinue)) {
            if ($dir.Name -like "*-ov-ir") {
                & $add $dir.FullName "openvino" $dir.Name
            } elseif (Test-DirHasOpenVINOIr -FullPath $dir.FullName) {
                & $add $dir.FullName "openvino" $dir.Name
            } else {
                $ggufs = @(Get-ChildItem -LiteralPath $dir.FullName -Filter "*.gguf" -File -ErrorAction SilentlyContinue)
                if ($ggufs.Count -eq 1) {
                    & $add $ggufs[0].FullName "gguf" $dir.Name
                }
            }
        }
        foreach ($g in @(Get-ChildItem -LiteralPath $modelsRoot -Filter "*.gguf" -File -ErrorAction SilentlyContinue)) {
            & $add $g.FullName "gguf" ([System.IO.Path]::GetFileNameWithoutExtension($g.Name))
        }
    }

    if (Test-Path -LiteralPath $regPath) {
        try {
            $reg = Get-Content -LiteralPath $regPath -Raw | ConvertFrom-Json
            foreach ($m in @($reg.models)) {
                $p = [string]$m.path
                if ([string]::IsNullOrWhiteSpace($p)) { continue }
                $full = if ([System.IO.Path]::IsPathRooted($p)) {
                    [System.IO.Path]::GetFullPath($p)
                } else {
                    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot ($p -replace '^\.[\\/]', '')))
                }
                $fmt = ([string]$m.format).Trim().ToLower()
                if (Test-DirHasOpenVINOIr -FullPath $full) {
                    $fmt = "openvino"
                } elseif ($full -match '\.(?i)gguf$') {
                    $fmt = "gguf"
                } elseif (Test-Path -LiteralPath $full -PathType Container) {
                    $ggufs = @(Get-ChildItem -LiteralPath $full -Filter "*.gguf" -File -ErrorAction SilentlyContinue)
                    if ($ggufs.Count -eq 1) {
                        $full = $ggufs[0].FullName
                        $fmt = "gguf"
                    }
                }
                & $add $full $fmt ([string]$m.id)
            }
        } catch {}
    }

    return @($found.Values)
}

function Score-Candidate {
    param($C)
    $fp = 5
    if ($C.Format -eq "openvino" -or (Test-DirHasOpenVINOIr -FullPath $C.Full)) { $fp = 0 }
    elseif ($C.Format -eq "gguf") { $fp = 1 }
    $score = ($fp * 100000.0) + $C.SizeMb
    $pathLower = ($C.Path + " " + $C.Id).ToLower()
    if ($pathLower -match '0\.5b|0\.5-b|500m') { $score -= 25000 }
    if ($pathLower -match '3b|3-b|4b|7b|8b|13b|27b|70b') { $score += 15000 }
    if ($pathLower -match 'q4_k_m|q8_0') { $score -= 500 }
    if ($pathLower -match 'iq[0-9]') { $score += 80000 }
    return $score
}

# Ensure registry scaffolding
$regDir = Join-Path $ProjectRoot "registry"
$null = New-Item -ItemType Directory -Force -Path $regDir -ErrorAction SilentlyContinue
if (-not (Test-Path -LiteralPath $backReg) -and (Test-Path -LiteralPath $backExample)) {
    Copy-Item -LiteralPath $backExample -Destination $backReg
}
if (-not (Test-Path -LiteralPath $regPath) -and (Test-Path -LiteralPath $regExample)) {
    Copy-Item -LiteralPath $regExample -Destination $regPath
}

$candidates = Get-RunnableDiscoveries
if (-not $candidates -or $candidates.Count -eq 0) {
    Write-Host "[AcouLM] No runnable model found under .\models\ (need OpenVINO IR or one .gguf file)." -ForegroundColor Yellow
    return @{ Ok = $false; Reason = "no-runnable" }
}

$best = $candidates | Sort-Object { Score-Candidate $_ }, Id | Select-Object -First 1

$reg = @{
    schema                 = 1
    auto_select_best_model = $true
    selected_model         = $best.Id
    models                 = @()
}
$seenId = @{}
foreach ($c in ($candidates | Sort-Object { Score-Candidate $_ })) {
    if ($seenId.ContainsKey($c.Id)) { continue }
    $seenId[$c.Id] = $true
    $reg.models += @{
        id      = $c.Id
        path    = $c.Path
        format  = if ($c.Format) { $c.Format } else { "openvino" }
        backend = "openvino"
        status  = "ready"
    }
}
($reg | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $regPath -Encoding UTF8

Write-Host "[AcouLM] Using model: $($best.Id) ($($best.Path))" -ForegroundColor Green
if ($best.Format -eq "gguf") {
    Write-Host "[AcouLM] Tip: export OpenVINO IR once for much faster daily acoulm (see README Speed)." -ForegroundColor DarkGray
}

return @{ Ok = $true; ModelId = $best.Id; Path = $best.Path; Format = $best.Format }
