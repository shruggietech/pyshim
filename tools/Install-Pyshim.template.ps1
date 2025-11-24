<#
.SYNOPSIS
    Single-file installer that provisions pyshim shims to the local machine.
.DESCRIPTION
    Unpacks an embedded archive containing the pyshim batch shims and PowerShell
    module, then mirrors the behaviour of Make-Pyshim.ps1: copies the payload to
    C:\bin\shims (creating the directory when needed) and optionally appends
    that directory to the user PATH.

    The embedded archive is generated from the repository's bin/shims directory
    using tools/New-PyshimInstaller.ps1. Re-run that tool whenever the shims
    change to refresh this installer before publishing a release asset.
.PARAMETER WritePath
    Automatically append C:\bin\shims to the user PATH when it is missing. If
    omitted the script prompts the user.
.PARAMETER Help
    Display the full help text for this script.
.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Install-Pyshim.ps1 -WritePath

    Installs pyshim and ensures the user PATH contains C:\bin\shims.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias('Path','P')]
    [Switch]$WritePath,

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

    function Add-PyshimPathEntry {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$TargetPath,

            [Parameter(Mandatory=$true)]
            [System.String]$CurrentUserPath
        )

        $NormalizedTarget = $TargetPath.TrimEnd('\\')
        $SplitPaths = @()
        if ($CurrentUserPath) {
            $SplitPaths = $CurrentUserPath -split ';'
        }

        $Filtered = @()
        foreach ($Entry in $SplitPaths) {
            if (-not $Entry) { continue }
            if ($Entry.TrimEnd('\\') -ieq $NormalizedTarget) { continue }
            $Filtered += $Entry
        }

        $Ordered = @($TargetPath) + $Filtered
        return ($Ordered | Where-Object { $_ }) -join ';'
    }

    function Get-PyshimPathScopes {
        Param()

        return [PSCustomObject]@{
            Process = $env:Path
            User    = [Environment]::GetEnvironmentVariable('Path','User')
            Machine = [Environment]::GetEnvironmentVariable('Path','Machine')
        }
    }

    function Test-PyshimPathPresence {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$TargetPath,

            [Parameter(Mandatory=$true)]
            [System.String[]]$Scopes
        )

        foreach ($Scope in $Scopes) {
            if (-not $Scope) {
                continue
            }

            $Entries = $Scope -split ';'
            if ($Entries | Where-Object { $_.TrimEnd('\\') -ieq $TargetPath.TrimEnd('\\') }) {
                return $true
            }
        }

        return $false
    }

    function Expand-PyshimArchive {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$DestinationPath
        )

        $Bytes = [Convert]::FromBase64String($EmbeddedArchive)
        $ZipPath = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllBytes($ZipPath,$Bytes)
            [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath,$DestinationPath,$true)
        } finally {
            if (Test-Path -LiteralPath $ZipPath) {
                Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

#______________________________________________________________________________
## Embedded Archive Block

$EmbeddedArchive = @'
__PYSHIM_EMBEDDED_ARCHIVE__
'@

#______________________________________________________________________________
## Declare Variables and Load Assemblies

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $ShimDir = 'C:\bin\shims'
    $WorkingRoot = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("pyshim_" + [Guid]::NewGuid().ToString('N'))

#______________________________________________________________________________
## Execute Operations

    # Catch help text requests
    if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
        Get-Help -Name $MyInvocation.MyCommand.Path -Full
        exit 0
    }

    $Null = New-Item -ItemType Directory -Path $WorkingRoot -Force

    Write-PyshimMessage -Type Info -Message 'Starting pyshim installation.'
    Write-PyshimMessage -Type Info -Message "Target directory: $ShimDir"
    Write-PyshimMessage -Type Action -Message 'Extracting embedded payload to a temporary staging folder.'

    try {
        Expand-PyshimArchive -DestinationPath $WorkingRoot
        $PayloadSource = $WorkingRoot
        Write-PyshimMessage -Type Success -Message "Payload unpacked to $WorkingRoot"

        if (-not (Test-Path -LiteralPath $ShimDir)) {
            if ($PSCmdlet.ShouldProcess($ShimDir,'Create shim directory')) {
                Write-PyshimMessage -Type Action -Message "Creating shim directory at $ShimDir"
                New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null
            }
        } else {
            Write-PyshimMessage -Type Info -Message "Shim directory already exists at $ShimDir"
        }

        if ($PSCmdlet.ShouldProcess($ShimDir,'Copy embedded shims')) {
            Write-PyshimMessage -Type Action -Message "Copying shim payload into $ShimDir"
            Copy-Item -Path (Join-Path -Path $PayloadSource -ChildPath '*') -Destination $ShimDir -Recurse -Force
            Write-PyshimMessage -Type Success -Message 'Shim files refreshed.'
        }
    } finally {
        if (Test-Path -LiteralPath $WorkingRoot) {
            Remove-Item -LiteralPath $WorkingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $PathScopes = Get-PyshimPathScopes
    $AllScopes = @($PathScopes.Process,$PathScopes.User,$PathScopes.Machine)
    $PathPresent = Test-PyshimPathPresence -TargetPath $ShimDir -Scopes $AllScopes

    if ($PathPresent) {
        Write-PyshimMessage -Type Success -Message "C:\bin\shims already present in PATH. Installation complete."
        return
    }

    $ShouldWritePath = $false
    if ($WritePath) {
        $ShouldWritePath = $true
    } else {
        $Response = Read-Host "Add 'C:\bin\shims' to your user PATH? [y/N]"
        if ($Response -and ($Response.Trim() -match '^(y|yes)$')) {
            $ShouldWritePath = $true
        }
    }

    if ($ShouldWritePath) {
        if ($PSCmdlet.ShouldProcess('User PATH','Append shim directory')) {
            $NewUserPath = Add-PyshimPathEntry -TargetPath $ShimDir -CurrentUserPath $PathScopes.User
            [Environment]::SetEnvironmentVariable('Path',$NewUserPath,'User')
            $env:Path = Add-PyshimPathEntry -TargetPath $ShimDir -CurrentUserPath $env:Path
            Write-PyshimMessage -Type Success -Message "Added 'C:\bin\shims' to the user PATH. Restart existing shells."
            Write-PyshimMessage -Type Success -Message 'pyshim installation complete.'
        }
        return
    } else {
        Write-PyshimMessage -Type Warning -Message "Skipped PATH update. To add it later run:"
        Write-Host ("    [Environment]::SetEnvironmentVariable('Path',( '{0};' + [Environment]::GetEnvironmentVariable('Path','User')).Trim(';'),'User')" -f $ShimDir) -ForegroundColor Yellow
        Write-PyshimMessage -Type Success -Message 'pyshim installation complete.'
        return
    }

#______________________________________________________________________________
## End of script