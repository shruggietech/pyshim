# Quiet verbose unless you explicitly opt in later
$VerbosePreference = 'SilentlyContinue'

# ===== ShruggieTech Python Shim Profile =====
# Ensures the shim is first on PATH and loads helper functions

# --- 1) PATH: ensure C:\bin\shims is first and unique
$ShimDir = 'C:\bin\shims'

# Bridge for when Windows Launcher is missing
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    Set-Alias py "$ShimDir\python.bat" -Scope Global
}

# Split PATH into parts, remove empties, sort and unique
$pathParts = ($env:PATH -split ';') | Where-Object { $_ -and $_.Trim() -ne '' } | Sort-Object -Unique

# Remove all occurrences of ShimDir
$pathParts = $pathParts | Where-Object { $_ -ne $ShimDir }

# Prepend ShimDir
$env:PATH = ($ShimDir + ';' + ($pathParts -join ';'))

# Optional: make sure pipx shims are reachable
$PipxBin = Join-Path $env:USERPROFILE '.local\bin'
if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $PipxBin })) {
    $env:PATH = "$PipxBin;$env:PATH"
}

# --- 2) Import pyshim module (provides Use-Python, Set-AppPython, etc.)
$PyShimModule = Join-Path $ShimDir 'pyshim.psm1'
if (Test-Path -LiteralPath $PyShimModule) {
    Import-Module $PyShimModule -Force -DisableNameChecking
} else {
    Write-Warning "pyshim module not found at $PyShimModule. Install shims and module from repo."
}

# --- 3) DO NOT override the Windows 'py' launcher
# If you previously had: New-Alias py python  => REMOVE IT.
# The py launcher is used by specs like 'py:3.12' and must remain available.

# --- 4) Friendly helpers ------------------------------------------------------

function Show-PyShim {
    Write-Host "PATH[0] = $ShimDir"
    Write-Host "pyshim module loaded: " -NoNewline
    if (Get-Module -Name (Split-Path $PyShimModule -Leaf) -ErrorAction SilentlyContinue) {
        Write-Host "yes"
    } else {
        Write-Host "no"
    }

    $globalEnv = Join-Path $ShimDir 'python.env'
    $nopersist = Join-Path $ShimDir 'python.nopersist'
    if (Test-Path $globalEnv) {
        $spec = Get-Content -LiteralPath $globalEnv -Raw
        Write-Host "Global spec (python.env): $spec"
    } else {
        Write-Host "Global spec (python.env): <none>"
    }
    Write-Host "Global persistence disabled? " -NoNewline
    Write-Host ($(Test-Path $nopersist))
    if ($env:PYSHIM_INTERPRETER) { Write-Host "Session spec: $($env:PYSHIM_INTERPRETER)" }
    if ($env:PYSHIM_TARGET)      { Write-Host "App target : $($env:PYSHIM_TARGET)" }
}

# A quick bootstrap: if you want a default interpreter for new shells but not when nopersist is set
$DefaultSpec = $null   # e.g. 'py:3.12' or 'conda:base'  (leave $null to do nothing)
$NoPersistMarker = Join-Path $ShimDir 'python.nopersist'
$GlobalEnvFile  = Join-Path $ShimDir 'python.env'

if ($DefaultSpec -and -not (Test-Path $NoPersistMarker) -and -not (Test-Path $GlobalEnvFile)) {
    try {
        Use-Python -Spec $DefaultSpec -Persist
        Write-Host "Initialized global Python spec -> $DefaultSpec"
    } catch {
        Write-Warning "Failed to initialize global Python spec: $($_.Exception.Message)"
    }
}

# --- 5) Conda wrapper that cooperates with pyshim -----------------------------
# When you run: conda activate <env>, set only the *session* spec to that env.
# This keeps the shell consistent without flipping global persistence.
function conda {
    # Call the real conda
    $RealConda = Join-Path $env:USERPROFILE 'miniconda3\Scripts\conda.exe'
    if (-not (Test-Path -LiteralPath $RealConda)) {
        Write-Error "Conda not found at $RealConda"; return
    }
    & $RealConda @Args

    # Detect "conda activate <env>"
    if ($Args.Count -ge 2 -and $Args[0] -eq 'activate') {
        $envName = $Args[1]
        # Session-only switch to that env
        try {
            Use-Python -Spec "conda:$envName"
            Write-Host "Session Python -> conda:$envName (not persisted)"
        } catch {
            Write-Warning ("Failed to set session interpreter to conda:$($envName): $($_.Exception.Message)")
        }
    }
}

# --- 6) Convenience: quick commands ------------------------------------------
Set-Alias which Get-Command -Scope Global -ErrorAction SilentlyContinue

function pyver { & "$ShimDir\python.bat" -V }
function pipver { & "$ShimDir\python.bat" -m pip --version }

# Uncomment if you want to see current shim state on every new shell
# Show-PyShim
