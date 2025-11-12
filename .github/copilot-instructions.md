# Copilot Instructions

This document provides instructions for AI coding agents to effectively assist in developing the pyshim project.

## Project Overview: pyshim

**pyshim** is a deterministic, context-aware Python shim system for Windows that intercepts `python`, `pip`, and `pythonw` calls to route them to the correct interpreter based on context. The system consists of three core components:

1. **Batch Shims** (`python.bat`, `pip.bat`, `pythonw.bat`) — Entry points that resolve interpreter specs through a priority chain and delegate to the actual interpreter
2. **PowerShell Module** (`pyshim.psm1`) — User-facing cmdlets for managing interpreter selection and persistence
3. **Config Files** (`python.env`, `python@AppName.env`, `.python-version`) — Text files storing interpreter specifications

### Architecture & Resolution Priority

When `python.bat` is invoked, it resolves the interpreter using this exact priority chain:

1. **One-shot flag**: `--interpreter "SPEC" --` (used by `Run-WithPython` and direct invocation)
2. **Session variable**: `$env:PYSHIM_INTERPRETER` (set by `Use-Python` without `-Persist`)
3. **App-target override**: `python@%PYSHIM_TARGET%.env` (set by `Set-AppPython`)
4. **Project pin**: `.python-version` file in current directory or parent chain (walks up directory tree)
5. **Global persistence**: `python.env` (unless `python.nopersist` marker exists)
6. **Fallback chain**: `py -3.12` → `py -3` → `conda run -n base python` → real `python.exe` (not in shim dir) → (error if none found)

**Important**: The fallback chain avoids infinite recursion by:

- Using `PYSHIM_FROM_PY` guard variable when called from `py.bat`
- Skipping `python.exe` results that point to the shim directory itself
- Using explicit commands (`py.exe`, `conda`, absolute paths) rather than bare `python`

### Interpreter Spec Formats

The system supports three spec formats (stored in `.env` and `.python-version` files):

- `py:3.12` — Uses Windows `py` launcher with specific version
- `conda:envname` — Uses Conda environment
- `C:\Path\to\python.exe` — Absolute path to interpreter binary

These specs are parsed by the `:RESOLVE_SPEC` subroutine in `python.bat` (lines 91-115).

### Key Files & Their Roles

- **`python.bat`** (~137 lines): Core resolver logic with batch subroutines `:RESOLVE_SPEC` and `:FIND_DOTFILE` (walks directory tree for `.python-version`)
- **`pip.bat`** (4 lines): Trivial wrapper that calls `python.bat -m pip`
- **`pythonw.bat`** (4 lines): Best-effort headless wrapper (delegates to `python.bat`)
- **`pyshim.psm1`** (124 lines): PowerShell module with cmdlets `Use-Python`, `Disable-PythonPersistence`, `Enable-PythonPersistence`, `Set-AppPython`, `Run-WithPython`
- **`tests/smoke.ps1`**: Basic smoke test verifying `python -V`, `pip --version`, and `Run-WithPython`

**Note**: `py.bat` is NOT included — the shim relies on the native Windows Python Launcher (`py.exe`) being installed globally.

### Critical Implementation Details

**Batch File Constraints**:

- Uses `ENABLEDELAYEDEXPANSION` for variable expansion in loops
- Subroutines use `call :LABEL` pattern with output variables passed by name (e.g., `call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD`)
- `:FIND_DOTFILE` implements parent directory walking using `%%~dpD` to extract parent paths
- Exit codes must be preserved with `exit /b %ERRORLEVEL%`
- **Critical**: Final fallback uses `py` (not `python`) to prevent infinite recursion since `python.bat` IS the `python` command in PATH

**PowerShell Module Design**:

- All cmdlets use `[CmdletBinding()]` with no parameters (lightweight functions)
- File operations use `-LiteralPath` for whitespace-safe handling
- Files written with `-NoNewline -Encoding ASCII` to avoid trailing newlines and BOM issues
- Hardcoded shim directory: `C:\bin\shims` (not parameterized — design choice for simplicity)

**File Format Discipline**:

- All `.env` files contain a single line with no trailing newline (enforced by `Set-Content -NoNewline`)
- Parsed with `for /f "usebackq delims="` in batch to preserve exact content
- `.python-version` files follow same single-line format

### Development Workflows

**Testing Changes**:

