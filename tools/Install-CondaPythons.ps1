<#
.SYNOPSIS
    Convenience wrapper that forwards to bin/shims/Install-CondaPythons.ps1.
.DESCRIPTION
    Keeps repository tooling compatible by launching the script that ships with the
    installed shims, ensuring releases and local runs share the same logic.
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

$ShimScript = Join-Path -Path $PSScriptRoot -ChildPath '..\bin\shims\Install-CondaPythons.ps1'
$ShimScript = [IO.Path]::GetFullPath($ShimScript)
if (-not (Test-Path -LiteralPath $ShimScript)) {
    throw "Unable to locate $ShimScript. Ensure the repository shims are present."
}

& $ShimScript @PSBoundParameters

#______________________________________________________________________________
## End of script