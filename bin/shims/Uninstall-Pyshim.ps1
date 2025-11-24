<#
.SYNOPSIS
    Removes the pyshim shim directory and cleans up PATH entries.

.DESCRIPTION
    Runs either the module-provided `Uninstall-Pyshim` cmdlet or the bundled standalone logic to delete the shim payload, optional config files, and PATH references. Provides color-coded status messages so the user can see what was removed.

.PARAMETER Force
    Removes unexpected files in the shim directory instead of stopping for review.

.PARAMETER Help
    Display the full help text for this script.

.EXAMPLE
    PS C:\> .\Uninstall-Pyshim.ps1
    Runs the uninstaller in interactive mode and leaves any unexpected files behind.

.EXAMPLE
    PS C:\> .\Uninstall-Pyshim.ps1 -Force
    Forces removal of the shim directory even if extra files are present.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Switch]$Force,

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias('h')]
    [Switch]$Help
)
#______________________________________________________________________________
## Declare Functions

    function Write-PyshimMessage {
        <#
        .SYNOPSIS
            Write a color-coded message to the host.
        .DESCRIPTION
            Outputs a message to the host with color coding based on the message type.
        .PARAMETER Type
            The type of message to write (Info, Action, Success, Warning, Error).
        .PARAMETER Message
            The message text to write.
        .EXAMPLE
            Write-PyshimMessage -Type Info -Message 'This is an informational message.'
        #>
        [CmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='None',DefaultParameterSetName='Default')]
        Param(
            [Parameter(Mandatory=$true)]
            [ValidateSet('Info','Action','Success','Warning','Error')]
            [string]$Type,

            [Parameter(Mandatory=$true)]
            [string]$Message
        )

        switch ($Type) {
            'Info'    { $Color = 'Cyan' }
            'Action'  { $Color = 'Blue' }
            'Success' { $Color = 'Green' }
            'Warning' { $Color = 'Yellow' }
            'Error'   { $Color = 'Red' }
        }

        Write-Host $Message -ForegroundColor $Color
    }

    function Remove-StandalonePyshimProfiles {
        <#
        .SYNOPSIS
            Remove pyshim auto-import entries from all PowerShell profiles.
        .DESCRIPTION
            Scans all PowerShell profile files for pyshim auto-import entries and removes them.
        .PARAMETER ScopeOrder
            An ordered list of profile scopes to process. Defaults to all scopes in standard order.
            (CurrentUserCurrentHost, CurrentUserAllHosts, AllUsersCurrentHost, AllUsersAllHosts)
        .EXAMPLE
            Remove-StandalonePyshimProfiles

            Removes pyshim auto-import entries from all PowerShell profiles.
        #>
        [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High',DefaultParameterSetName='Default')]
        Param(
            [Parameter(Mandatory=$false)]
            [string[]]$ScopeOrder = @('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')
        )

        $SentinelStart = '# >>> pyshim auto-import >>>'
        $SentinelEnd   = '# <<< pyshim auto-import <<<'

        $ProfileTargets = @()
        $ProfileMap = [ordered]@{
            CurrentUserCurrentHost = $PROFILE.CurrentUserCurrentHost
            CurrentUserAllHosts    = $PROFILE.CurrentUserAllHosts
            AllUsersCurrentHost    = $PROFILE.AllUsersCurrentHost
            AllUsersAllHosts       = $PROFILE.AllUsersAllHosts
        }

        foreach ($ScopeName in $ScopeOrder) {
            if (-not $ProfileMap.Contains($ScopeName)) { continue }
            $Path = $ProfileMap[$ScopeName]
            if ([string]::IsNullOrWhiteSpace($Path)) { continue }
            $ProfileTargets += [pscustomobject]@{
                Scope         = $ScopeName
                Path          = $Path
                Origin        = 'pwsh'
                NeedsElevation = ($ScopeName -like 'AllUsers*') -or ($Path -like "$env:ProgramFiles*") -or ($Path -like "$env:WINDIR*")
            }
        }

        $UserDocuments = [Environment]::GetFolderPath('MyDocuments')
        $WinPsUserRoot = Join-Path $UserDocuments 'WindowsPowerShell'
        $WinPsAllUsersRoot = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0'
        $LegacyMap = [ordered]@{
            CurrentUserCurrentHost = Join-Path $WinPsUserRoot 'Microsoft.PowerShell_profile.ps1'
            CurrentUserAllHosts    = Join-Path $WinPsUserRoot 'profile.ps1'
            AllUsersCurrentHost    = Join-Path $WinPsAllUsersRoot 'Microsoft.PowerShell_profile.ps1'
            AllUsersAllHosts       = Join-Path $WinPsAllUsersRoot 'profile.ps1'
        }

        foreach ($ScopeName in $ScopeOrder) {
            if (-not $LegacyMap.Contains($ScopeName)) { continue }
            $Path = $LegacyMap[$ScopeName]
            if ([string]::IsNullOrWhiteSpace($Path)) { continue }
            $ProfileTargets += [pscustomobject]@{
                Scope         = $ScopeName
                Path          = $Path
                Origin        = 'WindowsPowerShell'
                NeedsElevation = ($ScopeName -like 'AllUsers*') -or ($Path -like "$env:ProgramFiles*") -or ($Path -like "$env:WINDIR*")
            }
        }

        if (-not $ProfileTargets) {
            Write-PyshimMessage -Type Info -Message 'No profile files resolved for cleanup.'
            return
        }

        $IsElevated = $false
        try {
            $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
            $IsElevated = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            Write-PyshimMessage -Type Warning -Message 'Unable to determine elevation status; proceeding with profile cleanup best-effort.'
        }

        foreach ($Target in ($ProfileTargets | Sort-Object -Property Path, Origin -Unique)) {
            $ProfilePath = $Target.Path
            $ScopeName = $Target.Scope
            $Origin = $Target.Origin
            $NeedsElevation = $Target.NeedsElevation

            if ([string]::IsNullOrWhiteSpace($ProfilePath)) { continue }
            if ($NeedsElevation -and -not $IsElevated) {
                Write-PyshimMessage -Type Warning -Message "Skipping $Origin $ScopeName profile at $ProfilePath (administrator rights required)."
                continue
            }
            if (-not (Test-Path -LiteralPath $ProfilePath)) {
                continue
            }

            $Content = Get-Content -LiteralPath $ProfilePath -Raw
            if ($Content -eq $null) { continue }
            if (($Content -notmatch [System.Text.RegularExpressions.Regex]::Escape($SentinelStart)) -or ($Content -notmatch [System.Text.RegularExpressions.Regex]::Escape($SentinelEnd))) {
                continue
            }

            $Lines = $Content -split "`r?`n"
            $StartIndex = [Array]::IndexOf($Lines,$SentinelStart)
            if ($StartIndex -lt 0) { continue }
            $EndIndex = [Array]::IndexOf($Lines,$SentinelEnd)
            if ($EndIndex -lt 0 -or $EndIndex -lt $StartIndex) { continue }

            $RangeStart = $StartIndex
            if ($RangeStart -gt 0 -and [string]::IsNullOrWhiteSpace($Lines[$RangeStart - 1])) {
                $RangeStart -= 1
            }

            $Before = if ($RangeStart -gt 0) { $Lines[0..($RangeStart - 1)] } else { @() }
            $After = if ($EndIndex -lt ($Lines.Count - 1)) { $Lines[($EndIndex + 1)..($Lines.Count - 1)] } else { @() }

            while ($Before.Count -gt 0 -and [string]::IsNullOrWhiteSpace($Before[-1])) {
                $Before = if ($Before.Count -gt 1) { $Before[0..($Before.Count - 2)] } else { @() }
            }

            while ($After.Count -gt 0 -and [string]::IsNullOrWhiteSpace($After[0])) {
                $After = if ($After.Count -gt 1) { $After[1..($After.Count - 1)] } else { @() }
            }

            $NewLines = @()
            if ($Before) { $NewLines += $Before }
            if ($After) { $NewLines += $After }
            $NewContent = if ($NewLines) { $NewLines -join "`r`n" } else { '' }

            try {
                Set-Content -LiteralPath $ProfilePath -Value $NewContent -Encoding utf8
                Write-PyshimMessage -Type Success -Message "Removed pyshim auto-import from $ProfilePath ($Origin / $ScopeName)."
            } catch {
                Write-PyshimMessage -Type Warning -Message "Failed to update $($ProfilePath): $($_.Exception.Message)"
            }
        }
    }

    function Invoke-StandalonePyshimUninstall {
        <#
        .SYNOPSIS
            Uninstall pyshim by removing shims and cleaning up environment variables.
        .DESCRIPTION
            This function removes pyshim files from the shim directory, updates the user PATH,
            and removes pyshim auto-import entries from PowerShell profiles.
        .PARAMETER Force
            Force removal even if unexpected files are present.
        .PARAMETER InvokerPath
            The path of the script invoking this uninstall function. If provided, this script will not delete itself immediately but will schedule a cleanup job.
        .EXAMPLE
            Invoke-StandalonePyshimUninstall -Force

            Uninstalls pyshim, forcing removal of unexpected files.
        #>
        [CmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='None',DefaultParameterSetName='Default')]
        Param(
            [Parameter(Mandatory=$false)]
            [Switch]$Force,

            [Parameter(Mandatory=$false)]
            [System.String]$InvokerPath
        )

        if ($InvokerPath) {
            $ShimDir = Split-Path -Parent $InvokerPath
        }
        if (-not $ShimDir) { $ShimDir = 'C:\bin\shims' }

        Write-PyshimMessage -Type Info -Message "Preparing to remove pyshim from $ShimDir"

        $ExpectedCore = 'pip.bat','python.bat','pythonw.bat','pyshim.psm1','Uninstall-Pyshim.ps1'
        $OptionalExact = 'python.env','python.nopersist'
        $OptionalPatterns = 'python@*.env'
        if (-not (Test-Path -LiteralPath $ShimDir)) {
            Write-PyshimMessage -Type Warning -Message "pyshim already appears to be removed (missing $ShimDir)."
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
            Write-PyshimMessage -Type Warning -Message "Additional files were found in $ShimDir. Re-run with -Force to remove everything."
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
                Write-PyshimMessage -Type Success -Message 'Removed C:\bin\shims from the user PATH.'
            }
        }

        $Items = Get-ChildItem -LiteralPath $ShimDir -Force
        foreach ($Item in $Items) {
            if ($InvokerPath -and ($Item.FullName -eq $InvokerPath)) {
                continue
            }
            Write-PyshimMessage -Type Action -Message "Deleting $($Item.Name)"
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
            Write-PyshimMessage -Type Info -Message "Scheduled cleanup job to remove $ShimDir after this script exits."
        } else {
            Write-PyshimMessage -Type Action -Message "Removing directory $ShimDir"
            Remove-Item -LiteralPath $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-PyshimMessage -Type Success -Message "Removed $ShimDir."
        }

        Write-PyshimMessage -Type Action -Message 'Removing pyshim profile hooks.'
        Remove-StandalonePyshimProfiles
        Write-PyshimMessage -Type Success -Message 'pyshim has been removed.'
    }

