<#
.SYNOPSIS
    Provision optional Miniconda environments for pyshim covering Python 3.10
    through Python 3.14.
.DESCRIPTION
    Locates a Miniconda/conda installation and creates (or refreshes) lightweight
    environments named py310 … py314, each pinned to its matching CPython version.
    Existing environments are skipped if they already report the requested version.
    This script mirrors the development setup used while bootstrapping pyshim and
    serves as an optional add-on for users who want readily available interpreters
    spanning multiple minor versions.
.PARAMETER CondaPath
    Explicit path to conda.exe. By default the script attempts to locate conda via
    CONDA_EXE, the current PATH, or the common %USERPROFILE%\miniconda3 location.
.PARAMETER ForceRecreate
    When supplied, existing py3xx environments are removed and recreated even if
    they already match the target version.
.PARAMETER Help
    Display detailed help for this script.
.EXAMPLE
    .\Install-CondaPythons.ps1

    Creates py310…py314 environments using the detected conda installation.
.EXAMPLE
    .\Install-CondaPythons.ps1 -CondaPath 'C:\Tools\miniconda3\Scripts\conda.exe'

    Use a custom conda installation when auto-detection fails.
.EXAMPLE
    .\Install-CondaPythons.ps1 -ForceRecreate

    Rebuild all py3xx environments from scratch.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias('Conda','CondaExe')]
    [System.String]$CondaPath,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Switch]$ForceRecreate,

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias('h')]
    [Switch]$Help
)
#______________________________________________________________________________
## Declare Functions

    function Write-PyshimMessage {
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

    function Resolve-CondaExecutable {
        Param(
            [Parameter(Mandatory=$false)]
            [System.String]$Candidate
        )

        $SearchOrder = @()
        if ($Candidate) { $SearchOrder += $Candidate }
        if ($env:CONDA_EXE) { $SearchOrder += $env:CONDA_EXE }

        $PathHit = $null
        try {
            $PathHit = (Get-Command conda -ErrorAction Stop).Source
        } catch {
            $PathHit = $null
        }
        if ($PathHit) { $SearchOrder += $PathHit }

        $DefaultUserInstall = Join-Path -Path $env:USERPROFILE -ChildPath 'miniconda3\Scripts\conda.exe'
        $SearchOrder += $DefaultUserInstall

        foreach ($PathCandidate in $SearchOrder) {
            if ([string]::IsNullOrWhiteSpace($PathCandidate)) { continue }
            $Expanded = Resolve-Path -LiteralPath $PathCandidate -ErrorAction SilentlyContinue
            if ($Expanded) {
                return $Expanded.ProviderPath
            }
        }

        return $null
    }

    function Invoke-CondaCommand {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$CondaExe,

            [Parameter(Mandatory=$true)]
            [System.String[]]$Arguments
        )

        Write-Verbose "[conda] $($Arguments -join ' ')"
        $Output = & $CondaExe @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
        if ($ExitCode -ne 0) {
            $Combined = ($Output | Out-String).Trim()
            if (-not $Combined) { $Combined = "conda exited with code $ExitCode" }
            throw $Combined
        }

        return ($Output | Out-String)
    }

#______________________________________________________________________________
## Declare Variables and Arrays

    $ThisScriptPath = $MyInvocation.MyCommand.Path

#______________________________________________________________________________
## Execute Operations

    # Catch help text requests
    if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
        Get-Help $ThisScriptPath -Detailed
        exit
    }

    $ResolvedConda = Resolve-CondaExecutable -Candidate $CondaPath
    if (-not $ResolvedConda) {
        Write-PyshimMessage -Type Error -Message 'Unable to locate conda.exe. Install Miniconda and/or supply -CondaPath.'
        throw "Unable to locate conda.exe. Install Miniconda and/or supply -CondaPath."
    }

    Write-PyshimMessage -Type Info -Message "Using conda at $ResolvedConda"
    Write-PyshimMessage -Type Info -Message 'Target environments: py310, py311, py312, py313, py314'
    if ($ForceRecreate) {
        Write-PyshimMessage -Type Warning -Message 'ForceRecreate requested; existing environments will be rebuilt.'
    }

    $TargetVersions = [ordered]@{
        'py310' = '3.10'
        'py311' = '3.11'
        'py312' = '3.12'
        'py313' = '3.13'
        'py314' = '3.14'
    }

    $EnvListJson = Invoke-CondaCommand -CondaExe $ResolvedConda -Arguments @('env','list','--json')
    $EnvList = $EnvListJson | ConvertFrom-Json
    $ExistingEnvMap = @{}
    foreach ($EnvPath in $EnvList.envs) {
        $Name = [IO.Path]::GetFileName($EnvPath)
        if (-not [string]::IsNullOrWhiteSpace($Name)) {
            $ExistingEnvMap[$Name.ToLower()] = $EnvPath
        }
    }

    foreach ($Entry in $TargetVersions.GetEnumerator()) {
        $EnvName = $Entry.Key
        $Version = $Entry.Value
        $Existing = $ExistingEnvMap[$EnvName.ToLower()]

        $NeedsCreation = $true
        if ($Existing -and -not $ForceRecreate) {
            try {
                $VersionProbe = Invoke-CondaCommand -CondaExe $ResolvedConda -Arguments @('run','-n',$EnvName,'python','-c','import sys; print(sys.version.split()[0])')
                $ReportedVersion = $VersionProbe.Trim()
                if ($ReportedVersion.StartsWith($Version)) {
                    Write-PyshimMessage -Type Success -Message "Environment '$EnvName' already provides Python $ReportedVersion; skipping."
                    $NeedsCreation = $false
                } else {
                    Write-PyshimMessage -Type Warning -Message "Environment '$EnvName' reports Python $ReportedVersion (expected $Version). Recreating."
                }
            } catch {
                Write-PyshimMessage -Type Warning -Message "Failed to probe Python version for '$EnvName'. Environment will be recreated."
            }
        }

        if ($Existing -and ($ForceRecreate -or $NeedsCreation)) {
            if ($PSCmdlet.ShouldProcess($EnvName,'Remove existing conda environment')) {
                Write-PyshimMessage -Type Action -Message "Removing existing environment '$EnvName'"
                Invoke-CondaCommand -CondaExe $ResolvedConda -Arguments @('env','remove','-n',$EnvName,'-y') | Out-Null
            }
            $NeedsCreation = $true
        }

        if ($NeedsCreation) {
            if ($PSCmdlet.ShouldProcess($EnvName,"Create Python $Version environment")) {
                Write-PyshimMessage -Type Action -Message "Creating environment '$EnvName' (Python $Version)"
                Invoke-CondaCommand -CondaExe $ResolvedConda -Arguments @('create','-n',$EnvName,"python=$Version",'--yes','--quiet','--no-default-packages') | Out-Null
                $Verify = Invoke-CondaCommand -CondaExe $ResolvedConda -Arguments @('run','-n',$EnvName,'python','-V')
                Write-PyshimMessage -Type Success -Message "Created '$EnvName': $($Verify.Trim())"
            }
        }
    }

    Write-PyshimMessage -Type Success -Message 'Requested Python environments are ready.'

#______________________________________________________________________________
## End of script