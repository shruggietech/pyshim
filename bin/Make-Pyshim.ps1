<#
.SYNOPSIS
    Perform the initial setup process for pyshim
.DESCRIPTION

.PARAMETER Help
    
.EXAMPLE

#>
[CmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias("h")]
    [Switch]$Help
)

# Catch Help Text Requests
if (($Help) -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
    Get-Help -Name $MyInvocation.MyCommand.Path -Full
    Exit 0
}
