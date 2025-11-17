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

if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
    Get-Help -Name $MyInvocation.MyCommand.Path -Full
    exit 0
}

$EmbeddedArchive = @'
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
dFBLBQYAAAAABAAEAN8AAABFDAAAAAA=
'@

Add-Type -AssemblyName System.IO.Compression.FileSystem

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

$ShimDir = 'C:\bin\shims'
$WorkingRoot = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("pyshim_" + [Guid]::NewGuid().ToString('N'))
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

