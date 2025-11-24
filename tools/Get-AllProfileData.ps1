<#
.SYNOPSIS
    Dump the contents of every available PowerShell profile script with scope metadata.

.DESCRIPTION
    Traverses the four built-in PowerShell profile scopes (CurrentUser/CurrentHost,
    CurrentUser/AllHosts, AllUsers/CurrentHost, AllUsers/AllHosts), verifies which
    scripts actually exist on the machine, and prints each file preceded by a
    commented header that captures the absolute path and scope. Use this when you
    need to diagnose stray profile snippets (for example, lingering pyshim imports
    that still emit warnings) without manually chasing paths.

    The script is read-only; it never modifies or creates profile files. Missing
    scopes are skipped automatically.

.PARAMETER Help
    Emit the detailed help text for this script and then exit immediately.

.EXAMPLE
    Get-AllProfileData

    Show every profile that exists for the current machine/user along with metadata
    headers so you can identify which file is driving a startup warning.

.EXAMPLE
    Get-AllProfileData | Out-File -FilePath .\profiles.txt -Encoding utf8

    Capture the full dump to disk for later inspection or when sharing evidence in
    a bug report.

#>
[CmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias('h')]
    [Switch]$Help
)

#______________________________________________________________________________
## Declare Functions

    # Nothing needed here for now

#______________________________________________________________________________
## Declare Variables and Arrays

    $SectionLinePart = '_' * 79
    $SectionLine = -join('#', $SectionLinePart)

    $ProfileScopes = [ordered]@{
        'CurrentUserCurrentHost' = $PROFILE.CurrentUserCurrentHost
        'CurrentUserAllHosts'    = $PROFILE.CurrentUserAllHosts
        'AllUsersCurrentHost'    = $PROFILE.AllUsersCurrentHost
        'AllUsersAllHosts'       = $PROFILE.AllUsersAllHosts
    }

    $Profiles = @()
    foreach ($Entry in $ProfileScopes.GetEnumerator()) {
        $ScopeName = $Entry.Key
        $ProfilePath = $Entry.Value
        if (-not $ProfilePath) { continue }
        if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf -ErrorAction SilentlyContinue)) { continue }
        $Profiles += [pscustomobject]@{
            Scope = $ScopeName
            Path  = $ProfilePath
        }
    }

#______________________________________________________________________________
## Execute Operations

    # Catch help text requests
    if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
        Get-Help $MyInvocation.MyCommand.Path -Detailed
        exit
    }

    # Print profile data
    foreach ($Profile in $Profiles) {
        $Header = @(
            $SectionLine,
            '#',
            '# Profile Metadata',
            '#',
            ('#   Path : {0}' -f $Profile.Path),
            ('#   Scope: {0}' -f $Profile.Scope),
            $SectionLine
        ) -join "`n"

        Write-Host "`n$Header" -ForegroundColor Cyan

        try {
            Get-Content -LiteralPath $Profile.Path -Force -ErrorAction Stop
        } catch [System.UnauthorizedAccessException] {
            Write-Warning "Access denied reading '$($Profile.Path)' ($($Profile.Scope)). Run this script from an elevated PowerShell session or view the file manually with administrative rights to capture the remaining profile content."
        } catch {
            Write-Warning "Failed to read '$($Profile.Path)': $($_.Exception.Message)"
        }
    }

#______________________________________________________________________________
## End of script