$ErrorActionPreference = 'Stop'
$SepLine = "`n" + ("-" * 60) + "`n"
$TotalDurationMax = 18    # seconds
$SingleDurationMax = 3    # seconds
$StartTime = Get-Date
$TestsFailed = $false

#-------------------------------------------------------------------------------
# Helper function to run a command with timeout and exit code monitoring
#-------------------------------------------------------------------------------
function Invoke-TimedCommand {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.String]$Description,

        [Parameter(Mandatory=$true)]
        [ScriptBlock]$Command,

        [Parameter(Mandatory=$false)]
        [System.Int32]$TimeoutSeconds = $script:SingleDurationMax,

        [Parameter(Mandatory=$false)]
        [Switch]$IsGetCommand
    )

    Write-Host "    Running: $Description" -ForegroundColor Cyan
    $CommandStart = Get-Date
    $Job = Start-Job -ScriptBlock $Command

    $Completed = Wait-Job -Job $Job -Timeout $TimeoutSeconds
    $CommandEnd = Get-Date
    $Duration = ($CommandEnd - $CommandStart).TotalSeconds

    if ($null -eq $Completed) {
    Write-Host "    TIMEOUT after $Duration seconds (max: $TimeoutSeconds)" -ForegroundColor Red
        Stop-Job -Job $Job -ErrorAction SilentlyContinue
        Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
        $script:TestsFailed = $true
        return $false
    }

    $JobOutput = Receive-Job -Job $Job -ErrorAction SilentlyContinue
    $JobState = $Job.State
    $JobError = $Job.ChildJobs[0].Error

    Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue

    if ($JobState -eq 'Failed' -or ($JobError -and $JobError.Count -gt 0)) {
        Write-Host "    FAILED (duration: $Duration seconds)" -ForegroundColor Red
        if ($JobError) {
            $JobError | ForEach-Object { Write-Host "    ERROR: $_" -ForegroundColor Red }
        }
        $script:TestsFailed = $true
        return $false
    }

    Write-Host "    Result: OK (duration: $Duration seconds)" -ForegroundColor Green
    
    if ($JobOutput) {
        if ($IsGetCommand) {
            $JsonOutput = $JobOutput | Select-Object CommandType, Name, Version, Source | ConvertTo-Json -Compress
            Write-Host "    Output: $JsonOutput" -ForegroundColor Gray
        } else {
            $FlatOutput = ($JobOutput | Out-String).Trim() -replace "`r`n", ", " -replace "`n", ", "
            Write-Host "    Output: $FlatOutput" -ForegroundColor Gray
        }
    }
    return $true
}

function Write-CondaStatus {
    [CmdletBinding()]
    Param()

    Write-Host "Inspecting Conda / Miniconda environment:" -ForegroundColor Yellow

    $Candidates = @()
    if ($env:CONDA_EXE) {
        $Candidates += $env:CONDA_EXE
    }

    try {
        $CommandHit = (Get-Command conda -ErrorAction Stop).Source
        if ($CommandHit) {
            $Candidates += $CommandHit
        }
    } catch {
        # ignored on purpose
    }

    $DefaultUserInstall = Join-Path -Path $env:USERPROFILE -ChildPath 'miniconda3\Scripts\conda.exe'
    $Candidates += $DefaultUserInstall

    Write-Host "    Running: (Conda detection)" -ForegroundColor Cyan
    $Candidates = $Candidates | Where-Object { $_ } | Select-Object -Unique
    if ($Candidates.Count -gt 0) {
        Write-Host "    Output: Candidate paths -> $(($Candidates -join ', '))" -ForegroundColor Gray
    } else {
        Write-Host "    Output: No candidate paths discovered." -ForegroundColor Gray
    }

    $ResolvedConda = $null
    foreach ($Candidate in $Candidates) {
        $ResolvedCandidate = Resolve-Path -LiteralPath $Candidate -ErrorAction SilentlyContinue
        if ($ResolvedCandidate) {
            $ResolvedConda = $ResolvedCandidate.ProviderPath
            break
        }
    }

    if (-not $ResolvedConda) {
        Write-Host "    Result: Conda executable not detected." -ForegroundColor Yellow
        return
    }

    Write-Host "    Result: Found conda executable." -ForegroundColor Green
    #Write-Host "    Output: $ResolvedConda" -ForegroundColor Gray

    Write-Host "    Running: $ResolvedConda --version" -ForegroundColor Cyan
    $VersionOutput = & $ResolvedConda '--version' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Output: $((($VersionOutput | Out-String).Trim()))" -ForegroundColor Gray
    } else {
        Write-Host "    Output: Unable to determine conda version." -ForegroundColor Yellow
    }

    Write-Host "    Running: $ResolvedConda env list --json" -ForegroundColor Cyan
    $EnvJsonRaw = & $ResolvedConda 'env' 'list' '--json' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Output: Unable to enumerate conda environments." -ForegroundColor Yellow
        return
    }

    try {
        $EnvInfo = ($EnvJsonRaw | Out-String | ConvertFrom-Json)
    } catch {
        Write-Host "    Output: Failed to parse conda environment list." -ForegroundColor Yellow
        return
    }

    if (-not $EnvInfo -or -not $EnvInfo.envs) {
        Write-Host "    Output: No conda environments reported." -ForegroundColor Yellow
        return
    }

    $TargetEnvs = 'py310','py311','py312','py313','py314'
    $EnvSummaries = @()
    foreach ($Target in $TargetEnvs) {
        $MatchingPath = $EnvInfo.envs | Where-Object { $_.Split([IO.Path]::DirectorySeparatorChar)[-1].ToLower() -eq $Target }
        if (-not $MatchingPath) {
            $EnvSummaries += ('{0}: missing' -f $Target)
            continue
        }

        #Write-Host "    Running: $ResolvedConda run -n $Target python -c 'import sys; print(sys.version.split()[0])'" -ForegroundColor Cyan
        $VersionProbe = & $ResolvedConda 'run' '-n' $Target 'python' '-c' 'import sys; print(sys.version.split()[0])' 2>&1
        if ($LASTEXITCODE -eq 0) {
            $EnvSummaries += ('{0}: {1}' -f $Target, (($VersionProbe | Out-String).Trim()))
        } else {
            $EnvSummaries += ('{0}: version query failed' -f $Target)
        }
    }

    if ($EnvSummaries.Count -gt 0) {
        Write-Host "    Output: $($EnvSummaries -join ', ')" -ForegroundColor Gray
    }
}

