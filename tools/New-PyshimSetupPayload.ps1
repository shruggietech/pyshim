<#
.SYNOPSIS
    Generates installer/Pyshim.Setup/EmbeddedPayload.cs from the current shims.
.DESCRIPTION
    Copies bin/shims, strips runtime state files, zips the payload, and emits a
    C# source file embedding the archive as a base64 string for the WinForms
    installer.
.EXAMPLE
    pwsh ./tools/New-PyshimSetupPayload.ps1 -Force
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None')]
Param(
    [Parameter(Mandatory=$false)]
    [System.String]$OutputPath,

    [Parameter(Mandatory=$false)]
    [Switch]$Force
)

$RepoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
$SourceDir = Join-Path -Path $RepoRoot -ChildPath 'bin/shims'
if (-not $OutputPath) {
    $OutputPath = Join-Path -Path $RepoRoot -ChildPath 'installer/Pyshim.Setup/EmbeddedPayload.cs'
}

if ((Test-Path -LiteralPath $OutputPath) -and (-not $Force)) {
    throw "Output file '$OutputPath' already exists. Use -Force to overwrite."
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Shim source directory '$SourceDir' was not found."
}

$TempRoot = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ("pyshim_setup_" + [Guid]::NewGuid().ToString('N'))) -Force
$StagingDir = Join-Path -Path $TempRoot -ChildPath 'shims'
$TempZip = Join-Path -Path $TempRoot -ChildPath 'payload.zip'
$ExcludedExact = @('python.env','python.nopersist')
$ExcludedWildcard = @('python@*.env')

try {
    New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
    Copy-Item -Path (Join-Path -Path $SourceDir -ChildPath '*') -Destination $StagingDir -Recurse -Force

    Get-ChildItem -Path $StagingDir -Recurse -File | ForEach-Object {
        $Name = $_.Name
        if ($ExcludedExact -contains $Name) {
            Remove-Item -LiteralPath $_.FullName -Force
            return
        }
        foreach ($Pattern in $ExcludedWildcard) {
            if ($Name -like $Pattern) {
                Remove-Item -LiteralPath $_.FullName -Force
                return
            }
        }
    }

    Compress-Archive -Path (Join-Path -Path $StagingDir -ChildPath '*') -DestinationPath $TempZip -Force
    $Bytes = [IO.File]::ReadAllBytes($TempZip)
    $Base64 = [Convert]::ToBase64String($Bytes)
    $Builder = New-Object System.Text.StringBuilder
    for ($Offset = 0; $Offset -lt $Base64.Length; $Offset += 96) {
        $ChunkLength = [Math]::Min(96, $Base64.Length - $Offset)
        [void]$Builder.AppendLine($Base64.Substring($Offset,$ChunkLength))
    }
    $WrappedBase64 = $Builder.ToString().TrimEnd()

    $SourceBuilder = New-Object System.Text.StringBuilder
    [void]$SourceBuilder.AppendLine('namespace Pyshim.Setup;')
    [void]$SourceBuilder.AppendLine()
    [void]$SourceBuilder.AppendLine('/// <summary>')
    [void]$SourceBuilder.AppendLine('///  Generated payload bundling the current shims as a base64 zip archive.')
    [void]$SourceBuilder.AppendLine('///  Run tools/New-PyshimSetupPayload.ps1 whenever the shims change.')
    [void]$SourceBuilder.AppendLine('/// </summary>')
    [void]$SourceBuilder.AppendLine('internal static class EmbeddedPayload')
    [void]$SourceBuilder.AppendLine('{')
    [void]$SourceBuilder.AppendLine('    internal const string Base64Archive = @"')
    [void]$SourceBuilder.AppendLine($WrappedBase64)
    [void]$SourceBuilder.AppendLine('";')
    [void]$SourceBuilder.AppendLine('}')

    $Content = $SourceBuilder.ToString()
    Set-Content -LiteralPath $OutputPath -Value $Content -Encoding UTF8
    Write-Host "EmbeddedPayload.cs updated." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
