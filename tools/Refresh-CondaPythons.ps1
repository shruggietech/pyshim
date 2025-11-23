<#
.SYNOPSIS
    Convenience wrapper that forwards to bin/shims/Refresh-CondaPythons.ps1.
.DESCRIPTION
    Allows repository tooling to reuse the refresh script that ships with the installed
    shims directory so behavior stays consistent between local runs and releases.
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

$ShimScript = Join-Path -Path $PSScriptRoot -ChildPath '..\bin\shims\Refresh-CondaPythons.ps1'
$ShimScript = [IO.Path]::GetFullPath($ShimScript)
if (-not (Test-Path -LiteralPath $ShimScript)) {
    throw "Unable to locate $ShimScript. Ensure the repository shims are present."
}

& $ShimScript @PSBoundParameters