#-------------------------------------------------------------------------------
Write-Host ''
Write-Host "Beginning smoke tests for pyshim." -ForegroundColor Green
#-------------------------------------------------------------------------------

$SepLine | Write-Host
Write-Host "Checking for py, python, and pip commands in PATH:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "where.exe py" -Command {
    where.exe py
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "where.exe python" -Command {
    where.exe python
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "where.exe pip" -Command {
    where.exe pip
    $LASTEXITCODE
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Verifying that py, python, and pip commands are functional:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "Get-Command py" -IsGetCommand -Command {
    Get-Command py -ErrorAction Stop
} | Out-Null

Invoke-TimedCommand -Description "Get-Command python" -IsGetCommand -Command {
    Get-Command python -ErrorAction Stop
} | Out-Null

Invoke-TimedCommand -Description "Get-Command pip" -IsGetCommand -Command {
    Get-Command pip -ErrorAction Stop
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Checking versions of py, python, and pip:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "py -V" -Command {
    py -V
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "python -V" -Command {
    python -V
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "pip --version" -Command {
    pip --version
    $LASTEXITCODE
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Running a simple Python command using the pyshim function Run-WithPython:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "Run-WithPython -Spec 'py:3' -- -c `"print('ok')`"" -Command {
    Import-Module 'C:\bin\shims\pyshim.psm1' -Force -DisableNameChecking
    Run-WithPython -Spec 'py:3' -- -c "print('ok')"
    $LASTEXITCODE
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Testing dotfile search from drive root (regression check for infinite loop):" -ForegroundColor Yellow

Invoke-TimedCommand -Description "python -c `"print('ok from root')`" (from C:\)" -Command {
    Push-Location C:\
    try {
        $output = & python -c "print('ok from root')" 2>&1
        $exitCode = $LASTEXITCODE
        Pop-Location
        if ($exitCode -ne 0) { throw "Exit code: $exitCode" }
        $exitCode
    } catch {
        Pop-Location
        throw
    }
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Testing dotfile search from UNC path (if available):" -ForegroundColor Yellow

$UncPath = "\\localhost\c$"
if (Test-Path -LiteralPath $UncPath -ErrorAction SilentlyContinue) {
    Invoke-TimedCommand -Description "python -c `"print('ok from UNC')`" (from $UncPath)" -Command {
        Push-Location $UncPath
        try {
            $output = & python -c "print('ok from UNC')" 2>&1
            $exitCode = $LASTEXITCODE
            Pop-Location
            if ($exitCode -ne 0) { throw "Exit code: $exitCode" }
            $exitCode
        } catch {
            Pop-Location
            throw
        }
    } | Out-Null
} else {
    Write-Host "    Skipped (UNC path not accessible)" -ForegroundColor Gray
}

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-CondaStatus

#-------------------------------------------------------------------------------
$SepLine | Write-Host
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds

if ($TestsFailed) {
    Write-Host "Total duration: $TotalDuration seconds." -ForegroundColor Red
    Write-Host "Smoke FAILED: One or more tests failed." -ForegroundColor Red
    Write-Host "Exiting script." -ForegroundColor Red
    exit 1
} elseif ($TotalDuration -gt $TotalDurationMax) {
    Write-Host "Total duration: $TotalDuration seconds." -ForegroundColor Red
    Write-Host "Smoke FAILED: Total duration exceeds maximum of $TotalDurationMax seconds." -ForegroundColor Red
    Write-Host "Exiting script." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Total duration: $TotalDuration seconds." -ForegroundColor Green
    Write-Host "Smoke OK (Tests passed successfully)." -ForegroundColor Green
    Write-Host "Exiting script." -ForegroundColor Green
    exit 0
}