```powershell
# Run smoke test to verify basic functionality
.\tests\smoke.ps1

# Manual verification of resolution priority
Use-Python -Spec 'py:3.12' -Persist
python -V
```

**Adding New Cmdlets**:

- Follow existing pattern in `pyshim.psm1`
- Include full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
- Use `$ShimDir = 'C:\bin\shims'` for path construction
- File writes should use `-NoNewline -Encoding ASCII`

**Modifying Resolution Logic**:

- Changes to priority chain happen in `python.bat` (lines 10-88)
- Spec parsing logic lives in `:RESOLVE_SPEC` subroutine (lines 91-115)
- Always preserve `%ERRORLEVEL%` when delegating to resolved interpreter

### Common Pitfalls

- **Trailing Newlines**: Config files MUST NOT have trailing newlines (breaks batch parsing)
- **Path Separators**: Use `Join-Path` in PowerShell; avoid hardcoded `\` for potential Linux compatibility
- **Delayed Expansion**: Required in batch for variable mutation in loops/conditionals
- **Case Sensitivity**: Batch is case-insensitive, but `.python-version` filename is lowercase by convention (matching `pyenv`)
- **Infinite Recursion**: Never use bare `python` in fallback chain — `python.bat` IS the `python` command, so it would call itself. Always use `py.exe` or absolute paths in fallbacks

### Design Philosophy

pyshim prioritizes **determinism** and **zero-configuration** over flexibility:

- No installer required — just copy files and update PATH
- Hardcoded paths (`C:\bin\shims`) for predictability
- Minimal dependencies (PowerShell 5.1+, Windows batch)
- Spec files use simple text format (no JSON/YAML parsing overhead)
- Global state is explicit (`.env` files in shim directory, not registry or AppData)

## Standards for Writing Style and Tone

- Always write in a way that reads as genuinely human and free from any linguistic patterns that commonly expose AI-generated text. Avoid all "AI tells," including but not limited to: excessive politeness, generic transitions (e.g., "Furthermore," "In conclusion," "Overall"), filler phrases ("It's important to note that"), parallel-sounding constructions ("not only...but also"), and overly balanced or neatly summarized conclusions.
- Favor a natural flow that mirrors how an experienced writer or professional would actually communicate:
  - Use sentence length variation (occasional fragments are fine).
  - Use contractions naturally ("I'm," "don't," "that's").
  - Avoid corporate buzzwords and inflated adjectives unless context demands them.
  - Use clarity, subtle rhythm, and precision over "niceness."
  - Never overexplain or restate points unless it aids comprehension.
  - Eliminate template phrasing like "Here's a breakdown," "Let's explore," or "This means that."
- The tone should sound authentic, thoughtful, and intentional, not algorithmically tidy. Write as if the content were edited by a sharp human who values brevity, rhythm, and nuance more than structure or formality.
- Use a little bit of sarcasm or dry humor where appropriate and have fun talking trash about tools and frameworks developed by Microsoft (they deserve it).

## System Environment Handling

### Sensitivity to File and Directory Names

While this project is likely to be developed in a Windows 11 environment, it should be assumed that some (or all) of the code may be run in an Ubuntu Linux production environment. Windows file paths are case-insensitive, while Linux file paths use a much more robust case-sensitive approach. As such, when writing scripts that interact with the filesystem, care must be taken to ensure that file and directory names are treated in a universally compatible manner at all times. In addition to the matter of case sensitivity, Windows file systems use (for some unknowable reason) a `\` (backslash "escape") separator character, while Linux file systems use a `/` (forward slash) separator. So while it would be convenient to treat all paths like Internet URLs like Linux, when writing scripts that interact with the filesystem, care must be taken to ensure that file and directory paths are constructed and parsed correctly for the target operating system (thanks to Microsoft).

In Powershell, use a standard discovery method to determine the appropriate path separator for the current operating system and store that separator in a variable: `$Sep` (adapt this method for other scripting languages as needed):

```powershell
$Sep = [IO.Path]::DirectorySeparatorChar
```

File and directory names should avoid spaces where possible. However, scripts must always account for cases where whitespace exists. When handling paths or user inputs in PowerShell, use the `-LiteralPath` parameter where supported (instead of the intuitive but ill-advised `-Path` parameter). Always verify the compatibility of the `-LiteralPath` parameter with each cmdlet to prevent errors when processing path references, as some cmdlets do NOT support `-LiteralPath`.

On a side note, one of the original creators of PowerShell publicly complained about the broken state of the `-Path` parameter and its inconsistent handling of special characters. So (as is the case with all dumpster fire code written by Microsoft) this is a known fundamental bad-practice end-user pain point that Microsoft just simply ignores (okay I'm good now - moving on).

### Python Versioning and Management

- The system-wide Python installation is exactly version `3.12.10`. This should be taken into account when writing or updating scripts that may interact with the Python installation or its packages.
- Whenever possible, try to use virtual environments for Python projects to avoid dependency conflicts and ensure consistent behavior across different development and production environments.
- Consider using python-poetry.org for managing Python project dependencies and virtual environments.
- If Poetry is not installed, it can be installed using one of the following commands:

  Install Poetry on Windows 11 (Powershell):

  ```powershell
  (Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | py -
  ```

  Install Poetry on Ubuntu Linux (Bash):

  ```bash
  curl -sSL https://install.python-poetry.org | python3 -
  ```

  Note: You may need to also set up your system PATH to include Poetry's bin directory. Refer to the official Poetry documentation for guidance.
- Python is another dumpster fire situation. Backwards compatibility is a nightmare, and the ecosystem is riddled with poorly maintained packages and security vulnerabilities, and almost every project prides itself on reinventing the wheel. Always expect the worst and check the maintenance status of any third-party libraries before including them in a project, and only include well-established, actively maintained packages AT ALL TIMES.

## General Code Formatting

- **Nested Helper Functions:** For complex functions, break down logic into smaller, single-purpose nested helper functions. These helpers should follow a `ParentFunctionName-HelperAction` naming convention (e.g., `ApkExtract-ResolvePath`).
- **Variable Naming Convention:** All variables should use **PascalCase** (e.g., `$NumbersCount`, `$InputFile`, `$ExitCode`). Do not use snake_case or camelCase unless absolutely necessary (like conformance with existing third-party code).
- **Clean Whitespace:**
  - Never include a line that contains only whitespace characters. If a blank line is needed for readability, it must be completely empty.
  - Never leave trailing whitespace at the end of any line.
  - Always leave a single blank line between major logical sections of code (e.g., between function declarations)
  - Never indent code using tab characters. Always use exactly **four spaces** for each level of indentation.

- **Brace Style (One True Brace Style):** When declaring functions, `if` statements, loops, or any other code block, the opening curly brace `{` **must** be on the same line as the declaration. The closing curly brace `}` **must** be on its own line, aligned with the start of the declaration.

    ```powershell
    # Correct
    function Get-Something {
        if ($Condition) {
            # Do work
        }
    }

    # Incorrect
    function Get-Something
    {
        # ...
    }
    ```

## Scripting Standards (Powershell Focused)

All non-Powershell scripts should include an appropriate shebang line at the top of the file:

- Bash: `#!/usr/bin/env bash`
- Python: `#!/usr/bin/env python3`
- Node.js: `#!/usr/bin/env node`
- etc.

Important Note: Never include a shebang line in Powershell scripts. Doing so will prevent the script from behaving correctly in Windows environments.

All scripts and functions should closely adhere to the following general structure:

1. Introduction
    - **Comprehensive ReadMe:** Comprehensive comment-based Help Text documentation
    - **`[CmdletBinding()]` Declaration:** (Powershell only)
    - **`Param()` Block:** Define all input parameters (Powershell only)
2. Declarations
    - **Function Declarations:** Function and sub-function declarations in alphabetical order
    - **Variable & Array Declarations:** Variable and array declarations, including self-awareness variables (be sure to carefully sequence these correctly to avoid dependency issues when initializing variables that depend on other locally declared variables)
3. Core Logic
    - **Catch Help Text Requests:** Display the help text and gracefully exit if the `-Help` parameter is specified
    - **Validate Inputs:** Validate user inputs or required environment variables if necessary
    - **Main Process Logic:** The core logic of the script or function, broken down into logical sections with clear comments explaining each part
4. Conclusion
    - **Return Output:** Return outputs to the stdout stream and/or write require output files as needed
    - **Garbage Collection:** Clean up any temporary files or resources used during execution
    - **Exit Gracefully:** Exit with an appropriate exit code indicating success or failure (depending on the language, this may be implicit)

### Comprehensive ReadMe

Example comment-based help block for Powershell:

```text
<#
.SYNOPSIS
    A brief summary of the function's purpose.
.DESCRIPTION
    A more detailed description of what the function does, how it behaves, and the kinds of inputs and outputs it handles.
.PARAMETER ParameterName
    A clear explanation of what this parameter is for along with any constraints or special behaviors.
.EXAMPLE
    A practical example of how to use the function.
.LINK
    [example.com](https://example.com/)
#>
```

- When writing any Powershell script (or function or sub-function), always include a full comment-based help block at the very beginning of the file and before the internal logic of each function.
- At a minimum, in Powershell, this block must include `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` for each parameter, and at least one `.EXAMPLE`. Include a `.LINK` for external references where applicable.
- Relevant help text should be included in non-Powershell scripts as well (using appropriate interactive features and appropriate comment syntax).

### CmdletBinding (Powershell)

Example `[CmdletBinding()]` declaration:

```powershell
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None',DefaultParameterSetName='Default')]
```

When writing PowerShell functions and scripts, always include a proper `[CmdletBinding()]` declaration directly following the comment-based help text. This ensures that the function behaves like a standard cmdlet, supporting common features like `-Verbose`, `-Debug`, and `-ErrorAction`.

- Avoid using empty whitespace inside the parentheses of `CmdletBinding()`. This line is already quite long, so keep it tight.
- If the function performs actions that change system state (e.g., file operations), consider including `SupportsShouldProcess=$true` in the declaration.
- Include `ConfirmImpact='None'` unless the function performs high-impact actions (who knows whatever that means).
- Always specify a `DefaultParameterSetName='Default'` to ensure predictable behavior regardless of how many parameter sets are defined.
- Additional attributes can be included if doing so would facilitate the function's specific needs and assumed use-cases (such as handling of pipeline inputs, etc). Make sure to understand the implications of each attribute before including it as these can completely break an entire script or function if misused.

### Param Block (Powershell)

Define all parameters within a `Param()` block immediately following the `[CmdletBinding()]` declaration. This ensures standard cmdlet behavior. Be sure to leave a blank line between each clump of attributes related to a single parameter for readability.

Example `Param()` block:

```powershell
Param(
    [Parameter(Mandatory=$true,ParameterSetName='Default')]
    [Alias("f")]
    [System.String]$File,

    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("o","outfile")]
    [System.String]$Output = "ProjectOutput.txt",

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias("h")]
    [Switch]$Help
)
```

- **Named Parameter Groups:** Organize parameters into logical groups using the `ParameterSetName` attribute. This helps clarify which parameters can be used together and improves usability and discoverability from within the standard Help Text generator.
- **Parameter Attributes:** Use attributes like `[Parameter(Mandatory=$true)]` to enforce required parameters within the context of named parameter groups. The Help text parameter (`-Help`) should always inhabit a `HelpText` parameter group and be mandatory within that group.
- **Parameter Aliases:** Provide common, best-practice aliases for parameters to improve usability (e.g., `[Alias("f","file","inputfile")]`) but carefully avoid overly generic aliases that could conflict with other parameters. Conflicts in parameter names and aliases should be strongly avoided. Always remember that parameters are case-insensitive in PowerShell
  - Example: Including both `-File` and `-file` aliases would break the script or function.
- **Type Constraints:** Strongly type all parameters (e.g., `[System.String]`, `[System.Boolean]`, `[Switch]`).
- **Default Values:** If an input has a highly-likely default value, assign default values to optional parameters directly in the `Param()` block (e.g., `$Verbosity = $true`) and avoid assigning defaults to mandatory parameters (as this angers the syntax parsers in Visual Studio).

### Self-Awareness Variables

For effective logging and verbosity, functions and scripts should all declare "self-awareness" variables at the beginning to establish a caller reference string. This is especially important for nested functions to create a logical call stack.

Example self-awareness variable declarations:

```powershell
# Internal self-awareness variables for use in verbosity and logging
$thisFunctionReference = "{0}" -f $MyInvocation.MyCommand
$thisSubFunction = "{0}" -f $MyInvocation.MyCommand
$thisFunction = if ($null -eq $thisFunction) { $thisSubFunction } else { -join("$thisFunction", ":", "$thisSubFunction") }
```
