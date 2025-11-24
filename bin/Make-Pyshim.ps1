<#
.SYNOPSIS
    Install the pyshim shims and optionally wire them into the user PATH.
.DESCRIPTION
    Copies all files from the repository shim folder (`bin/shims`) into the
    fixed installation directory (`C:\bin\shims`). Existing files are
    overwritten. If the target directory does not exist it is created.

    After copying, the script validates whether `C:\bin\shims` already lives
    in the effective PATH (process, user, or machine scopes). If the entry is
    missing you can either supply `-WritePath` up front or respond to the
    interactive prompt to append it to the user PATH. Refusing the update
    prints the manual command you need to run yourself.
.PARAMETER WritePath
    Automatically append `C:\bin\shims` to the user PATH when it is missing.
    Without this switch the script will prompt for confirmation.
.PARAMETER Help
    Display the full help text for this script.
.PARAMETER SkipCondaRefresh
    Skip the default Conda environment refresh that runs after the shims are copied.
.PARAMETER CondaPath
    Path to conda.exe when auto-detection via CONDA_EXE, PATH, or %USERPROFILE%\miniconda3 fails.
.EXAMPLE
    .\Make-Pyshim.ps1 -WritePath

    Copies the shims into place and appends `C:\bin\shims` to the user PATH if
    it is not already present.
.#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("Path","P")]
    [Switch]$WritePath,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Switch]$SkipCondaRefresh,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [System.String]$CondaPath,

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias("h")]
    [Switch]$Help
)
#______________________________________________________________________________
## Declare Functions

    function Add-PyshimPathEntry {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$TargetPath,

            [Parameter(Mandatory=$true)]
            [System.String]$CurrentUserPath
        )

        $SplitPaths = @()
        if ($CurrentUserPath) {
            $SplitPaths = $CurrentUserPath -split ';'
        }

        if (-not ($SplitPaths | Where-Object { $_.TrimEnd('\') -ieq $TargetPath.TrimEnd('\') })) {
            $SplitPaths = @($SplitPaths | Where-Object { $_ }) + $TargetPath
        }

        return ($SplitPaths | Where-Object { $_ }) -join ';'
    }

    function Get-PyshimPathScopes {
        Param()

        return [PSCustomObject]@{
            Process = $env:Path
            User    = [Environment]::GetEnvironmentVariable('Path','User')
            Machine = [Environment]::GetEnvironmentVariable('Path','Machine')
        }
    }

    function Test-PyshimPathPresence {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$TargetPath,

            [Parameter(Mandatory=$true)]
            [System.String[]]$Scopes
        )

        foreach ($Scope in $Scopes) {
            if (-not $Scope) {
                continue
            }

            $Entries = $Scope -split ';'
            if ($Entries | Where-Object { $_.TrimEnd('\') -ieq $TargetPath.TrimEnd('\') }) {
                return $true
            }
        }

        return $false
    }

#______________________________________________________________________________
## Declare Variables and Arrays

    # Internal self-awareness variables for verbosity/logging
    $thisFunctionReference = "{0}" -f $MyInvocation.MyCommand
    $thisScript = $thisFunctionReference
    $ShimDir = 'C:\bin\shims'
    $SourceDir = Join-Path -Path $PSScriptRoot -ChildPath 'shims'

#______________________________________________________________________________
## Execute Operations

    # Catch Help Text Requests
    if (($Help) -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
        Get-Help -Name $MyInvocation.MyCommand.Path -Full
        Exit 0
    }

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Shim source directory '$SourceDir' was not found."
    }

    if (-not (Test-Path -LiteralPath $ShimDir)) {
        if ($PSCmdlet.ShouldProcess($ShimDir,'Create shim directory')) {
            New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null
        }
    }

    $CopySource = Join-Path -Path $SourceDir -ChildPath '*'
    if ($PSCmdlet.ShouldProcess($ShimDir,'Copy shim files')) {
        Copy-Item -Path $CopySource -Destination $ShimDir -Recurse -Force
        Write-Verbose "[$thisScript] Copied shims from '$SourceDir' to '$ShimDir'."
    }

    $PathScopes = Get-PyshimPathScopes
    $AllScopes = @($PathScopes.Process,$PathScopes.User,$PathScopes.Machine)
    $PathPresent = Test-PyshimPathPresence -TargetPath $ShimDir -Scopes $AllScopes

    if ($PathPresent) {
        Write-Verbose "[$thisScript] Shim directory already present in PATH."
    } else {
        $ShouldWritePath = $false
        if ($WritePath) {
            $ShouldWritePath = $true
        } else {
            $Response = Read-Host "Add '$ShimDir' to your user PATH? [y/N]"
            if ($Response -and ($Response.Trim() -match '^(y|yes)$')) {
                $ShouldWritePath = $true
            }
        }

        if ($ShouldWritePath) {
            if ($PSCmdlet.ShouldProcess('User PATH','Append shim directory')) {
                $NewUserPath = Add-PyshimPathEntry -TargetPath $ShimDir -CurrentUserPath $PathScopes.User
                [Environment]::SetEnvironmentVariable('Path',$NewUserPath,'User')
                $EnvEntries = $env:Path -split ';'
                if (-not ($EnvEntries | Where-Object { $_.TrimEnd('\\') -ieq $ShimDir.TrimEnd('\\') })) {
                    $env:Path = ($EnvEntries + $ShimDir | Where-Object { $_ }) -join ';'
                }
                Write-Host "Added '$ShimDir' to the user PATH. Restart shells that were already open."
            }
        } else {
            Write-Host "Skipping PATH update. To add it later run:`n  [Environment]::SetEnvironmentVariable('Path',( '{0};' + [Environment]::GetEnvironmentVariable('Path','User')).Trim(';'),'User')" -f $ShimDir
        }
    }

    if (-not $SkipCondaRefresh) {
        $ModulePath = Join-Path -Path $ShimDir -ChildPath 'pyshim.psm1'
        if (-not (Test-Path -LiteralPath $ModulePath)) {
            Write-Warning "Unable to locate $ModulePath; skipping Conda environment refresh."
        } else {
            $RefreshArgs = @{ IgnoreMissing = $true }
            if ($PSBoundParameters.ContainsKey('CondaPath')) { $RefreshArgs.CondaPath = $CondaPath }
            if ($PSBoundParameters.ContainsKey('WhatIf')) { $RefreshArgs.WhatIf = $true }
            if ($PSBoundParameters.ContainsKey('Confirm')) { $RefreshArgs.Confirm = $Confirm }
            try {
                Import-Module $ModulePath -DisableNameChecking -Force -ErrorAction Stop -WarningAction SilentlyContinue
                Refresh-CondaPythons @RefreshArgs
            } catch {
                Write-Warning "Conda environment refresh failed: $($_.Exception.Message). Re-run with -SkipCondaRefresh to skip this step."
            }
        }
    } else {
        Write-Verbose 'Skipping Conda environment refresh per -SkipCondaRefresh.'
    }

#______________________________________________________________________________
## End of script