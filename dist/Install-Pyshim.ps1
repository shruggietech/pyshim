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

    function Add-PyshimPathEntry {
        Param(
            [Parameter(Mandatory=$true)]
            [System.String]$TargetPath,

            [Parameter(Mandatory=$true)]
            [System.String]$CurrentUserPath
        )

        $SplitPaths = @()
        if ($CurrentUserPath) {
            $SplitPaths = $CurrentUserPath -split ';'
        }

        if (-not ($SplitPaths | Where-Object { $_.TrimEnd('\\') -ieq $TargetPath.TrimEnd('\\') })) {
            $SplitPaths = @($SplitPaths | Where-Object { $_ }) + $TargetPath
        }

        return ($SplitPaths | Where-Object { $_ }) -join ';'
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
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
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

    try {
        Expand-PyshimArchive -DestinationPath $WorkingRoot
        $PayloadSource = $WorkingRoot

        if (-not (Test-Path -LiteralPath $ShimDir)) {
            if ($PSCmdlet.ShouldProcess($ShimDir,'Create shim directory')) {
                New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null
            }
        }

        if ($PSCmdlet.ShouldProcess($ShimDir,'Copy embedded shims')) {
            Copy-Item -Path (Join-Path -Path $PayloadSource -ChildPath '*') -Destination $ShimDir -Recurse -Force
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
        Write-Host "C:\bin\shims already present in PATH." -ForegroundColor Green
        exit 0
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
            $EnvEntries = $env:Path -split ';'
            if (-not ($EnvEntries | Where-Object { $_.TrimEnd('\\') -ieq $ShimDir.TrimEnd('\\') })) {
                $env:Path = ($EnvEntries + $ShimDir | Where-Object { $_ }) -join ';'
            }
            Write-Host "Added 'C:\bin\shims' to the user PATH. Restart existing shells." -ForegroundColor Green
        }
        exit 0
    } else {
        Write-Host "Skipped PATH update. To add it later run:" -ForegroundColor Yellow
        Write-Host "    [Environment]::SetEnvironmentVariable('Path',( '{0};' + [Environment]::GetEnvironmentVariable('Path','User')).Trim(';'),'User')" -f $ShimDir
        exit 0
    }

#______________________________________________________________________________
## End of script