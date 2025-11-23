<#
.SYNOPSIS
    Wipe and rebuild the managed py310..py314 Conda environments used by pyshim.
.DESCRIPTION
    Imports the local pyshim module and invokes Refresh-CondaPythons, which removes each
    managed environment and recreates it with the requested interpreter versions.
.PARAMETER CondaPath
    Explicit path to conda.exe. Falls back to CONDA_EXE, PATH lookup, or %USERPROFILE%\miniconda3.
.PARAMETER Environment
    Optional subset of environment names (py310..py314) to refresh instead of the default set.
.PARAMETER IgnoreMissing
    Suppress warnings when an environment does not exist prior to removal.
.PARAMETER Help
    Display detailed help for this script.
.EXAMPLE
    .\Refresh-CondaPythons.ps1

    Removes and recreates the full managed py310..py314 environment set.
.EXAMPLE
    .\Refresh-CondaPythons.ps1 -Environment py312 -IgnoreMissing

    Rebuild only the py312 environment and skip warnings if it is missing.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias('Conda','CondaExe')]
    [System.String]$CondaPath,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [string[]]$Environment,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Switch]$IgnoreMissing,

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias('h')]
    [Switch]$Help
)

if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
    Get-Help -Name $MyInvocation.MyCommand.Path -Detailed
    exit
}

$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'pyshim.psm1'
if (-not (Test-Path -LiteralPath $ModulePath)) {
    throw "Unable to locate pyshim.psm1 at $ModulePath. Ensure pyshim is installed."
}

Import-Module $ModulePath -DisableNameChecking -Force -ErrorAction Stop -WarningAction SilentlyContinue

$ForwardParameters = @{}
if ($PSBoundParameters.ContainsKey('CondaPath')) { $ForwardParameters.CondaPath = $CondaPath }
if ($Environment) { $ForwardParameters.Environment = $Environment }
if ($IgnoreMissing) { $ForwardParameters.IgnoreMissing = $true }
if ($PSBoundParameters.ContainsKey('WhatIf')) { $ForwardParameters.WhatIf = $true }
if ($PSBoundParameters.ContainsKey('Confirm')) { $ForwardParameters.Confirm = $Confirm }

Refresh-CondaPythons @ForwardParameters
