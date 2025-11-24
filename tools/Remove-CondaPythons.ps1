<#
.SYNOPSIS
    Convenience wrapper that forwards to bin/shims/Remove-CondaPythons.ps1.
.DESCRIPTION
    Ensures local tooling matches the scripts shipped with the installed shims by invoking
    the version that lives alongside pyshim.psm1.
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

$ShimScript = Join-Path -Path $PSScriptRoot -ChildPath '..\bin\shims\Remove-CondaPythons.ps1'
$ShimScript = [IO.Path]::GetFullPath($ShimScript)
if (-not (Test-Path -LiteralPath $ShimScript)) {
    throw "Unable to locate $ShimScript. Ensure the repository shims are present."
}

& $ShimScript @PSBoundParameters

#______________________________________________________________________________
## End of script