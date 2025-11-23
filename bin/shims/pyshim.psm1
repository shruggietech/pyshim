<#
.SYNOPSIS
    PowerShell helpers that manage the pyshim directory, interpreter selection, and profile hooks.

.DESCRIPTION
    Install this module alongside the shims in C:\bin\shims and import it from your PowerShell profile
    to expose cmdlets such as Use-Python, Enable-PyshimProfile, Update-Pyshim, and Uninstall-Pyshim.
    These commands coordinate interpreter specs, keep shim config files up to date, and automate
    profile wiring so `python.bat` always resolves to the interpreter you expect.

.PARAMETER Help
    Emit the detailed help for this module (equivalent to Get-Help on the file) and exit immediately.

.EXAMPLE
    Import-Module 'C:\bin\shims\pyshim.psm1' -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Recommended import statement (mirrors the profile snippet the installer wires up) that avoids verb
    warnings and other benign noise while making the pyshim cmdlets available for the session.

.EXAMPLE
    Import-Module 'C:\bin\shims\pyshim.psm1' -DisableNameChecking -ArgumentList -Help
    Shows the module help text without importing the cmdlets.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias('h')]
    [Switch]$Help
)

#______________________________________________________________________________
## Declare Functions

    function Use-Python {
        <#
        .SYNOPSIS
            Choose a Python interpreter for this session and/or persist it globally.
        .DESCRIPTION
            SPEC accepts absolute path, 'py:3.12', 'py:3', or 'conda:ENV'.
        .PARAMETER Spec
            Interpreter spec.
        .PARAMETER Persist
            Write SPEC to C:\bin\shims\python.env (unless nopersist marker exists).
        .PARAMETER NoPersist
            Delete C:\bin\shims\python.env (session keeps $env:PYSHIM_INTERPRETER only).
        .EXAMPLE
            Use-Python -Spec 'py:3.12' -Persist
        .EXAMPLE
            Use-Python -Spec 'conda:tools'   # session-only
        #>
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$Spec,

            [Switch]$Persist,

            [Switch]$NoPersist
        )

        $ShimDir = 'C:\bin\shims'
        $GlobalEnv = Join-Path $ShimDir 'python.env'
        $NoPersistMarker = Join-Path $ShimDir 'python.nopersist'

        if ($NoPersist) {
            if (Test-Path $GlobalEnv) { Remove-Item -LiteralPath $GlobalEnv -Force }
            $env:PYSHIM_INTERPRETER = $null
            Write-Host "Global persistence disabled for future calls (file removed)." -ForegroundColor Yellow
            return
        }

        if ($Spec) {
            $env:PYSHIM_INTERPRETER = $Spec
            Write-Host "Session interpreter -> $Spec"
            if ($Persist) {
                if (Test-Path $NoPersistMarker) {
                    Write-Warning "Global nopersist marker is present; not writing python.env."
                } else {
                    Set-Content -LiteralPath $GlobalEnv -Value $Spec -NoNewline -Encoding ASCII
                    Write-Host "Persisted globally -> $GlobalEnv"
                }
            }
        } else {
            if (Test-Path $GlobalEnv) {
                $env:PYSHIM_INTERPRETER = Get-Content -LiteralPath $GlobalEnv -Raw
                Write-Host "Session now matching global -> $($env:PYSHIM_INTERPRETER)"
            } else {
                Write-Host "No SPEC provided and no global python.env; using shim fallbacks."
            }
        }
    }

    function Disable-PythonPersistence {
        <#
        .SYNOPSIS
            Make shim ignore python.env without deleting it.
        #>
        [CmdletBinding()]
        Param()
        $marker = 'C:\bin\shims\python.nopersist'
        if (-not (Test-Path $marker)) { New-Item -ItemType File -Path $marker | Out-Null }
        Write-Host "Created $marker. Global persistence is now ignored."
    }

    function Enable-PythonPersistence {
        <#
        .SYNOPSIS
            Re-enable reading python.env.
        #>
        [CmdletBinding()]
        Param()
        $marker = 'C:\bin\shims\python.nopersist'
        if (Test-Path $marker) { Remove-Item -LiteralPath $marker -Force }
        Write-Host "Removed nopersist marker. Global persistence active again."
    }

    function Enable-PyshimProfile {
        <#
        .SYNOPSIS
            Append a guarded pyshim import block to PowerShell profile files.
        .DESCRIPTION
            Ensures the pyshim module auto-loads for selected profile scopes without clobbering existing
            content. Creates profile files when missing, preserves backups, and inserts a sentinel block
            only when it is not already present. Defaults to CurrentUserAllHosts and CurrentUserCurrentHost
            for the active pwsh installation; optionally includes Windows PowerShell profiles.
        .PARAMETER Scope
            One or more profile scopes to update. Defaults to CurrentUserAllHosts and CurrentUserCurrentHost.
            Valid values: CurrentUserCurrentHost, CurrentUserAllHosts, AllUsersCurrentHost, AllUsersAllHosts.
        .PARAMETER IncludeWindowsPowerShell
            Also update the equivalent Windows PowerShell 5.x profiles under WindowsPowerShell directories.
        .PARAMETER NoBackup
            Skip creating a .pyshim.bak backup alongside existing profile files.
        .EXAMPLE
            Enable-PyshimProfile
        .EXAMPLE
            Enable-PyshimProfile -Scope AllUsersAllHosts -IncludeWindowsPowerShell
        #>
        [CmdletBinding(SupportsShouldProcess=$true)]
        Param(
            [Parameter(Mandatory=$false)]
            [ValidateSet('CurrentUserCurrentHost','CurrentUserAllHosts','AllUsersCurrentHost','AllUsersAllHosts')]
            [string[]]$Scope = @('CurrentUserAllHosts','CurrentUserCurrentHost'),

            [Switch]$IncludeWindowsPowerShell,

            [Switch]$NoBackup
        )

        $ProfileMap = [ordered]@{
            CurrentUserCurrentHost = $PROFILE.CurrentUserCurrentHost
            CurrentUserAllHosts    = $PROFILE.CurrentUserAllHosts
            AllUsersCurrentHost    = $PROFILE.AllUsersCurrentHost
            AllUsersAllHosts       = $PROFILE.AllUsersAllHosts
        }

        $Targets = @()
        foreach ($Requested in $Scope) {
            if (-not $ProfileMap.Contains($Requested)) { continue }
            $Path = $ProfileMap[$Requested]
            if ([string]::IsNullOrWhiteSpace($Path)) { continue }
            $Targets += [pscustomobject]@{
                Scope  = $Requested
                Path   = $Path
                Origin = 'pwsh'
            }
        }

        if ($IncludeWindowsPowerShell) {
            $UserDocuments = [Environment]::GetFolderPath('MyDocuments')
            $WinPsUserRoot = Join-Path $UserDocuments 'WindowsPowerShell'
            $WinPsAllUsersRoot = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0'

            $LegacyMap = [ordered]@{
                CurrentUserCurrentHost = Join-Path $WinPsUserRoot 'Microsoft.PowerShell_profile.ps1'
                CurrentUserAllHosts    = Join-Path $WinPsUserRoot 'profile.ps1'
                AllUsersCurrentHost    = Join-Path $WinPsAllUsersRoot 'Microsoft.PowerShell_profile.ps1'
                AllUsersAllHosts       = Join-Path $WinPsAllUsersRoot 'profile.ps1'
            }

            foreach ($Requested in $Scope) {
                if (-not $LegacyMap.Contains($Requested)) { continue }
                $Path = $LegacyMap[$Requested]
                if ([string]::IsNullOrWhiteSpace($Path)) { continue }
                $Targets += [pscustomobject]@{
                    Scope  = $Requested
                    Path   = $Path
                    Origin = 'WindowsPowerShell'
                }
            }
        }

        if (-not $Targets) {
            Write-Warning 'No valid profile paths resolved for the requested scope(s).'
            return
        }

        $ScopeOrder = @('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')

        $Targets = $Targets |
            Sort-Object -Property Path, Origin -Unique |
            Sort-Object -Property @{Expression = { [Array]::IndexOf($ScopeOrder,$_.Scope) } },
                                    @{Expression = { $_.Origin } },
                                    @{Expression = { $_.Path } }

        $AppliedScopesByOrigin = @{}

        $SentinelStart = '# >>> pyshim auto-import >>>'
        $SentinelEnd   = '# <<< pyshim auto-import <<<'
        $ShimModulePath = 'C:\bin\shims\pyshim.psm1'
        $SnippetLines = @(
            $SentinelStart
            "if (Test-Path '$ShimModulePath') {"
            '    try {'
            "        Import-Module '$ShimModulePath' -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue"
            '    } catch {'
            '        Write-Verbose "pyshim auto-import failed: $($_.Exception.Message)"'
            '    }'
            '}'
            $SentinelEnd
        )
        $Snippet = $SnippetLines -join "`r`n"

        $IsElevated = $false
        try {
            $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
            $IsElevated = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            Write-Verbose 'Unable to determine elevation status for profile updates.'
        }

        foreach ($Target in $Targets) {
            $ProfilePath = $Target.Path
            $ScopeName = $Target.Scope
            $Origin = $Target.Origin

            if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
                continue
            }

            $Directory = Split-Path -Parent $ProfilePath
            if (-not $Directory) {
                continue
            }

            $NeedsElevation = ($ScopeName -like 'AllUsers*') -or ($ProfilePath -like "$env:ProgramFiles*") -or ($ProfilePath -like "$env:WINDIR*")
            if ($NeedsElevation -and -not $IsElevated) {
                Write-Warning "Skipping $Origin $ScopeName profile at $ProfilePath (administrator rights required)."
                continue
            }

            $AppliedForOrigin = if ($AppliedScopesByOrigin.ContainsKey($Origin)) { $AppliedScopesByOrigin[$Origin] } else { @() }
            $SkipForRedundancy = $false
            $CurrentIndex = [Array]::IndexOf($ScopeOrder,$ScopeName)
            foreach ($AppliedScope in $AppliedForOrigin) {
                $AppliedIndex = [Array]::IndexOf($ScopeOrder,$AppliedScope)
                if ($AppliedIndex -ge 0 -and $CurrentIndex -ge 0 -and $AppliedIndex -le $CurrentIndex) {
                    $SkipForRedundancy = $true
                    break
                }
            }
            if ($SkipForRedundancy) {
                Write-Verbose "Skipping $Origin $ScopeName because a broader pyshim profile block already exists."
                continue
            }

            if (-not (Test-Path -LiteralPath $Directory)) {
                if ($PSCmdlet.ShouldProcess($Directory,'Create profile directory')) {
                    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
                } else {
                    continue
                }
            }

            $ProfileExists = Test-Path -LiteralPath $ProfilePath
            $ExistingContent = ''
            if ($ProfileExists) {
                $ExistingContent = Get-Content -LiteralPath $ProfilePath -Raw
                $HasSentinel = ($ExistingContent -match [System.Text.RegularExpressions.Regex]::Escape($SentinelStart)) -and
                               ($ExistingContent -match [System.Text.RegularExpressions.Regex]::Escape($SentinelEnd))
                if ($HasSentinel) {
                    $HasDisableFlag = $ExistingContent -match '-DisableNameChecking'
                    if ($HasDisableFlag) {
                        Write-Verbose "pyshim auto-import block already present in $ProfilePath."
                        continue
                    }

                    Write-Verbose "pyshim auto-import block in $ProfilePath is outdated; refreshing with latest import command."
                    $DisableParams = @{ Scope = @($ScopeName); NoBackup = $NoBackup; Confirm = $false }
                    if ($Origin -eq 'WindowsPowerShell') {
                        $DisableParams.IncludeWindowsPowerShell = $true
                    }
                    Disable-PyshimProfile @DisableParams | Out-Null

                    if (Test-Path -LiteralPath $ProfilePath) {
                        $ExistingContent = Get-Content -LiteralPath $ProfilePath -Raw
                    } else {
                        $ExistingContent = ''
                        if ($PSCmdlet.ShouldProcess($ProfilePath,'Create profile file')) {
                            New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
                            $ProfileExists = $true
                        } else {
                            continue
                        }
                    }
                }
                if (-not $NoBackup) {
                    $BackupPath = "$ProfilePath.pyshim.bak"
                    if (-not (Test-Path -LiteralPath $BackupPath)) {
                        Copy-Item -LiteralPath $ProfilePath -Destination $BackupPath -Force
                    }
                }
            } else {
                if ($PSCmdlet.ShouldProcess($ProfilePath,'Create profile file')) {
                    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
                    $ProfileExists = $true
                    $ExistingContent = ''
                } else {
                    continue
                }
            }

            $AppendValue = $Snippet
            if (-not [string]::IsNullOrEmpty($ExistingContent)) {
                if ($ExistingContent.EndsWith("`n")) {
                    $AppendValue = "`n$Snippet"
                } else {
                    $AppendValue = "`r`n$Snippet"
                }
            }

            if ($PSCmdlet.ShouldProcess($ProfilePath,"Insert pyshim auto-import block for $Origin $ScopeName")) {
                Add-Content -LiteralPath $ProfilePath -Value $AppendValue -Encoding utf8
                Write-Host "Added pyshim auto-import to $ProfilePath ($Origin / $ScopeName)." -ForegroundColor Green
                if (-not $AppliedScopesByOrigin.ContainsKey($Origin)) {
                    $AppliedScopesByOrigin[$Origin] = @()
                }
                $AppliedScopesByOrigin[$Origin] = $AppliedScopesByOrigin[$Origin] + $ScopeName
            }
        }

        if ($AppliedScopesByOrigin.Count -gt 0) {
            $ScopesToPrune = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($OriginEntry in $AppliedScopesByOrigin.GetEnumerator()) {
                foreach ($ScopeRecorded in $OriginEntry.Value) {
                    $RecordedIndex = [Array]::IndexOf($ScopeOrder,$ScopeRecorded)
                    if ($RecordedIndex -ge 0 -and $RecordedIndex -lt ($ScopeOrder.Count - 1)) {
                        for ($k = $RecordedIndex + 1; $k -lt $ScopeOrder.Count; $k++) {
                            [void]$ScopesToPrune.Add($ScopeOrder[$k])
                        }
                    }
                }
            }

            if ($ScopesToPrune.Count -gt 0) {
                $ScopesArray = $ScopesToPrune.ToArray()
                Disable-PyshimProfile -Scope $ScopesArray -IncludeWindowsPowerShell:$IncludeWindowsPowerShell -NoBackup:$NoBackup -Confirm:$false | Out-Null
            }
        }
    }

    function Disable-PyshimProfile {
        <#
        .SYNOPSIS
            Remove the pyshim auto-import block from PowerShell profile files.
        .DESCRIPTION
            Mirrors Enable-PyshimProfile by locating the sentinel block in each targeted profile and
            deleting it. Honors the same scope selection, optional Windows PowerShell targeting, and
            backup behavior so an enable/disable cycle is reversible across the same paths.
        .PARAMETER Scope
            One or more profile scopes to update. Defaults to CurrentUserAllHosts and CurrentUserCurrentHost.
            Valid values: CurrentUserCurrentHost, CurrentUserAllHosts, AllUsersCurrentHost, AllUsersAllHosts.
        .PARAMETER IncludeWindowsPowerShell
            Also remove the block from the equivalent Windows PowerShell 5.x profiles under WindowsPowerShell directories.
        .PARAMETER NoBackup
            Skip creating a .pyshim.bak backup before editing existing profile files.
        .EXAMPLE
            Disable-PyshimProfile
        .EXAMPLE
            Disable-PyshimProfile -Scope AllUsersAllHosts -IncludeWindowsPowerShell
        #>
        [CmdletBinding(SupportsShouldProcess=$true)]
        Param(
            [Parameter(Mandatory=$false)]
            [ValidateSet('CurrentUserCurrentHost','CurrentUserAllHosts','AllUsersCurrentHost','AllUsersAllHosts')]
            [string[]]$Scope = @('CurrentUserAllHosts','CurrentUserCurrentHost'),

            [Switch]$IncludeWindowsPowerShell,

            [Switch]$NoBackup
        )

        $ProfileMap = [ordered]@{
            CurrentUserCurrentHost = $PROFILE.CurrentUserCurrentHost
            CurrentUserAllHosts    = $PROFILE.CurrentUserAllHosts
            AllUsersCurrentHost    = $PROFILE.AllUsersCurrentHost
            AllUsersAllHosts       = $PROFILE.AllUsersAllHosts
        }

        $Targets = @()
        foreach ($Requested in $Scope) {
            if (-not $ProfileMap.Contains($Requested)) { continue }
            $Path = $ProfileMap[$Requested]
            if ([string]::IsNullOrWhiteSpace($Path)) { continue }
            $Targets += [pscustomobject]@{
                Scope  = $Requested
                Path   = $Path
                Origin = 'pwsh'
            }
        }

        if ($IncludeWindowsPowerShell) {
            $UserDocuments = [Environment]::GetFolderPath('MyDocuments')
            $WinPsUserRoot = Join-Path $UserDocuments 'WindowsPowerShell'
            $WinPsAllUsersRoot = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0'

            $LegacyMap = [ordered]@{
                CurrentUserCurrentHost = Join-Path $WinPsUserRoot 'Microsoft.PowerShell_profile.ps1'
                CurrentUserAllHosts    = Join-Path $WinPsUserRoot 'profile.ps1'
                AllUsersCurrentHost    = Join-Path $WinPsAllUsersRoot 'Microsoft.PowerShell_profile.ps1'
                AllUsersAllHosts       = Join-Path $WinPsAllUsersRoot 'profile.ps1'
            }

            foreach ($Requested in $Scope) {
                if (-not $LegacyMap.Contains($Requested)) { continue }
                $Path = $LegacyMap[$Requested]
                if ([string]::IsNullOrWhiteSpace($Path)) { continue }
                $Targets += [pscustomobject]@{
                    Scope  = $Requested
                    Path   = $Path
                    Origin = 'WindowsPowerShell'
                }
            }
        }

        if (-not $Targets) {
            Write-Warning 'No valid profile paths resolved for the requested scope(s).'
            return
        }

        $Targets = $Targets | Sort-Object -Property Path, Origin -Unique

        $SentinelStart = '# >>> pyshim auto-import >>>'
        $SentinelEnd   = '# <<< pyshim auto-import <<<'

        $IsElevated = $false
        try {
            $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
            $IsElevated = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            Write-Verbose 'Unable to determine elevation status for profile updates.'
        }

        foreach ($Target in $Targets) {
            $ProfilePath = $Target.Path
            $ScopeName = $Target.Scope
            $Origin = $Target.Origin

            if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
                continue
            }

            $Directory = Split-Path -Parent $ProfilePath
            if (-not $Directory) {
                continue
            }

            $NeedsElevation = ($ScopeName -like 'AllUsers*') -or ($ProfilePath -like "$env:ProgramFiles*") -or ($ProfilePath -like "$env:WINDIR*")
            if ($NeedsElevation -and -not $IsElevated) {
                Write-Warning "Skipping $Origin $ScopeName profile at $ProfilePath (administrator rights required)."
                continue
            }

            if (-not (Test-Path -LiteralPath $ProfilePath)) {
                Write-Verbose "Profile file $ProfilePath does not exist; nothing to remove."
                continue
            }

            $ExistingContent = Get-Content -LiteralPath $ProfilePath -Raw
            if ($ExistingContent -eq $null) {
                continue
            }

            $Lines = $ExistingContent -split "`r?`n"
            $StartIndex = -1
            for ($i = 0; $i -lt $Lines.Count; $i++) {
                if ($Lines[$i] -eq $SentinelStart) {
                    $StartIndex = $i
                    break
                }
            }

            if ($StartIndex -lt 0) {
                Write-Verbose "No pyshim auto-import block found in $ProfilePath."
                continue
            }

            $EndIndex = -1
            for ($j = $StartIndex; $j -lt $Lines.Count; $j++) {
                if ($Lines[$j] -eq $SentinelEnd) {
                    $EndIndex = $j
                    break
                }
            }

            if ($EndIndex -lt 0) {
                Write-Verbose "Found start sentinel without matching end in $ProfilePath; skipping removal."
                continue
            }

            $RangeStart = $StartIndex
            if ($RangeStart -gt 0 -and [string]::IsNullOrWhiteSpace($Lines[$RangeStart - 1])) {
                $RangeStart -= 1
            }

            $RangeEnd = $EndIndex
            $Before = if ($RangeStart -gt 0) { $Lines[0..($RangeStart - 1)] } else { @() }
            $After = @()
            if ($RangeEnd -lt ($Lines.Count - 1)) {
                $After = $Lines[($RangeEnd + 1)..($Lines.Count - 1)]
            }

            while ($Before.Count -gt 0 -and [string]::IsNullOrWhiteSpace($Before[-1])) {
                $Before = if ($Before.Count -gt 1) { $Before[0..($Before.Count - 2)] } else { @() }
            }

            while ($After.Count -gt 0 -and [string]::IsNullOrWhiteSpace($After[0])) {
                $After = if ($After.Count -gt 1) { $After[1..($After.Count - 1)] } else { @() }
            }

            $NewLines = @()
            if ($Before) { $NewLines += $Before }
            if ($After) { $NewLines += $After }

            $NewContent = $null
            if ($NewLines.Count -gt 0) {
                $NewContent = $NewLines -join "`r`n"
            } else {
                $NewContent = ''
            }

            if (-not $NoBackup) {
                $BackupPath = "$ProfilePath.pyshim.bak"
                if (-not (Test-Path -LiteralPath $BackupPath)) {
                    Copy-Item -LiteralPath $ProfilePath -Destination $BackupPath -Force
                }
            }

            if ($PSCmdlet.ShouldProcess($ProfilePath,"Remove pyshim auto-import block for $Origin $ScopeName")) {
                Set-Content -LiteralPath $ProfilePath -Value $NewContent -Encoding utf8
                Write-Host "Removed pyshim auto-import from $ProfilePath ($Origin / $ScopeName)." -ForegroundColor Green
            }
        }
    }

    function Set-AppPython {
        <#
        .SYNOPSIS
            Pin an interpreter SPEC for a named app (used when PYSHIM_TARGET=App).
        .EXAMPLE
            Set-AppPython -App 'MyService' -Spec 'conda:svc'
        #>
        [CmdletBinding(SupportsShouldProcess=$true)]
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$App,

            [Parameter(Mandatory=$true)]
            [System.String]$Spec
        )
        $file = "C:\bin\shims\python@$App.env"
        Set-Content -LiteralPath $file -Value $Spec -NoNewline -Encoding ASCII
        Write-Host "Wrote $file => $Spec"
    }

    function Run-WithPython {
        <#
        .SYNOPSIS
            One-shot run with a specific interpreter, no persistence.
        .EXAMPLE
            Run-WithPython -Spec 'py:3.11' -- -m pip --version
        #>
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$Spec,

            [Parameter(ValueFromRemainingArguments=$true)]
            [string[]]$Args
        )
        & "C:\bin\shims\python.bat" --interpreter "$Spec" -- @Args
    }

    function script:Get-PyshimCondaVersionMap {
        [CmdletBinding()]
        Param()

        return [ordered]@{
            'py310' = '3.10'
            'py311' = '3.11'
            'py312' = '3.12'
            'py313' = '3.13'
            'py314' = '3.14'
        }
    }

    function script:Resolve-PyshimCondaExecutable {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$Candidate
        )

        $SearchOrder = @()
        if ($Candidate) { $SearchOrder += $Candidate }
        if ($env:CONDA_EXE) { $SearchOrder += $env:CONDA_EXE }

        $PathHit = $null
        try {
            $Command = Get-Command -Name conda -ErrorAction Stop
            if ($Command -and $Command.Source) {
                $PathHit = $Command.Source
            }
        } catch {
            $PathHit = $null
        }
        if ($PathHit) { $SearchOrder += $PathHit }

        $DefaultUserInstall = Join-Path -Path $env:USERPROFILE -ChildPath 'miniconda3\Scripts\conda.exe'
        $SearchOrder += $DefaultUserInstall

        foreach ($PathCandidate in $SearchOrder) {
            if ([string]::IsNullOrWhiteSpace($PathCandidate)) {
                continue
            }

            $Expanded = Resolve-Path -LiteralPath $PathCandidate -ErrorAction SilentlyContinue
            if ($Expanded) {
                return $Expanded.ProviderPath
            }
        }

        return $null
    }

    function script:Invoke-PyshimCondaCommand {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$CondaExe,

            [Parameter(Mandatory=$true)]
            [System.String[]]$Arguments
        )

        Write-Verbose ("[conda] {0}" -f ($Arguments -join ' '))
        $Output = & $CondaExe @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
        if ($ExitCode -ne 0) {
            $Combined = ($Output | Out-String).Trim()
            if (-not $Combined) {
                $Combined = "conda exited with code $ExitCode"
            }
            throw $Combined
        }

        return ($Output | Out-String)
    }

    function script:Get-PyshimCondaEnvironmentMap {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$CondaExe
        )

        $EnvListJson = script:Invoke-PyshimCondaCommand -CondaExe $CondaExe -Arguments @('env','list','--json')
        try {
            $EnvList = $EnvListJson | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to parse conda env list JSON. $_"
        }

        $ExistingEnvMap = @{}
        if ($EnvList -and $EnvList.envs) {
            foreach ($EnvPath in $EnvList.envs) {
                $Name = [IO.Path]::GetFileName($EnvPath)
                if (-not [string]::IsNullOrWhiteSpace($Name)) {
                    $ExistingEnvMap[$Name.ToLower()] = $EnvPath
                }
            }
        }

        return $ExistingEnvMap
    }

    function Install-CondaPythons {
        <#
        .SYNOPSIS
            Provision Conda environments py310 through py314 with matching Python versions.
        .DESCRIPTION
            Reuses the helper shipped alongside the shims so the module can manage the environments
            directly. Environments are created only when missing or rebuilt when -ForceRecreate is
            supplied.
        .PARAMETER CondaPath
            Explicit path to conda.exe. Falls back to CONDA_EXE, Get-Command lookup, or %USERPROFILE%\miniconda3.
        .PARAMETER ForceRecreate
            Remove and rebuild environments even when the requested Python version already matches.
        .PARAMETER Environment
            Optional subset of environment names (py310..py314) to manage instead of all defaults.
        .EXAMPLE
            Install-CondaPythons
        .EXAMPLE
            Install-CondaPythons -CondaPath 'C:\Tools\miniconda3\Scripts\conda.exe' -ForceRecreate
        #>
        [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$CondaPath,

            [Switch]$ForceRecreate,

            [string[]]$Environment
        )

        $VersionMap = script:Get-PyshimCondaVersionMap
        if ($Environment) {
            $Filtered = [ordered]@{}
            foreach ($Entry in $Environment) {
                if ([string]::IsNullOrWhiteSpace($Entry)) {
                    continue
                }
                $Key = $Entry.Trim()
                if (-not $VersionMap.Contains($Key)) {
                    Write-Warning "Environment '$Key' is not in the managed pyshim set; skipping."
                    continue
                }
                $Filtered[$Key] = $VersionMap[$Key]
            }
            if ($Filtered.Count -eq 0) {
                throw 'No valid Conda environments were selected for installation.'
            }
            $VersionMap = $Filtered
        }

        $ResolvedConda = script:Resolve-PyshimCondaExecutable -Candidate $CondaPath
        if (-not $ResolvedConda) {
            throw 'Unable to locate conda.exe. Install Miniconda and/or supply -CondaPath.'
        }

        Write-Host "Using conda at $ResolvedConda" -ForegroundColor Cyan
        Write-Host ("Target environments: {0}" -f ($VersionMap.Keys -join ', ')) -ForegroundColor Cyan
        if ($ForceRecreate) {
            Write-Warning 'ForceRecreate requested; existing environments will be rebuilt.'
        }

        $ExistingEnvMap = script:Get-PyshimCondaEnvironmentMap -CondaExe $ResolvedConda

        foreach ($Entry in $VersionMap.GetEnumerator()) {
            $EnvName = $Entry.Key
            $Version = $Entry.Value
            $Existing = $ExistingEnvMap[$EnvName.ToLower()]

            $NeedsCreation = $true
            if ($Existing -and -not $ForceRecreate) {
                try {
                    $Probe = script:Invoke-PyshimCondaCommand -CondaExe $ResolvedConda -Arguments @('run','-n',$EnvName,'python','-c','import sys; print(sys.version.split()[0])')
                    $Reported = $Probe.Trim()
                    if ($Reported.StartsWith($Version)) {
                        Write-Host "Environment '$EnvName' already matches Python $Reported; skipping." -ForegroundColor Green
                        $NeedsCreation = $false
                    } else {
                        Write-Warning "Environment '$EnvName' reports Python $Reported (expected $Version). Recreating."
                    }
                } catch {
                    Write-Warning "Failed to probe Python version for '$EnvName'. Environment will be recreated. $_"
                }
            }

            if ($Existing -and ($ForceRecreate -or $NeedsCreation)) {
                if ($PSCmdlet.ShouldProcess($EnvName,'Remove existing conda environment')) {
                    Write-Host "Removing existing environment '$EnvName'" -ForegroundColor Yellow
                    script:Invoke-PyshimCondaCommand -CondaExe $ResolvedConda -Arguments @('env','remove','-n',$EnvName,'-y') | Out-Null
                }
                $NeedsCreation = $true
            }

            if ($NeedsCreation) {
                if ($PSCmdlet.ShouldProcess($EnvName,"Create Python $Version environment")) {
                    Write-Host "Creating environment '$EnvName' (Python $Version)" -ForegroundColor Blue
                    script:Invoke-PyshimCondaCommand -CondaExe $ResolvedConda -Arguments @('create','-n',$EnvName,"python=$Version",'--yes','--quiet','--no-default-packages') | Out-Null
                    $Verify = script:Invoke-PyshimCondaCommand -CondaExe $ResolvedConda -Arguments @('run','-n',$EnvName,'python','-V')
                    Write-Host "Created '$EnvName': $($Verify.Trim())" -ForegroundColor Green
                }
            }
        }

        Write-Host 'Requested Python environments are ready.' -ForegroundColor Green
    }

    function Remove-CondaPythons {
        <#
        .SYNOPSIS
            Remove the managed py310..py314 Conda environments.
        .DESCRIPTION
            Complements Install-CondaPythons by deleting the same interpreter environments. Useful for
            freeing disk space or rebuilding everything from scratch before reinstalling.
        .PARAMETER CondaPath
            Explicit path to conda.exe. Falls back to CONDA_EXE, Get-Command lookup, or %USERPROFILE%\miniconda3.
        .PARAMETER Environment
            Optional subset of environment names (py310..py314) to remove instead of the default set.
        .PARAMETER IgnoreMissing
            Suppress warnings when a requested environment does not exist.
        .EXAMPLE
            Remove-CondaPythons
        .EXAMPLE
            Remove-CondaPythons -Environment py312 -IgnoreMissing
        #>
        [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$CondaPath,

            [string[]]$Environment,

            [Switch]$IgnoreMissing
        )

        $VersionMap = script:Get-PyshimCondaVersionMap
        $Targets = @()
        if ($Environment -and $Environment.Count -gt 0) {
            foreach ($Entry in $Environment) {
                if ([string]::IsNullOrWhiteSpace($Entry)) {
                    continue
                }
                $Key = $Entry.Trim()
                if (-not $VersionMap.Contains($Key)) {
                    Write-Warning "Environment '$Key' is not in the managed pyshim set; skipping."
                    continue
                }
                $Targets += $Key
            }
            if (-not $Targets) {
                if ($IgnoreMissing) {
                    Write-Verbose 'No valid Conda environments were selected for removal.'
                    return
                }
                throw 'No valid Conda environments were selected for removal.'
            }
        } else {
            $Targets = $VersionMap.Keys
        }

        $ResolvedConda = script:Resolve-PyshimCondaExecutable -Candidate $CondaPath
        if (-not $ResolvedConda) {
            throw 'Unable to locate conda.exe. Install Miniconda and/or supply -CondaPath.'
        }

        Write-Host "Using conda at $ResolvedConda" -ForegroundColor Cyan
        Write-Host ("Removing environments: {0}" -f ($Targets -join ', ')) -ForegroundColor Cyan

        $ExistingEnvMap = script:Get-PyshimCondaEnvironmentMap -CondaExe $ResolvedConda

        foreach ($EnvName in $Targets) {
            $Lookup = $EnvName.ToLower()
            if (-not $ExistingEnvMap.ContainsKey($Lookup)) {
                if ($IgnoreMissing) {
                    Write-Verbose "Environment '$EnvName' does not exist; skipping removal."
                } else {
                    Write-Warning "Environment '$EnvName' does not exist; skipping removal."
                }
                continue
            }

            if ($PSCmdlet.ShouldProcess($EnvName,'Remove conda environment')) {
                Write-Host "Removing environment '$EnvName'" -ForegroundColor Yellow
                script:Invoke-PyshimCondaCommand -CondaExe $ResolvedConda -Arguments @('env','remove','-n',$EnvName,'-y') | Out-Null
                Write-Host "Removed Conda environment '$EnvName'." -ForegroundColor Green
            }
        }
    }

    function Refresh-CondaPythons {
        <#
        .SYNOPSIS
            Remove and recreate the managed py310..py314 Conda environments.
        .DESCRIPTION
            Calls Remove-CondaPythons (ignoring missing environments) followed by
            Install-CondaPythons with -ForceRecreate to ensure each target interpreter
            is rebuilt from scratch.
        .PARAMETER CondaPath
            Explicit path to conda.exe. Falls back to CONDA_EXE, PATH lookup, or %USERPROFILE%\miniconda3.
        .PARAMETER Environment
            Optional subset of environment names (py310..py314) to refresh instead of the default set.
        .PARAMETER IgnoreMissing
            Suppress warnings when an environment does not exist before removal.
        .EXAMPLE
            Refresh-CondaPythons
        .EXAMPLE
            Refresh-CondaPythons -Environment py312 -IgnoreMissing
        #>
        [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$CondaPath,

            [string[]]$Environment,

            [Switch]$IgnoreMissing
        )

        $RemoveArgs = @{}
        if ($PSBoundParameters.ContainsKey('CondaPath')) { $RemoveArgs.CondaPath = $CondaPath }
        if ($Environment) { $RemoveArgs.Environment = $Environment }
        if ($IgnoreMissing) { $RemoveArgs.IgnoreMissing = $true }
        if ($PSBoundParameters.ContainsKey('WhatIf')) { $RemoveArgs.WhatIf = $true }
        if ($PSBoundParameters.ContainsKey('Confirm')) { $RemoveArgs.Confirm = $Confirm }

        Remove-CondaPythons @RemoveArgs

        $InstallArgs = @{ ForceRecreate = $true }
        if ($PSBoundParameters.ContainsKey('CondaPath')) { $InstallArgs.CondaPath = $CondaPath }
        if ($Environment) { $InstallArgs.Environment = $Environment }
        if ($PSBoundParameters.ContainsKey('WhatIf')) { $InstallArgs.WhatIf = $true }
        if ($PSBoundParameters.ContainsKey('Confirm')) { $InstallArgs.Confirm = $Confirm }

        Install-CondaPythons @InstallArgs
    }

    function Update-Pyshim {
        <#
        .SYNOPSIS
            Download the latest pyshim release from GitHub and rerun the installer.
        .DESCRIPTION
            Fetches release metadata, downloads Install-Pyshim.ps1, executes it, and refreshes the
            current session's module import. Defaults to the latest release but can target a specific tag.
        .PARAMETER Tag
            Git tag to install (for example 'v0.1.1-alpha'). Defaults to the latest release.
        .PARAMETER WritePath
            Pass -WritePath through to the installer so C:\bin\shims is added to the user PATH when missing.
        .PARAMETER Token
            GitHub token used for authenticated API calls to avoid rate limiting (falls back to GITHUB_TOKEN env var).
        .EXAMPLE
            Update-Pyshim
        .EXAMPLE
            Update-Pyshim -WritePath -Tag 'v0.1.1-alpha'
        #>
        [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$Tag,

            [Switch]$WritePath,

            [System.String]$Token
        )

        $Repository = 'shruggietech/pyshim'
        $ApiRoot = 'https://api.github.com'
        $Headers = @{
            'User-Agent' = 'pyshim-update'
            'Accept'     = 'application/vnd.github+json'
        }

        if (-not $Token) {
            $Token = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','Process')
            if (-not $Token) {
                $Token = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User')
            }
        }

        if ($Token) {
            $Headers['Authorization'] = "Bearer $Token"
        }

        $ReleaseUri = if ($Tag) { "$ApiRoot/repos/$Repository/releases/tags/$Tag" } else { "$ApiRoot/repos/$Repository/releases/latest" }

        try {
            $Release = Invoke-RestMethod -Uri $ReleaseUri -Headers $Headers -ErrorAction Stop
        } catch {
            throw "Failed to query GitHub release metadata ($ReleaseUri). $_"
        }

        if (-not $Release) {
            throw "GitHub returned no release data from $ReleaseUri."
        }

        $InstallerAsset = $Release.assets | Where-Object { $_.name -eq 'Install-Pyshim.ps1' } | Select-Object -First 1
        if (-not $InstallerAsset) {
            throw "The release '$($Release.tag_name)' does not expose Install-Pyshim.ps1; cannot continue."
        }

        $Sep = [IO.Path]::DirectorySeparatorChar
        $ShimDir = "C:${Sep}bin${Sep}shims"
        $TargetTag = if ($Release.tag_name) { $Release.tag_name } else { '(unknown tag)' }
        if (-not $PSCmdlet.ShouldProcess($ShimDir,"Update pyshim to $TargetTag")) {
            return
        }

        $TempRoot = [IO.Path]::GetTempPath()
        $TempName = 'pyshim-update-' + [Guid]::NewGuid().ToString('N')
        $WorkingDir = Join-Path $TempRoot $TempName
        $InstallerPath = Join-Path $WorkingDir 'Install-Pyshim.ps1'

        try {
            if (-not (Test-Path -LiteralPath $WorkingDir)) {
                New-Item -ItemType Directory -Path $WorkingDir -Force | Out-Null
            }

            try {
                Invoke-WebRequest -Uri $InstallerAsset.browser_download_url -OutFile $InstallerPath -Headers $Headers -ErrorAction Stop
            } catch {
                throw "Failed to download Install-Pyshim.ps1 from $($InstallerAsset.browser_download_url). $_"
            }

            $Arguments = @('-ExecutionPolicy','Bypass','-File',$InstallerPath)
            if ($WritePath) {
                $Arguments += '-WritePath'
            }

            & powershell.exe @Arguments
            $ExitCode = $LASTEXITCODE

            if ($ExitCode -ne 0) {
                throw "Install-Pyshim.ps1 exited with code $ExitCode."
            }

            $ModulePath = Join-Path $ShimDir 'pyshim.psm1'
            if (Test-Path -LiteralPath $ModulePath) {
                Import-Module $ModulePath -Force -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }

            Write-Host "pyshim updated to release $TargetTag." -ForegroundColor Green
        } finally {
            if (Test-Path -LiteralPath $WorkingDir) {
                Remove-Item -LiteralPath $WorkingDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Uninstall-Pyshim {
        <#
        .SYNOPSIS
            Remove pyshim files and PATH entries from the current machine.
        .PARAMETER Force
            Proceed even if unexpected files exist in the shim directory.
        .PARAMETER InvokerPath
            Internal use. Path to the executing uninstall script so cleanup can finish after exit.
        .EXAMPLE
            Uninstall-Pyshim
        .EXAMPLE
            Uninstall-Pyshim -Force
        #>
        [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
        Param(
            [Switch]$Force,

            [Parameter(Mandatory=$false)]
            [System.String]$InvokerPath
        )

        $ShimDir = 'C:\bin\shims'
        if (-not (Test-Path -LiteralPath $ShimDir)) {
            Write-Host "pyshim does not appear to be installed (missing $ShimDir)." -ForegroundColor Yellow
            return
        }

        $ExpectedCore = 'pip.bat','python.bat','pythonw.bat','pyshim.psm1','Uninstall-Pyshim.ps1'
        $OptionalExact = 'python.env','python.nopersist'
        $OptionalPatterns = 'python@*.env'

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
            Write-Warning "Additional files were found in $ShimDir. Re-run with -Force to remove everything."
            foreach ($Item in $Unexpected) {
                Write-Host "    $($Item.Name)" -ForegroundColor Yellow
            }
            return
        }

        $TargetNormalized = $ShimDir.TrimEnd('\\')
        $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
        if ($UserPath) {
            $Segments = $UserPath -split ';'
            $Filtered = $Segments | Where-Object { $_ -and ($_.TrimEnd('\\') -ine $TargetNormalized) }
            $NewUserPath = ($Filtered | Where-Object { $_ }) -join ';'
            if ($NewUserPath -ne $UserPath) {
                if ($PSCmdlet.ShouldProcess('User PATH','Remove pyshim entry')) {
                    [Environment]::SetEnvironmentVariable('Path',$NewUserPath,'User')
                    $EnvSegments = $env:Path -split ';'
                    $env:Path = ($EnvSegments | Where-Object { $_.TrimEnd('\\') -ine $TargetNormalized }) -join ';'
                    Write-Host "Removed C:\bin\shims from the user PATH." -ForegroundColor Green
                }
            }
        }

        $Items = Get-ChildItem -LiteralPath $ShimDir -Force
        foreach ($Item in $Items) {
            if ($InvokerPath -and ($Item.FullName -eq $InvokerPath)) {
                continue
            }
            if ($PSCmdlet.ShouldProcess($Item.FullName,'Delete file')) {
                Remove-Item -LiteralPath $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $ProfileScopes = @('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')
        try {
            Write-Verbose 'Attempting to remove pyshim profile hooks via Disable-PyshimProfile.'
            Disable-PyshimProfile -Scope $ProfileScopes -IncludeWindowsPowerShell -NoBackup -Confirm:$false | Out-Null
        } catch {
            Write-Warning "Failed to remove pyshim profile hooks using Disable-PyshimProfile: $($_.Exception.Message)"
        }

        if ($InvokerPath) {
            $Cleanup = {
                param($ScriptPath,$Directory)
                Start-Sleep -Seconds 1
                Remove-Item -LiteralPath $ScriptPath -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $Directory -Recurse -Force -ErrorAction SilentlyContinue
                $Parent = Split-Path -Parent $Directory
                if ($Parent -and (Test-Path -LiteralPath $Parent)) {
                    $Remaining = Get-ChildItem -LiteralPath $Parent -Force -ErrorAction SilentlyContinue
                    if (-not $Remaining) {
                        Remove-Item -LiteralPath $Parent -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            Start-Job -ScriptBlock $Cleanup -ArgumentList $InvokerPath,$ShimDir | Out-Null
            Write-Host "Scheduled cleanup job to remove $ShimDir after this script exits." -ForegroundColor Green
        } else {
            if ($PSCmdlet.ShouldProcess($ShimDir,'Remove shim directory')) {
                Remove-Item -LiteralPath $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
                $ParentDir = Split-Path -Parent $ShimDir
                if ($ParentDir -and (Test-Path -LiteralPath $ParentDir)) {
                    $Remaining = Get-ChildItem -LiteralPath $ParentDir -Force -ErrorAction SilentlyContinue
                    if (-not $Remaining) {
                        Remove-Item -LiteralPath $ParentDir -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }

        if (Get-ChildItem Env:PYSHIM_INTERPRETER -ErrorAction SilentlyContinue) {
            Remove-Item Env:PYSHIM_INTERPRETER -ErrorAction SilentlyContinue
        }
        Write-Host "pyshim has been removed." -ForegroundColor Green
    }

#______________________________________________________________________________
## Declare Variables and Arrays

    # Nothing needed here for now

#______________________________________________________________________________
## Execute Operations

    # Catch help text requests
    if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
        Get-Help $MyInvocation.MyCommand.Path -Detailed
        exit
    }

#______________________________________________________________________________
## End of script