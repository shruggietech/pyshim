$ErrorActionPreference = 'Stop'
$SepLine = "`n" + ("-" * 60) + "`n"
$TotalDurationMax = 12    # seconds
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

    Write-Host "  Running: $Description" -ForegroundColor Cyan
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
            $JobError | ForEach-Object { Write-Host "      ERROR: $_" -ForegroundColor Red }
        }
        $script:TestsFailed = $true
        return $false
    }

    Write-Host "    OK (duration: $Duration seconds)" -ForegroundColor Green
    
    if ($JobOutput) {
        if ($IsGetCommand) {
            $JsonOutput = $JobOutput | Select-Object CommandType, Name, Version, Source | ConvertTo-Json -Compress
            Write-Host "      $JsonOutput" -ForegroundColor Gray
        } else {
            $FlatOutput = ($JobOutput | Out-String).Trim() -replace "`r`n", ", " -replace "`n", ", "
            Write-Host "      $FlatOutput" -ForegroundColor Gray
        }
    }
    return $true
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
    Import-Module 'C:\bin\shims\pyshim.psm1' -Force
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
    Write-Host "  Skipped (UNC path not accessible)" -ForegroundColor Gray
}

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
