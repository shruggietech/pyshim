<#
.SYNOPSIS
    Remove the managed py310..py314 Conda environments used by pyshim.
.DESCRIPTION
    Imports the local pyshim module and runs Remove-CondaPythons so you can tear down the
    shared Conda interpreters directly from C:\bin\shims.
.PARAMETER CondaPath
    Explicit path to conda.exe. Falls back to CONDA_EXE, PATH lookup, or %USERPROFILE%\miniconda3.
.PARAMETER Environment
    Optional subset of environment names (py310..py314) to remove instead of the default set.
.PARAMETER IgnoreMissing
    Suppress warnings when a requested environment does not exist.
.PARAMETER Help
    Display detailed help for this script.
.EXAMPLE
    .\Remove-CondaPythons.ps1

    Removes every managed environment if it exists.
.EXAMPLE
    .\Remove-CondaPythons.ps1 -Environment py312 -IgnoreMissing

    Remove only py312 without warning when it is already gone.
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

Remove-CondaPythons @ForwardParameters
