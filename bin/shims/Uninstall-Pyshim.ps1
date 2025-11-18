[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
Param(
    [Switch]$Force
)

$ShimDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ShimDir -ChildPath 'pyshim.psm1'

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

    $ExpectedCore = 'pip.bat','python.bat','pythonw.bat','pyshim.psm1','Uninstall-Pyshim.ps1'
    $OptionalExact = 'python.env','python.nopersist'
    $OptionalPatterns = 'python@*.env'

    if (-not (Test-Path -LiteralPath $ShimDir)) {
        Write-Host "pyshim already appears to be removed (missing $ShimDir)." -ForegroundColor Yellow
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
        Write-Warning "Additional files were found in $ShimDir. Re-run with -Force to remove everything."
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
            Write-Host "Removed C:\bin\shims from the user PATH." -ForegroundColor Green
        }
    }

    $Items = Get-ChildItem -LiteralPath $ShimDir -Force
    foreach ($Item in $Items) {
        if ($InvokerPath -and ($Item.FullName -eq $InvokerPath)) {
            continue
        }
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
        Write-Host "Scheduled cleanup job to remove $ShimDir after this script exits." -ForegroundColor Green
    } else {
        Remove-Item -LiteralPath $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed $ShimDir." -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $ModulePath) {
    try {
        Import-Module -Name $ModulePath -Force -DisableNameChecking
    } catch {
        Write-Warning "Failed to import pyshim module; falling back to standalone uninstall logic."
    }
}

if (Get-Command -Name Uninstall-Pyshim -ErrorAction SilentlyContinue) {
    $Params = @{ }
    if ($Force) { $Params.Force = $true }
    $Params.InvokerPath = $MyInvocation.MyCommand.Path
    Uninstall-Pyshim @Params
} else {
    Invoke-StandalonePyshimUninstall -Force:$Force -InvokerPath $MyInvocation.MyCommand.Path
}

