<#
.SYNOPSIS
    Generates a Markdown code reference file from project root files (intended for use in AI prompting).
.DESCRIPTION
    Creates a comprehensive Markdown document containing all files from the project root directory
    with appropriate syntax highlighting. Excludes specific files like LICENSE and workspace files.
    README.md is processed first with headers downgraded one level. Each file is formatted as a
    level-two header followed by a code block with proper language syntax highlighting.
.PARAMETER Directory
    The directory to scan for files. Defaults to the project root (..\). Use this to point the
    script at a different directory for processing.
    Alias: d
.PARAMETER Recurse
    When specified, recursively scans subdirectories within the target directory. By default,
    only files in the root of the target directory are processed (non-recursive).
    Alias: r, recursive
.PARAMETER Force
    When specified, includes hidden files in the output. By default, hidden files are excluded.
    Alias: f
.PARAMETER IncludeMarkdown
    When specified, includes the full content of all Markdown files (other than README.md).
    By default, non-README Markdown files are listed with a placeholder message instead of
    their full content.
    Alias: i, includemd
.PARAMETER Help
    Displays detailed help information for this script.
    Alias: h
.EXAMPLE
    .\Make-PromptCodeReference.ps1

    Generates a code reference from files in the project root directory (non-recursive).
.EXAMPLE
    .\Make-PromptCodeReference.ps1 -Directory 'C:\MyProject'

    Generates a code reference from files in C:\MyProject (non-recursive).
.EXAMPLE
    .\Make-PromptCodeReference.ps1 -Recurse

    Generates a code reference from all files in the project root and subdirectories (recursive).
.EXAMPLE
    .\Make-PromptCodeReference.ps1 -d 'C:\MyProject' -r

    Generates a code reference from all files in C:\MyProject and subdirectories using parameter aliases.
.EXAMPLE
    .\Make-PromptCodeReference.ps1 -Force

    Generates a code reference from the project root including hidden files.
.EXAMPLE
    .\Make-PromptCodeReference.ps1 -IncludeMarkdown

    Generates a code reference including the full content of all Markdown files (other than README.md).
.LINK
    https://github.com/shruggietech/pyshim
#>

[CmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("d")]
    [System.String]$Directory,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("r","recursive")]
    [Switch]$Recurse,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("f")]
    [Switch]$Force,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("i","includemd")]
    [Switch]$IncludeMarkdown,

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias("h")]
    [Switch]$Help
)

# Internal self-awareness variables for use in verbosity and logging
$ThisScriptPath = $MyInvocation.MyCommand.Path
$ThisFunctionReference = "{0}" -f $MyInvocation.MyCommand
$ThisSubFunction = "{0}" -f $MyInvocation.MyCommand
$ThisFunction = if ($null -eq $ThisFunction) { $ThisSubFunction } else { -join("$ThisFunction", ":", "$ThisSubFunction") }

# Catch help text requests
if (($Help) -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
    Get-Help "$ThisScriptPath" -Detailed
    exit
}

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

$ProjectRoot = if ($Directory) { $Directory } else { Join-Path $PSScriptRoot '..' }
$OutputFile = Join-Path $PSScriptRoot 'Prompt-Code-Reference.md'
$ExcludedFiles = @('LICENSE')

# Map file extensions to GitHub Markdown syntax highlighting tags
$SyntaxMap = @{
    '.bash'             = 'bash'
    '.bat'              = 'batch'
    '.c'                = 'c'
    '.cc'               = 'cpp'
    '.cfg'              = 'ini'
    '.clj'              = 'clojure'
    '.cmd'              = 'batch'
    '.code-workspace'   = 'json'
    '.conf'             = 'conf'
    '.cpp'              = 'cpp'
    '.cs'               = 'csharp'
    '.css'              = 'css'
    '.cxx'              = 'cpp'
    '.dockerfile'       = 'dockerfile'
    '.env'              = 'bash'
    '.gitignore'        = 'gitignore'
    '.go'               = 'go'
    '.h'                = 'c'
    '.hpp'              = 'cpp'
    '.htm'              = 'html'
    '.html'             = 'html'
    '.ini'              = 'ini'
    '.java'             = 'java'
    '.js'               = 'javascript'
    '.json'             = 'json'
    '.jsx'              = 'jsx'
    '.kt'               = 'kotlin'
    '.less'             = 'less'
    '.lua'              = 'lua'
    '.markdown'         = 'markdown'
    '.md'               = 'markdown'
    '.perl'             = 'perl'
    '.php'              = 'php'
    '.pl'               = 'perl'
    '.ps1'              = 'powershell'
    '.psd1'             = 'powershell'
    '.psm1'             = 'powershell'
    '.py'               = 'python'
    '.r'                = 'r'
    '.rb'               = 'ruby'
    '.rs'               = 'rust'
    '.sass'             = 'sass'
    '.scala'            = 'scala'
    '.scss'             = 'scss'
    '.sh'               = 'bash'
    '.sql'              = 'sql'
    '.swift'            = 'swift'
    '.tex'              = 'latex'
    '.toml'             = 'toml'
    '.ts'               = 'typescript'
    '.tsx'              = 'tsx'
    '.txt'              = 'text'
    '.vim'              = 'vim'
    '.xml'              = 'xml'
    '.yaml'             = 'yaml'
    '.yml'              = 'yaml'
    '.zsh'              = 'bash'
}

