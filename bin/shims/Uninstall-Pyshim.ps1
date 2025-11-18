<#
.SYNOPSIS
Removes the pyshim shim directory and cleans up PATH entries.

.DESCRIPTION
Runs either the module-provided `Uninstall-Pyshim` cmdlet or the bundled standalone logic to delete the shim payload, optional config files, and PATH references. Provides color-coded status messages so the user can see what was removed.

.PARAMETER Force
Removes unexpected files in the shim directory instead of stopping for review.

.EXAMPLE
PS C:\> .\Uninstall-Pyshim.ps1
Runs the uninstaller in interactive mode and leaves any unexpected files behind.

.EXAMPLE
PS C:\> .\Uninstall-Pyshim.ps1 -Force
Forces removal of the shim directory even if extra files are present.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
Param(
    [Switch]$Force
)

$ShimDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ShimDir -ChildPath 'pyshim.psm1'

function Write-PyshimMessage {
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Info','Action','Success','Warning','Error')]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    switch ($Type) {
        'Info'    { $Color = 'Cyan' }
        'Action'  { $Color = 'Blue' }
        'Success' { $Color = 'Green' }
        'Warning' { $Color = 'Yellow' }
        'Error'   { $Color = 'Red' }
    }

    Write-Host $Message -ForegroundColor $Color
}

function Invoke-StandalonePyshimUninstall {
    Param(
        [Switch]$Force,
        [Parameter(Mandatory=$false)]
        [System.String]$InvokerPath
    )

    if ($InvokerPath) {
        $ShimDir = Split-Path -Parent $InvokerPath
    }
    if (-not $ShimDir) { $ShimDir = 'C:\bin\shims' }

    Write-PyshimMessage -Type Info -Message "Preparing to remove pyshim from $ShimDir"

    $ExpectedCore = 'pip.bat','python.bat','pythonw.bat','pyshim.psm1','Uninstall-Pyshim.ps1'
    $OptionalExact = 'python.env','python.nopersist'
    $OptionalPatterns = 'python@*.env'
    if (-not (Test-Path -LiteralPath $ShimDir)) {
        Write-PyshimMessage -Type Warning -Message "pyshim already appears to be removed (missing $ShimDir)."
        return
    }

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
        Write-PyshimMessage -Type Warning -Message "Additional files were found in $ShimDir. Re-run with -Force to remove everything."
        foreach ($Item in $Unexpected) {
            Write-Host "    $($Item.Name)" -ForegroundColor Yellow
        }
        return
    }

    $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($UserPath) {
        $Target = $ShimDir.TrimEnd('\\')
        $Parts = $UserPath -split ';'
        $Filtered = $Parts | Where-Object { $_ -and ($_.TrimEnd('\\') -ine $Target) }
        $NewUserPath = ($Filtered | Where-Object { $_ }) -join ';'
        if ($NewUserPath -ne $UserPath) {
            [Environment]::SetEnvironmentVariable('Path',$NewUserPath,'User')
            $EnvParts = $env:Path -split ';'
            $env:Path = ($EnvParts | Where-Object { $_.TrimEnd('\\') -ine $Target }) -join ';'
            Write-PyshimMessage -Type Success -Message 'Removed C:\bin\shims from the user PATH.'
        }
    }

    $Items = Get-ChildItem -LiteralPath $ShimDir -Force
    foreach ($Item in $Items) {
        if ($InvokerPath -and ($Item.FullName -eq $InvokerPath)) {
            continue
        }
        Write-PyshimMessage -Type Action -Message "Deleting $($Item.Name)"
        Remove-Item -LiteralPath $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($InvokerPath) {
        $Cleanup = {
            param($ScriptPath,$Directory)
            Start-Sleep -Seconds 1
            Remove-Item -LiteralPath $ScriptPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $Directory -Recurse -Force -ErrorAction SilentlyContinue
        }
        Start-Job -ScriptBlock $Cleanup -ArgumentList $InvokerPath,$ShimDir | Out-Null
        Write-PyshimMessage -Type Info -Message "Scheduled cleanup job to remove $ShimDir after this script exits."
    } else {
        Write-PyshimMessage -Type Action -Message "Removing directory $ShimDir"
        Remove-Item -LiteralPath $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-PyshimMessage -Type Success -Message "Removed $ShimDir."
    }

    Write-PyshimMessage -Type Success -Message 'pyshim has been removed.'
}

Write-PyshimMessage -Type Info -Message 'Starting pyshim uninstall.'

if (Test-Path -LiteralPath $ModulePath) {
    try {
        Import-Module -Name $ModulePath -Force -DisableNameChecking
    } catch {
        Write-PyshimMessage -Type Warning -Message 'Failed to import pyshim module; falling back to standalone uninstall logic.'
    }
}

if (Get-Command -Name Uninstall-Pyshim -ErrorAction SilentlyContinue) {
    Write-PyshimMessage -Type Info -Message 'Delegating to module-provided Uninstall-Pyshim.'
    $Params = @{ }
    if ($Force) { $Params.Force = $true }
    $Params.InvokerPath = $MyInvocation.MyCommand.Path
    Uninstall-Pyshim @Params
} else {
    Write-PyshimMessage -Type Info -Message 'Using standalone uninstall routine.'
    Invoke-StandalonePyshimUninstall -Force:$Force -InvokerPath $MyInvocation.MyCommand.Path
}