#______________________________________________________________________________
## Declare Variables and Arrays

    $ShimDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ModulePath = Join-Path -Path $ShimDir -ChildPath 'pyshim.psm1'
    $ThisScriptPath = $MyInvocation.MyCommand.Path

#______________________________________________________________________________
## Execute Operations

    # Catch help text requests
    if (($Help) -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
        Get-Help $ThisScriptPath -Detailed
        exit
    }

    # Main uninstall logic
    Write-PyshimMessage -Type Info -Message 'Starting pyshim uninstall.'

    if (Test-Path -LiteralPath $ModulePath) {
        try {
            Import-Module -Name $ModulePath -Force -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        } catch {
            Write-PyshimMessage -Type Warning -Message 'Failed to import pyshim module; falling back to standalone uninstall logic.'
        }
    }

    if (Get-Command -Name Uninstall-Pyshim -ErrorAction SilentlyContinue) {
        Write-PyshimMessage -Type Info -Message 'Delegating to module-provided Uninstall-Pyshim.'
        $Params = @{ }
        if ($Force) { $Params.Force = $true }
        $Params.InvokerPath = $MyInvocation.MyCommand.Path
        Uninstall-Pyshim @Params
    } else {
        Write-PyshimMessage -Type Info -Message 'Using standalone uninstall routine.'
        Invoke-StandalonePyshimUninstall -Force:$Force -InvokerPath $MyInvocation.MyCommand.Path
    }

#______________________________________________________________________________
## End of script