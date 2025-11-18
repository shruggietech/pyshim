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

function Uninstall-Pyshim {
    <#
    .SYNOPSIS
        Remove pyshim files and PATH entries from the current machine.
    .PARAMETER Force
        Proceed even if unexpected files exist in the shim directory.
    .PARAMETER InvokerPath
        Internal use. Path to the executing uninstall script so cleanup can finish after exit.
    .EXAMPLE
        Uninstall-Pyshim
    .EXAMPLE
        Uninstall-Pyshim -Force
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
        [Switch]$Force,

        [Parameter(Mandatory=$false)]
        [System.String]$InvokerPath
    )

    $ShimDir = 'C:\bin\shims'
    if (-not (Test-Path -LiteralPath $ShimDir)) {
        Write-Host "pyshim does not appear to be installed (missing $ShimDir)." -ForegroundColor Yellow
        return
    }

    $ExpectedCore = 'pip.bat','python.bat','pythonw.bat','pyshim.psm1','Uninstall-Pyshim.ps1'
    $OptionalExact = 'python.env','python.nopersist'
    $OptionalPatterns = 'python@*.env'

    $Entries = Get-ChildItem -LiteralPath $ShimDir -Force
    $Unexpected = @()
    foreach ($Entry in $Entries) {
        $Name = $Entry.Name
        if ($ExpectedCore -contains $Name) { continue }
        if ($OptionalExact -contains $Name) { continue }
        $MatchesPattern = $false
        foreach ($Pattern in $OptionalPatterns) {
            if ($Name -like $Pattern) {
                $MatchesPattern = $true
                break
            }
        }
        if ($MatchesPattern) { continue }
        $Unexpected += $Entry
    }

    if ($Unexpected.Count -gt 0 -and -not $Force) {
        Write-Warning "Additional files were found in $ShimDir. Re-run with -Force to remove everything."
        foreach ($Item in $Unexpected) {
            Write-Host "    $($Item.Name)" -ForegroundColor Yellow
        }
        return
    }

    $TargetNormalized = $ShimDir.TrimEnd('\\')
    $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($UserPath) {
        $Segments = $UserPath -split ';'
        $Filtered = $Segments | Where-Object { $_ -and ($_.TrimEnd('\\') -ine $TargetNormalized) }
        $NewUserPath = ($Filtered | Where-Object { $_ }) -join ';'
        if ($NewUserPath -ne $UserPath) {
            if ($PSCmdlet.ShouldProcess('User PATH','Remove pyshim entry')) {
                [Environment]::SetEnvironmentVariable('Path',$NewUserPath,'User')
                $EnvSegments = $env:Path -split ';'
                $env:Path = ($EnvSegments | Where-Object { $_.TrimEnd('\\') -ine $TargetNormalized }) -join ';'
                Write-Host "Removed C:\bin\shims from the user PATH." -ForegroundColor Green
            }
        }
    }

    $Items = Get-ChildItem -LiteralPath $ShimDir -Force
    foreach ($Item in $Items) {
        if ($InvokerPath -and ($Item.FullName -eq $InvokerPath)) {
            continue
        }
        if ($PSCmdlet.ShouldProcess($Item.FullName,'Delete file')) {
            Remove-Item -LiteralPath $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($InvokerPath) {
        $Cleanup = {
            param($ScriptPath,$Directory)
            Start-Sleep -Seconds 1
            Remove-Item -LiteralPath $ScriptPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $Directory -Recurse -Force -ErrorAction SilentlyContinue
            $Parent = Split-Path -Parent $Directory
            if ($Parent -and (Test-Path -LiteralPath $Parent)) {
                $Remaining = Get-ChildItem -LiteralPath $Parent -Force -ErrorAction SilentlyContinue
                if (-not $Remaining) {
                    Remove-Item -LiteralPath $Parent -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Start-Job -ScriptBlock $Cleanup -ArgumentList $InvokerPath,$ShimDir | Out-Null
        Write-Host "Scheduled cleanup job to remove $ShimDir after this script exits." -ForegroundColor Green
    } else {
        if ($PSCmdlet.ShouldProcess($ShimDir,'Remove shim directory')) {
            Remove-Item -LiteralPath $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
            $ParentDir = Split-Path -Parent $ShimDir
            if ($ParentDir -and (Test-Path -LiteralPath $ParentDir)) {
                $Remaining = Get-ChildItem -LiteralPath $ParentDir -Force -ErrorAction SilentlyContinue
                if (-not $Remaining) {
                    Remove-Item -LiteralPath $ParentDir -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if (Get-ChildItem Env:PYSHIM_INTERPRETER -ErrorAction SilentlyContinue) {
        Remove-Item Env:PYSHIM_INTERPRETER -ErrorAction SilentlyContinue
    }
    Write-Host "pyshim has been removed." -ForegroundColor Green
}
