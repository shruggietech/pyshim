<#
.SYNOPSIS
    Generates the single-file Install-Pyshim.ps1 installer for release builds.
.DESCRIPTION
    Zips the repository's bin/shims directory, converts it to Base64, and injects
    the payload into tools/Install-Pyshim.template.ps1. The rendered installer is
    written to dist/Install-Pyshim.ps1 (or a custom destination when specified).
.PARAMETER OutputPath
    Optional destination for the generated installer. Defaults to dist/Install-Pyshim.ps1
    relative to the repository root.
.PARAMETER Force
    Overwrite the output file if it already exists.
.EXAMPLE
    pwsh ./tools/New-PyshimInstaller.ps1

    Writes dist/Install-Pyshim.ps1 with the current shims payload embedded.
.EXAMPLE
    pwsh ./tools/New-PyshimInstaller.ps1 -OutputPath ./Install-Pyshim.ps1 -Force

    Generates the installer at the repository root, overwriting any existing file.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false)]
    [System.String]$OutputPath,

    [Parameter(Mandatory=$false)]
    [Switch]$Force
)
#______________________________________________________________________________
## Declare Functions

#______________________________________________________________________________
## Declare Variables and Arrays

    $RepoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
    $SourceDir = Join-Path -Path $RepoRoot -ChildPath 'bin/shims'
    $TemplatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Install-Pyshim.template.ps1'

#______________________________________________________________________________
## Execute Operations

    if (-not $OutputPath) {
        $OutputDir = Join-Path -Path $RepoRoot -ChildPath 'dist'
        if (-not (Test-Path -LiteralPath $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $OutputPath = Join-Path -Path $OutputDir -ChildPath 'Install-Pyshim.ps1'
    } else {
        $OutputPath = Resolve-Path -Path $OutputPath -ErrorAction SilentlyContinue -OutVariable resolved | Out-Null
        if ($resolved) {
            $OutputPath = $resolved.ProviderPath
        } else {
            $OutputPath = [IO.Path]::GetFullPath((Join-Path -Path (Get-Location) -ChildPath $OutputPath))
        }
    }

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Shim source directory '$SourceDir' was not found."
    }

    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        throw "Template file '$TemplatePath' was not found."
    }

    if ((Test-Path -LiteralPath $OutputPath) -and (-not $Force)) {
        throw "Output file '$OutputPath' already exists. Use -Force to overwrite."
    }

    $TempRoot = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ("pyshim_dist_" + [Guid]::NewGuid().ToString('N'))) -Force
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
            } else {
                foreach ($Pattern in $ExcludedWildcard) {
                    if ($Name -like $Pattern) {
                        Remove-Item -LiteralPath $_.FullName -Force
                        break
                    }
                }
            }
        }

        Compress-Archive -Path (Join-Path -Path $StagingDir -ChildPath '*') -DestinationPath $TempZip -Force
        $Bytes = [IO.File]::ReadAllBytes($TempZip)
        $Base64 = [Convert]::ToBase64String($Bytes)
        $Builder = New-Object System.Text.StringBuilder
        for ($Offset = 0; $Offset -lt $Base64.Length; $Offset += 76) {
            $ChunkLength = [Math]::Min(76, $Base64.Length - $Offset)
            [void]$Builder.AppendLine($Base64.Substring($Offset,$ChunkLength))
        }
        $WrappedBase64 = $Builder.ToString().TrimEnd()
        Write-Verbose ("Payload size: {0} bytes ({1} base64 characters)" -f $Bytes.Length,$Base64.Length)

        $TemplateContent = Get-Content -LiteralPath $TemplatePath -Raw
        $Rendered = $TemplateContent -replace '__PYSHIM_EMBEDDED_ARCHIVE__',$WrappedBase64
        if ($Rendered -notlike '*__PYSHIM_EMBEDDED_ARCHIVE__*') {
            Write-Verbose "Embedded archive inserted."
        } else {
            throw 'Failed to embed archive payload.'
        }

        Set-Content -LiteralPath $OutputPath -Value $Rendered -Encoding ASCII -Force
        Write-Host "Installer written to $OutputPath" -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $TempRoot) {
            Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

#______________________________________________________________________________
## End of script