# Host GPU tier hints for AcouLM launchers (integrated vs discrete).
# Used only to choose defaults for the built-in backend; external backends are unaffected.

function Test-AcouLMVideoNameIsVirtual {
    param([string]$Name)
    return $Name -match 'Microsoft Basic|Remote Desktop|Virtual|VMware|Parsec|Hyper-V|Citrix|Meta Virtual'
}

function Test-AcouLMVideoNameMatchesAny {
    param(
        [string]$Name,
        [string[]]$Patterns
    )
    foreach ($p in $Patterns) {
        if ($Name -match $p) { return $true }
    }
    return $false
}

function Test-AcouLMVideoNameIsDiscrete {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if (Test-AcouLMVideoNameIsVirtual -Name $Name) { return $false }
    return Test-AcouLMVideoNameMatchesAny -Name $Name -Patterns @(
        'NVIDIA',
        'GeForce',
        'GTX',
        'RTX',
        'Quadro',
        'Tesla',
        'TITAN',
        'MX[0-9]',
        'RTX\s*A',
        'Radeon\s*RX',
        'Radeon\(TM\)\s*RX',
        'Radeon\s*Pro',
        'Radeon\s*PRO',
        'FirePro',
        'Instinct',
        'Intel\(R\)\s*Arc',
        'Intel Arc',
        'AMD Radeon RX'
    )
}

function Test-AcouLMVideoNameIsIntegrated {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if (Test-AcouLMVideoNameIsVirtual -Name $Name) { return $false }
    if (Test-AcouLMVideoNameIsDiscrete -Name $Name) { return $false }
    return Test-AcouLMVideoNameMatchesAny -Name $Name -Patterns @(
        'Intel.*(UHD|Iris|HD Graphics)',
        'AMD Radeon\(TM\) Graphics',
        'Radeon Vega',
        'Radeon\(TM\) Vega',
        'Radeon\(TM\)\s*[0-9]{3,4}M\b',
        'Radeon\s*780M',
        'Radeon\s*880M',
        'Radeon\s*760M'
    )
}

function Get-AcouLMGpuTier {
    $forced = [string]$env:ACOULM_GPU_TIER
    if ($forced -match '^(weak|integrated|discrete|none|unknown)$') {
        if ($forced -eq 'weak') { return 'integrated' }
        return $forced
    }
    if ($env:ACOULM_FORCE_GPU -eq '1') {
        return 'discrete'
    }
    try {
        $controllers = @(
            Get-CimInstance Win32_VideoController -ErrorAction Stop |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) }
        )
        $hasDiscrete = $false
        $hasIntegrated = $false
        foreach ($c in $controllers) {
            $n = [string]$c.Name
            if (Test-AcouLMVideoNameIsDiscrete -Name $n) { $hasDiscrete = $true }
            elseif (Test-AcouLMVideoNameIsIntegrated -Name $n) { $hasIntegrated = $true }
        }
        if ($hasDiscrete) { return 'discrete' }
        if ($hasIntegrated) { return 'integrated' }
        if ($controllers.Count -gt 0) { return 'unknown' }
    } catch {}
    return 'none'
}

function Get-AcouLMSnappyLaunchDevice {
    param([bool]$IsGguf)
    if ($env:ACOULM_DEVICE -match '^(CPU|GPU|NPU)$') {
        return $env:ACOULM_DEVICE.Trim().ToUpperInvariant()
    }
    $tier = Get-AcouLMGpuTier
    $forceGpu = ($env:ACOULM_FORCE_GPU -eq '1')
    if ($tier -eq 'integrated') {
        return 'CPU'
    }
    if ($tier -eq 'discrete' -or $forceGpu) {
        return 'GPU'
    }
    return ''
}

function Initialize-AcouLMDeviceEnvironment {
    $tier = Get-AcouLMGpuTier
    if ($tier -ne 'unknown') {
        $env:ACOULM_GPU_TIER = $tier
    }
    switch ($tier) {
        'discrete' {
            Write-Host '[AcouLM] Discrete GPU on host — built-in backend will prefer GPU when available.' -ForegroundColor DarkCyan
        }
        'integrated' {
            Write-Host '[AcouLM] Intel iGPU machine — launching on CPU for stability (0.5B IR is still fast).' -ForegroundColor DarkYellow
            Write-Host '[AcouLM] To try iGPU: $env:ACOULM_DEVICE="GPU"; acoulm' -ForegroundColor DarkGray
        }
        'none' {
            Write-Host '[AcouLM] CPU-only host profile — normal for shell + external backends or built-in CPU inference.' -ForegroundColor DarkGray
        }
    }
}