#-------------------------------------------------------------------------------
# Main Process
#-------------------------------------------------------------------------------

Write-Host "Generating Prompt Code Reference from project root files..." -ForegroundColor Green
Write-Host "  Target directory: $(Resolve-Path -LiteralPath $ProjectRoot)" -ForegroundColor Cyan

# Purge any existing prompt artifacts before generating new output
$CleanupPattern = 'Prompt-Code-Reference*'
$ExistingArtifacts = Get-ChildItem -LiteralPath $PSScriptRoot -Filter $CleanupPattern -File -ErrorAction SilentlyContinue
if ($ExistingArtifacts) {
    Write-Host "  Removing $($ExistingArtifacts.Count) existing prompt artifact(s)..." -ForegroundColor Yellow
    foreach ($Artifact in $ExistingArtifacts) {
        Remove-Item -LiteralPath $Artifact.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Get all files from project root (recursive if -Recurse specified)
# Note: Get-ChildItem without -Force already excludes hidden files by default
$GetChildItemParams = @{
    LiteralPath = $ProjectRoot
    File = $true
}

if ($Recurse) {
    $GetChildItemParams['Recurse'] = $true
}

$RootFiles = Get-ChildItem @GetChildItemParams | Where-Object {
    # Exclude files in exclusion list
    if ($_.Name -in $ExcludedFiles) {
        return $false
    }
    # Unless -Force is specified, exclude hidden files and dotfiles
    if (-not $Force) {
        # Exclude files with Hidden attribute
        if ($_.Attributes -band [System.IO.FileAttributes]::Hidden) {
            return $false
        }
        # Exclude dotfiles (files starting with .)
        if ($_.Name.StartsWith('.')) {
            return $false
        }
    }
    return $true
} | Sort-Object Name

if ($RootFiles.Count -eq 0) {
    Write-Warning "No files found in project root to process."
    exit 1
}

Write-Host "  Found $($RootFiles.Count) files to process" -ForegroundColor Cyan

# Initialize output content
$MarkdownContent = @()
$MarkdownContent += "# Prompt Code Reference"
$MarkdownContent += ""

# Check for README file variants and process first
# Match: README.md, README (no extension), README.markdown, etc.
# Exclude: README.txt (treat as plain text)
$ReadmeFile = $RootFiles | Where-Object {
    $_.BaseName -eq 'README' -and $_.Extension -ne '.txt'
} | Select-Object -First 1

if ($ReadmeFile) {
    Write-Host "  Processing: $($ReadmeFile.FullName) (with header adjustments)..." -ForegroundColor Yellow

    try {
        $ReadmeContent = Get-Content -LiteralPath $ReadmeFile.FullName -Raw -ErrorAction Stop

        # Downgrade all headers (deepest first to avoid collisions)
        # Level 6 -> 7 (but markdown only supports up to 6, so these become invalid)
        # Level 5 -> 6
        # Level 4 -> 5
        # Level 3 -> 4
        # Level 2 -> 3
        # Level 1 -> 2
        $ReadmeContent = $ReadmeContent -replace '(?m)^######\s+', '####### '
        $ReadmeContent = $ReadmeContent -replace '(?m)^#####\s+', '###### '
        $ReadmeContent = $ReadmeContent -replace '(?m)^####\s+', '##### '
        $ReadmeContent = $ReadmeContent -replace '(?m)^###\s+', '#### '
        $ReadmeContent = $ReadmeContent -replace '(?m)^##\s+', '### '
        $ReadmeContent = $ReadmeContent -replace '(?m)^#\s+', '## '

        # Remove the first level-2 header line only (which was originally level-1)
        $ReadmeContent = $ReadmeContent -replace '^##\s+[^\r\n]+(\r?\n)?', ''

        # Fix list formatting: Insert blank line before list items that don't follow other list items
        # Match lines starting with '-' where the previous line doesn't start with '-' or whitespace+'-'
        $ReadmeContent = $ReadmeContent -replace '(?m)(?<=^(?!.*\s*-)[^\r\n]+\r?\n)(?=\s*-)', "`n"

        # Get relative path for README
        $RelativePath = ".\$($ReadmeFile.Name)"

        # Always add README.md as level-2 header at the top with relative path
        $ReadmeContent = "## ``$RelativePath```n`n" + $ReadmeContent.TrimStart()

        # Add the processed README content
        $MarkdownContent += $ReadmeContent.TrimEnd()
        $MarkdownContent += ""
        $MarkdownContent += ""
    }
    catch {
        Write-Warning "Failed to read README.md: $_"
    }
}

# Process all other files (excluding README variants)
$OtherFiles = $RootFiles | Where-Object {
    -not ($_.BaseName -eq 'README' -and $_.Extension -ne '.txt')
}

foreach ($File in $OtherFiles) {
    Write-Host "  Processing: $($File.FullName)" -ForegroundColor Yellow

    # Calculate relative path from project root
    $FullProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $FullFilePath = $File.FullName

    if ($FullFilePath.StartsWith($FullProjectRoot)) {
        $RelativePath = $FullFilePath.Substring($FullProjectRoot.Length).TrimStart('\', '/')
        $RelativePath = ".\$RelativePath"
    } else {
        $RelativePath = ".\$($File.Name)"
    }

    # Check if this is a Markdown file (excluding README.md which is already processed)
    $IsMarkdown = $File.Extension -eq '.md'

    # If it's a Markdown file and -IncludeMarkdown is NOT specified, add placeholder
    if ($IsMarkdown -and -not $IncludeMarkdown) {
        $MarkdownContent += "## ``$RelativePath``"
        $MarkdownContent += ""
        $MarkdownContent += "(All non-readme markdown content is excluded by default from this project summary document.)"
        $MarkdownContent += ""
        continue
    }

    # Determine syntax highlighting language
    $Extension = $File.Extension.ToLower()
    $Language = if ($SyntaxMap.ContainsKey($Extension)) {
        $SyntaxMap[$Extension]
    } else {
        'text'
    }

    # Read file content
    try {
        $FileContent = Get-Content -LiteralPath $File.FullName -Raw -ErrorAction Stop

        # If this is a Markdown file (and -IncludeMarkdown was specified), process headers
        if ($IsMarkdown) {
            # Downgrade all headers (deepest first to avoid collisions)
            $FileContent = $FileContent -replace '(?m)^######\s+', '####### '
            $FileContent = $FileContent -replace '(?m)^#####\s+', '###### '
            $FileContent = $FileContent -replace '(?m)^####\s+', '##### '
            $FileContent = $FileContent -replace '(?m)^###\s+', '#### '
            $FileContent = $FileContent -replace '(?m)^##\s+', '### '
            $FileContent = $FileContent -replace '(?m)^#\s+', '## '

            # Remove the first level-2 header line only (which was originally level-1)
            $FileContent = $FileContent -replace '^##\s+[^\r\n]+(\r?\n)?', ''

            # Fix list formatting: Insert blank line before list items that don't follow other list items
            # Match lines starting with '-' where the previous line doesn't start with '-' or whitespace+'-'
            $FileContent = $FileContent -replace '(?m)(?<=^(?!.*\s*-)[^\r\n]+\r?\n)(?=\s*-)', "`n"

            # Add header with relative path and processed content
            $MarkdownContent += "## ``$RelativePath``"
            $MarkdownContent += ""
            $MarkdownContent += $FileContent.TrimStart().TrimEnd()
            $MarkdownContent += ""
        } else {
            # Add header and code block with relative path in backticks
            $MarkdownContent += "## ``$RelativePath``"
            $MarkdownContent += ""
            $MarkdownContent += "``````$Language"
            $MarkdownContent += $FileContent.TrimEnd()
            $MarkdownContent += "``````"
            $MarkdownContent += ""
        }
    }
    catch {
        Write-Warning "Failed to read file: $($File.Name) - $_"
        continue
    }
}

# Write output file (force clobber if exists)
try {
    $FinalContent = ($MarkdownContent -join "`n")

    # Replace three sequential line breaks with two line breaks
    $FinalContent = $FinalContent -replace '(\r?\n){3}', "`n`n"

    $FinalContent | Set-Content -LiteralPath $OutputFile -NoNewline -Encoding UTF8 -Force -ErrorAction Stop
    Write-Host ""
    Write-Host "Successfully generated: $OutputFile" -ForegroundColor Green
    Write-Host "  Total files processed: $($RootFiles.Count)" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to write output file: $_"
    exit 1
}
