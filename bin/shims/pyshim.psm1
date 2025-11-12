# Save this file here: C:\bin\shims\pyshim.psm1
# Import this file from your $PROFILE in Powershell

function Use-Python {
    <#
    .SYNOPSIS
        Choose a Python interpreter for this session and/or persist it globally.
    .DESCRIPTION
        SPEC accepts absolute path, 'py:3.12', 'py:3', or 'conda:ENV'.
    .PARAMETER Spec
        Interpreter spec.
    .PARAMETER Persist
        Write SPEC to C:\bin\shims\python.env (unless nopersist marker exists).
    .PARAMETER NoPersist
        Delete C:\bin\shims\python.env (session keeps $env:PYSHIM_INTERPRETER only).
    .EXAMPLE
        Use-Python -Spec 'py:3.12' -Persist
    .EXAMPLE
        Use-Python -Spec 'conda:tools'   # session-only
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [System.String]$Spec,

        [Switch]$Persist,

        [Switch]$NoPersist
    )

    $ShimDir = 'C:\bin\shims'
    $GlobalEnv = Join-Path $ShimDir 'python.env'
    $NoPersistMarker = Join-Path $ShimDir 'python.nopersist'

    if ($NoPersist) {
        if (Test-Path $GlobalEnv) { Remove-Item -LiteralPath $GlobalEnv -Force }
        $env:PYSHIM_INTERPRETER = $null
        Write-Host "Global persistence disabled for future calls (file removed)." -ForegroundColor Yellow
        return
    }

    if ($Spec) {
        $env:PYSHIM_INTERPRETER = $Spec
        Write-Host "Session interpreter -> $Spec"
        if ($Persist) {
            if (Test-Path $NoPersistMarker) {
                Write-Warning "Global nopersist marker is present; not writing python.env."
            } else {
                Set-Content -LiteralPath $GlobalEnv -Value $Spec -NoNewline -Encoding ASCII
                Write-Host "Persisted globally -> $GlobalEnv"
            }
        }
    } else {
        if (Test-Path $GlobalEnv) {
            $env:PYSHIM_INTERPRETER = Get-Content -LiteralPath $GlobalEnv -Raw
            Write-Host "Session now matching global -> $($env:PYSHIM_INTERPRETER)"
        } else {
            Write-Host "No SPEC provided and no global python.env; using shim fallbacks."
        }
    }
}

function Disable-PythonPersistence {
    <#
    .SYNOPSIS
        Make shim ignore python.env without deleting it.
    #>
    [CmdletBinding()]
    Param()
    $marker = 'C:\bin\shims\python.nopersist'
    if (-not (Test-Path $marker)) { New-Item -ItemType File -Path $marker | Out-Null }
    Write-Host "Created $marker. Global persistence is now ignored."
}

function Enable-PythonPersistence {
    <#
    .SYNOPSIS
        Re-enable reading python.env.
    #>
    [CmdletBinding()]
    Param()
    $marker = 'C:\bin\shims\python.nopersist'
    if (Test-Path $marker) { Remove-Item -LiteralPath $marker -Force }
    Write-Host "Removed nopersist marker. Global persistence active again."
}

function Set-AppPython {
    <#
    .SYNOPSIS
        Pin an interpreter SPEC for a named app (used when PYSHIM_TARGET=App).
    .EXAMPLE
        Set-AppPython -App 'MyService' -Spec 'conda:svc'
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)]
        [System.String]$App,

        [Parameter(Mandatory=$true)]
        [System.String]$Spec
    )
    $file = "C:\bin\shims\python@$App.env"
    Set-Content -LiteralPath $file -Value $Spec -NoNewline -Encoding ASCII
    Write-Host "Wrote $file => $Spec"
}

function Run-WithPython {
    <#
    .SYNOPSIS
        One-shot run with a specific interpreter, no persistence.
    .EXAMPLE
        Run-WithPython -Spec 'py:3.11' -- -m pip --version
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.String]$Spec,

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Args
    )
    & "C:\bin\shims\python.bat" --interpreter "$Spec" -- @Args
}
