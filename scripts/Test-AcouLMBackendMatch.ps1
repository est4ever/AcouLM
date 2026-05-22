# Compare /v1/health loaded weights vs registry selected model (catches stale 3B backend + 0.5B IR registry).
# Dot-sourced by acoulm.ps1 / start_app.ps1 — do not use mandatory script-level params (PowerShell will prompt).
$ErrorActionPreference = "Stop"

function Test-DirHasOpenVINOIr {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath -PathType Container)) { return $false }
    return $null -ne @(Get-ChildItem -LiteralPath $FullPath -Filter "*.xml" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Get-ModelOnDiskBytes {
    param([string]$FullPath)
    if (-not (Test-Path -LiteralPath $FullPath)) { return 0 }
    if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
        return (Get-Item -LiteralPath $FullPath).Length
    }
    $sum = (Get-ChildItem -LiteralPath $FullPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(gguf|bin|xml|safetensors)$' } |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return 0 }
    return [int64]$sum
}

function Get-RegistrySelectedModelFull {
    $rp = Join-Path $ProjectRoot "registry\models_registry.json"
    if (-not (Test-Path -LiteralPath $rp)) { return $null }
    $reg = Get-Content -LiteralPath $rp -Raw | ConvertFrom-Json
    $sel = [string]$reg.selected_model
    foreach ($m in @($reg.models)) {
        if ([string]$m.id -eq $sel) {
            $rel = [string]$m.path
            if ([string]::IsNullOrWhiteSpace($rel)) { return $null }
            $full = if ([System.IO.Path]::IsPathRooted($rel)) {
                [System.IO.Path]::GetFullPath($rel)
            } else {
                [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot ($rel -replace '^\.[\\/]', '')))
            }
            return [pscustomobject]@{
                Id       = $sel
                Path     = $rel
                FullPath = $full
                Format   = ([string]$m.format).Trim().ToLower()
            }
        }
    }
    return $null
}

function Test-AcouLMBackendMatchesRegistry {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$ApiBase = "http://127.0.0.1:8000"
    )
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
    $meta = Get-RegistrySelectedModelFull
    if (-not $meta) {
        return [pscustomobject]@{ Match = $true; Reason = "no-registry-model" }
    }

    $base = $ApiBase.TrimEnd("/")
    try {
        $h = Invoke-RestMethod -Uri "$base/v1/health" -Method Get -TimeoutSec 4 -ErrorAction Stop
    } catch {
        return [pscustomobject]@{ Match = $false; Reason = "api-unreachable"; Meta = $meta }
    }

    if ($h.chat_ready -eq $false) {
        return [pscustomobject]@{ Match = $true; Reason = "still-loading"; Meta = $meta; Health = $h }
    }

    $expectedBytes = Get-ModelOnDiskBytes -FullPath $meta.FullPath
    $actualBytes = [int64]($h.model_weight_bytes)
    $loadFmt = [string]$h.load_format
    $expectIr = (Test-DirHasOpenVINOIr -FullPath $meta.FullPath) -or ($meta.Format -eq "openvino")
    $expectGguf = $meta.FullPath -match '\.(?i)gguf$' -or ($meta.Format -eq "gguf")

    if ($expectIr -and $loadFmt -ne "ir") {
        return [pscustomobject]@{
            Match  = $false
            Reason = "registry expects OpenVINO IR but backend loaded format=$loadFmt (~$([math]::Round($actualBytes/1MB)) MB)"
            Meta   = $meta
            Health = $h
        }
    }
    if ($expectGguf -and $loadFmt -eq "ir") {
        return [pscustomobject]@{
            Match  = $false
            Reason = "registry expects GGUF but backend loaded IR"
            Meta   = $meta
            Health = $h
        }
    }

    if ($expectedBytes -gt 0 -and $actualBytes -gt 0) {
        $ratio = $actualBytes / [double]$expectedBytes
        if ($ratio -lt 0.45 -or $ratio -gt 2.2) {
            return [pscustomobject]@{
                Match  = $false
                Reason = "loaded size $([math]::Round($actualBytes/1MB)) MB != registry model $([math]::Round($expectedBytes/1MB)) MB (stale backend?)"
                Meta   = $meta
                Health = $h
            }
        }
    }

    return [pscustomobject]@{ Match = $true; Reason = "ok"; Meta = $meta; Health = $h }
}

if ($MyInvocation.InvocationName -ne '.') {
    $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    Test-AcouLMBackendMatchesRegistry -ProjectRoot $root
}
