<#
.SYNOPSIS
    Provision Miniconda environments py310..py314 for pyshim usage.
.DESCRIPTION
    Imports the local pyshim module and invokes Install-CondaPythons so you can create
    or refresh the managed Conda interpreter set directly from C:\bin\shims.
.PARAMETER CondaPath
    Explicit path to conda.exe. Falls back to CONDA_EXE, PATH lookup, or %USERPROFILE%\miniconda3.
.PARAMETER ForceRecreate
    Remove and rebuild environments even when the requested Python version already matches.
.PARAMETER Environment
    Optional subset of environment names (py310..py314) to manage instead of the default set.
.PARAMETER Help
    Display detailed help for this script.
.EXAMPLE
    .\Install-CondaPythons.ps1

    Creates py310..py314 environments using the detected conda installation.
.EXAMPLE
    .\Install-CondaPythons.ps1 -CondaPath 'C:\Tools\miniconda3\Scripts\conda.exe' -ForceRecreate

    Use a custom conda installation and rebuild every environment from scratch.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias('Conda','CondaExe')]
    [System.String]$CondaPath,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Switch]$ForceRecreate,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [string[]]$Environment,

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
if ($ForceRecreate) { $ForwardParameters.ForceRecreate = $true }
if ($Environment) { $ForwardParameters.Environment = $Environment }
if ($PSBoundParameters.ContainsKey('WhatIf')) { $ForwardParameters.WhatIf = $true }
if ($PSBoundParameters.ContainsKey('Confirm')) { $ForwardParameters.Confirm = $Confirm }

Install-CondaPythons @ForwardParameters
