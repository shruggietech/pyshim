# Prompt Code Reference

## `.\README.md`

A deterministic, context-aware **Python shim** for Windows that lets you control *which* Python interpreter is used by apps, projects, and background tools — without breaking the global environment.

---

### Overview

**pyshim** is a lightweight command router that sits in front of `python.exe`.  
It intercepts all calls to `python` and dynamically decides which interpreter to run based on context and configuration.

This is especially useful when:

- Multiple Python versions (e.g., 3.8, 3.11, 3.12) are installed.
- You want per-project or per-app version pinning.
- You need background tools and scripts to consistently use the same interpreter as your shell session.
- You don’t want to fight Windows’ confusing PATH order or `py launcher` behavior.

---

### How It Works

When you call `python`, pyshim resolves the appropriate interpreter using this priority chain:

1. **One-shot flag**
   If called with `python --interpreter "SPEC" -- [args]`, that spec is used for this invocation only.

2. **Session override**
   If the environment variable `PYSHIM_INTERPRETER` is set (via `Use-Python` without `-Persist`), that spec is used.

3. **App-target override**
   If the environment variable `PYSHIM_TARGET` is set (e.g., `MyApp`), pyshim checks for
   `C:\bin\shims\python@MyApp.env`.

4. **Project-level pin**
   If a `.python-version` file exists in the current directory or any parent, that spec is used.

5. **Global persistence file**
   If `C:\bin\shims\python.env` exists (and persistence isn't disabled), pyshim uses that.

6. **Fallback chain**
   If no specific interpreter is found, pyshim falls back to:

   ```text
   py -3.12 → py -3 → conda run -n base python → real python.exe → (error if none found)
   ```

   **Note**: The system requires the Windows Python Launcher (`py.exe`) or Conda to be installed. The fallback intentionally uses `py.exe` and searches for real `python.exe` outside the shim directory to avoid infinite recursion (since `python.bat` IS the `python` command in your PATH).

---

### Prerequisites

- Install the **Windows Python Launcher (`py.exe`)** unless you already have it. Run any modern Python installer from [python.org](https://www.python.org/downloads/) and tick **"Install launcher for all users"** during setup. pyshim’s fallback chain expects `py.exe` (or Conda) to be present.
- Install **PowerShell 7 (pwsh)**. On Windows 11, run:

   ```powershell
   winget install --id Microsoft.PowerShell --source winget
   ```

   The Microsoft Store package or the MSI from GitHub works too—just make sure `pwsh.exe` ends up on your PATH. Windows PowerShell 5.x is not enough for pyshim’s module helpers.
- (Recommended) Set an execution policy for your account so profile scripts can run:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

   Execute that inside PowerShell 7; you can tighten it again once profiles are configured.

### Install (Recommended)

1. **Download the installer** from [the latest releases](https://github.com/shruggietech/pyshim/releases/latest):
   - Grab `Install-Pyshim.ps1` (required).
   - Optionally grab `Install-CondaPythons.ps1` if you want prebuilt Conda envs `py310`–`py314`.

2. **Run the installer** in an elevated PowerShell window (writes to `C:\bin\shims`):

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Install-Pyshim.ps1 -WritePath
   ```

   The script copies the shims to `C:\bin\shims` and adds that directory to your user PATH when it is missing. Skip `-WritePath` if you prefer to be prompted.

3. **(Optional) Provision Conda environments** after the main installer finishes:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Install-CondaPythons.ps1
   ```

   Supply `-ForceRecreate` to rebuild existing envs or `-CondaPath` if `conda.exe` lives elsewhere.

4. **Auto-load the module in PowerShell** so every shell gets the shim helpers:

   ```powershell
    Import-Module 'C:\bin\shims\pyshim.psm1' -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
   Enable-PyshimProfile
   ```

   This appends a guarded import block to your current-user profiles without touching existing content. Add `-Scope AllUsersAllHosts` and run in an elevated pwsh if you want it system-wide. Restart open terminals afterward so they pick up the refreshed PATH.

#### Manual install (advanced)

If you prefer to copy files yourself, follow these steps instead of the installer:

1. Create `C:\bin\shims` yourself.
2. Copy `python.bat`, `pip.bat`, `pythonw.bat`, `pyshim.psm1`, and `Uninstall-Pyshim.ps1` into that folder.
3. Put `C:\bin\shims` at the front of your user PATH.
4. Import the module from your PowerShell profile (or run `Enable-PyshimProfile` after importing the module once).

The single-file installer automates all of these steps, so prefer it for real machines.

---

### Uninstall

The installer drops `C:\bin\shims\Uninstall-Pyshim.ps1`. Run it from an elevated PowerShell prompt when you want to undo everything:

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\bin\shims\Uninstall-Pyshim.ps1
```

The uninstaller:

1. Verifies the shim directory only contains pyshim files (pass `-Force` to override).
2. Removes `C:\bin\shims` from your user PATH.
3. Deletes the shim directory (including any persisted specs like `python.env`).

If you added `Import-Module 'C:\bin\shims\pyshim.psm1' -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue` to your PowerShell profile, remove that line manually. After the script runs, restart your shells to pick up the cleaned PATH.

---

### Update

To pick up the newest release without hunting through GitHub, run the module helper:

```powershell
Update-Pyshim
```

By default it grabs the latest release asset and reruns `Install-Pyshim.ps1` for you. Add `-WritePath` if you also want to ensure `C:\bin\shims` stays on your PATH, or `-Tag 'v0.1.1-alpha'` to pin a specific release. Supply a `GITHUB_TOKEN` environment variable (or pass `-Token`) if your network sits behind aggressive rate limiting.

---

### Auto-load in PowerShell

- Run `Enable-PyshimProfile` after importing the module to append a guarded auto-import block to your `CurrentUser` profiles. Re-run it anytime; the sentinel comments prevent duplicates.
- Pass `-Scope AllUsersAllHosts` (and run elevated) to cover background agents or shared build accounts. Add `-IncludeWindowsPowerShell` if you still launch legacy `powershell.exe` shells that need the shim.
- The cmdlet creates `.pyshim.bak` backups the first time it touches each profile unless you pass `-NoBackup`. Opening profiles with `-NoProfile` skips the block by definition.
- The inserted code simply checks for `C:\bin\shims\pyshim.psm1` and imports it with `Write-Verbose` logging when anything goes sideways, so your existing profile customizations stay in control.

---

### Usage

#### Global Interpreter

Set the global default interpreter for all sessions:

```powershell
Use-Python -Spec 'py:3.12' -Persist
```

This writes to `C:\bin\shims\python.env`:

```text
py:3.12
```

Now, any call to `python`—including from apps and services—will use that version.

---

#### Session-Only Interpreter

```powershell
Use-Python -Spec 'conda:tools'
```

This sets the interpreter for the **current shell session** only.
Background apps will still use the global default.

---

#### Disable Global Persistence

To temporarily ignore the persisted version:

```powershell
Disable-PythonPersistence
```

This creates `C:\bin\shims\python.nopersist`, which causes the shim to skip `python.env`.

To re-enable:

```powershell
Enable-PythonPersistence
```

---

#### Per-App Overrides

You can pin specific apps to specific interpreters:

```powershell
Set-AppPython -App 'MyService' -Spec 'conda:svc'
```

This creates `C:\bin\shims\python@MyService.env` containing:

```text
conda:svc
```

When that app launches with `PYSHIM_TARGET=MyService`, it uses the pinned interpreter.

Example:

```bat
@echo off
set PYSHIM_TARGET=MyService
python -V
```

---

#### Per-Project Versions

Drop a `.python-version` file in your project root:

```text
py:3.11
```

or

```text
conda:myenv
```

When you run `python` inside that folder, pyshim automatically respects the project’s version.

---

#### One-Shot Command Execution

You can also run a single command with a specific interpreter, without persistence:

```powershell
Run-WithPython -Spec 'py:3.11' -- -m pip --version
```

---

### Package Strategy

To keep your system clean and predictable:

- **Global CLI tools** → Install with `pipx`.
  Each tool gets its own isolated virtual environment.
- **Per-project dependencies** → Use a `.venv` created by the interpreter chosen by pyshim.
- **Cache for speed** → Set `PIP_CACHE_DIR=%LOCALAPPDATA%\pip\cache`.
- **Conda users** → Continue managing environments normally (`conda:envname` specs work seamlessly).

This hybrid model ensures:

- Background apps remain stable.
- Projects stay isolated.
- Installations reuse cached wheels for efficiency.

---

### Quick Test

Once installed, open PowerShell and run:

```powershell
Use-Python -Spec 'py:3.12' -Persist
python -V
pip --version
Run-WithPython -Spec 'py:3.11' -- -c "print('hello from 3.11')"
```

---

### Example Directory Layout

```text
C:\
\-- bin\
   \-- shims\
      |-- python.bat
      |-- pip.bat
      |-- pythonw.bat
      |-- pyshim.psm1
      \-- Uninstall-Pyshim.ps1
```

The installer only drops the files above. Runtime metadata such as `python.env`, `python.nopersist`, or any `python@*.env` files show up later when you use the module; they aren't part of the shipped tree.

---

### Naming Conventions

- `python.env` — global persistent interpreter spec.
- `.python-version` — project-local interpreter spec.
- `python@AppName.env` — per-application interpreter spec.
- `python.nopersist` — disables persistence globally.
- `Uninstall-Pyshim.ps1` — local uninstaller dropped by the installer.

---

### Supported Spec Formats

| Format                  | Description                           |
| ----------------------- | ------------------------------------- |
| `py:3.12`               | Use Python 3.12 via Windows launcher. |
| `conda:myenv`           | Use Conda environment `myenv`.        |
| `C:\Path\to\python.exe` | Use this exact interpreter binary.    |

---

### Example Workflows

#### Developer Switching Between Projects

```powershell
cd ~/dev/project-a
python -V  # => Python 3.12 (from .python-version)

cd ~/dev/project-b
python -V  # => Python 3.10 (different .python-version)
```

#### Background Service Isolation

```powershell
Set-AppPython -App 'DataIndexer' -Spec 'conda:data'
set PYSHIM_TARGET=DataIndexer
python -m indexer.main
```

#### Temporary Testing

```powershell
Run-WithPython -Spec 'py:3.9' -- -c "import sys; print(sys.version)"
```

---

### Maintainers: Building the Installer

- Run `pwsh ./tools/New-PyshimInstaller.ps1` whenever the shims change. This regenerates `dist/Install-Pyshim.ps1` with the latest batch files, module, and the bundled `Uninstall-Pyshim.ps1`.
- Publish `dist/Install-Pyshim.ps1` (and optionally `tools/Install-CondaPythons.ps1`) as release assets so end users can install without cloning the repo.
- The GitHub workflow `.github/workflows/build-installer.yml` does this automatically when triggered manually or when a release is published. The artifact named `pyshim-tools` includes both scripts.

Keep contributor-only notes down here so users don’t confuse the installer generator with the installer itself.

---

### License

MIT License
Copyright (c) 2025 ShruggieTech

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...

*(full license text included in [LICENSE](LICENSE))*

---

### Links

- [ShruggieTech](https://shruggie.tech/)
- [Latest Releases](https://github.com/shruggietech/pyshim/releases)
- [dev-handbook Integration Docs](https://github.com/shruggietech/dev-handbook)

---

### Credits

Designed and maintained by h8rt3rmin8r for **ShruggieTech LLC**.
Originally conceived as part of the internal “dev-handbook” initiative for consistent Python environments across projects.

```text
¯\_(ツ)_/¯
```

## `.\.gitignore`

```gitignore
# See https://help.github.com/articles/ignoring-files/ for more about ignoring files.

# dependencies
/node_modules
/.pnp
.pnp.js
.vscode
# testing
/coverage

# next.js
/.next/
/out/

# production
/build

# misc
.DS_Store
*.pem

# debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*

# pyshim runtime state files
bin/shims/python.env
bin/shims/python.nopersist
bin/shims/python@*.env
```

## `.\examples\.python-version`

```text
C:\Users\you\miniconda3\envs\myproj\python.exe
```

## `.\.github\workflows\build-installer.yml`

```yaml
name: Build Installer

on:
  workflow_dispatch:
  release:
    types: [published]

concurrency: build-installer

jobs:
  build:
    permissions:
      contents: write
    runs-on: windows-latest
    defaults:
      run:
        shell: pwsh
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Ensure dist directory exists
        run: New-Item -ItemType Directory -Path ./dist -Force | Out-Null

      - name: Generate installer
        run: ./tools/New-PyshimInstaller.ps1 -Force -OutputPath ./dist/Install-Pyshim.ps1

      - name: Copy optional conda setup script
        run: |
          Copy-Item ./tools/Install-CondaPythons.ps1 ./dist/Install-CondaPythons.ps1 -Force

      - name: Upload installer artifact
        if: github.event_name == 'workflow_dispatch'
        uses: actions/upload-artifact@v4
        with:
          name: pyshim-tools
          path: |
            dist/Install-Pyshim.ps1
            dist/Install-CondaPythons.ps1

      - name: Attach installer to release
        if: github.event_name == 'release'
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/Install-Pyshim.ps1
            dist/Install-CondaPythons.ps1
```

## `.\.github\copilot-instructions.md`

### Project Snapshot
- pyshim routes Windows python/pip/pythonw calls via batch shims in `bin/shims` and a PowerShell module to pick the right interpreter.
- Core pieces: `python.bat` resolver, tiny wrappers (`pip.bat`, `pythonw.bat`), and `pyshim.psm1` cmdlets managing config files.
### Resolution Chain (bin/shims/python.bat)
- Priority is fixed: one-shot `--interpreter` → session `PYSHIM_INTERPRETER` → app `python@%PYSHIM_TARGET%.env` → project `.python-version` up the tree → global `python.env` → fallback.
- Fallback executes `py -3.12`, then `py -3`, then `conda run -n base python`, then the first real `python.exe` outside the shim dir; never add bare `python` or we loop forever.
- `:RESOLVE_SPEC` parses specs (`py:3.12`, `conda:env`, absolute paths); `:FIND_DOTFILE` walks parents using delayed expansion.
### Config Surfaces
- All `.env` and `.python-version` files are single-line ASCII with no trailing newline; editing scripts rely on `for /f "usebackq"`.
- `python.nopersist` toggles global persistence; guard `PYSHIM_FROM_PY` stops recursive launches when `py.exe` hands control back.
### PowerShell Module (bin/shims/pyshim.psm1)
- Cmdlets (`Use-Python`, `Run-WithPython`, etc.) use `[CmdletBinding()]`, explicit `Param()` blocks, PascalCase variables, and write files with `Set-Content -NoNewline -Encoding ASCII -LiteralPath`.
- Always compute `$Sep = [IO.Path]::DirectorySeparatorChar` before building paths and prefer `Join-Path`; thanks again, Microsoft.
- Maintain self-awareness variables (`$thisFunctionReference` et al.) for logging when new helpers are introduced.
### Testing & Verification
- Smoke test lives in `tests/smoke.ps1`; run `.\tests\smoke.ps1` from repo root when you touch the resolver or module.
- Manual sanity: `Use-Python -Spec 'py:3.12' -Persist` then `python -V`; use `Run-WithPython` for one-shot checks during debugging.
### Development Habits
- Batch files assume delayed expansion and preserve `%ERRORLEVEL%`; never early-exit without `exit /b %ERRORLEVEL%`.
- Stick to four-space indents, no tabs, no stray whitespace, and keep helper functions alphabetized when you add new ones.
- New scripts inherit the comment-based help structure shown in the module; keep examples real by using existing commands.
### Voice & Tone
- Write like a human who has seen things: short sentences, natural contractions, no boilerplate transitions.
- Sprinkle dry sarcasm at Microsoft tooling when it fits; avoid generic pep-talks or AI-scented phrasing.
### Quick References
- Shim dir is hard-coded `C:\bin\shims`; keep paths literal and quote anything user-controlled.
- Keep the repo ASCII unless the pre-existing file already goes Unicode.
- Default Python on the box is 3.12.10; confirm interpreter specs align with that reality.
- If you spot untracked changes you didn't make, stop and ask before touching them.
### When In Doubt
- Prefer tool-specific helpers (PowerShell cmdlets, batch subroutines) over inventing new workflows, and document any new CLI entrypoint.
- Ask for clarification if interpreter resolution, persistence flags, or path rules seem underspecified.

## `.\tools\Install-CondaPythons.ps1`

```powershell
<#
.SYNOPSIS
    Provision optional Miniconda environments for pyshim covering Python 3.10 through 3.14.
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

if ($Help -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
    Get-Help -Name $MyInvocation.MyCommand.Path -Full
    exit 0
}

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
```

## `.\dist\Install-Pyshim.ps1`

```powershell
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
UEsDBBQAAAAIALlibFtfyrxgXgAAAGcAAAAHAAAAcGlwLmJhdHNITc7IV8hPS+PlKk4tyclPTszh
5Qpy9VVIzSsuLUpVKMgsUMhNLEnOSC1WKM9ILEktSy1SKKgsycjP00tKLFEoSi3OzylLTeHlUlKt
SykwQEgpKejmgrWravFyAQBQSwMEFAAAAAgAo51xW1osPLRiCQAAQiIAAAsAAABweXNoaW0ucHNt
McVZbXPbuBH+nhn/hx1HU0qtqWvab051E50iJ7qJZY3oJM3EngxErkScSYAFQClqzv+9A4AvoETZ
sq/T+oMlSsDuYvfZZ3ehlxCQNYKKqYQlTRBiFHgOo/ObBWU3MqapvMm2+rWfyfTVyYuXMEkzLpSz
ZSl4ClueC+jM5lcXkw9joAxmfINCxpgkJy9OXixzFirKGXyU6M+2KuYMfpy8AAD4x0v72g++TK9m
wSSwj/pvFHMuEQgUOyhTKDKBCgUsubA2SJRSSyYs+okLyFBIKhVQBauEL0iSbPuFgrfjYDSfzK4n
V9NaRzAbj4CEIWZKAllInuQKISMqPgMv257/vf/qb17x1jsDLsALOYvI+Xj6ySslz4bz4eX4ejyH
IMOwFj5xDJYZhvvrZ9bcestnQRVaqxTfDYT2Qh/ZGro5S1BKYLw8b0rEHQrA71Qq2dtXNOV7qt5i
ggoP6yg9e4eYSeggW5/PvgTvJ5ffJtPr8Xw2N4I5S7aVvvE/h5ezD+NahxNvX/um9in4DYOO2Wod
rzhPpAcAL8vY+9oGu/Hlz/b16yiNElS/UBZRtur2bu3HMyJI2q11fDUf6Ph0LwmLiOJiO+gsSSKx
3GKWBVupMO0HSlC2uu1oc840rusFG6rC+LZTnKn9y50Y9MpFnSCm6VsqYACeGw2v+PqdAfKYrWEA
v3LK/BlRcb3Lq4NW7qg0XVpYPLivApFXGkSX0K1l9MpULb+6RqkKWZVpPfgBc0z5Gv2JwhT8D1Sh
IMnOMvAvuAgR7muJh4A1gA7LNX00UsN/z6WCUyuwzHZkIUJEJVkkGBlqWOYqFwghSRIJXcNTwlgX
9fqnxghcCZ6zaMQTLuALJgnf1KoEqlww+3zf8IoOfcMhD5jfJAPX/KBILZfR/J/tjtOms0tINZS2
RGIn5HvLaxM+E8EoW1VO3CMRKiETKJGp18C4go2gSm+ocdZ3jDQ+AkwktqkMUPkjzhQydRgTn0iS
oz09+FM+xU1CGYI/ZiHX+QvDYDSZHDqPdWlxeowq3jcerbTsWlw/Fm/3z/AA1pvCDmPg3THHnxMH
eoegwvgGUqLCWPvDHtEcsHtAec85cHt4XC1TbmtOJviaRhjpcgqMl4rqyL+GXGoLNEHBkiTJgoR3
0sVD6c6TF/eN0v/W5mfB6TMncx/vBC7JHVqVdMW4QMcg2FAV81xBpMuZNo2q/hOKQa+gzAL7OxR8
08KRJTR8nRsuQKyInqbCKW4KHtT/r7cZwoUmocZK+B2ucuVP8yQpvebGZCSQaDwXq/vQQnpU9wCb
wiuRDkPT6WP2bJ/P0UezGwSSaCf//ycO3nftg0WmUNCsMK5D7dZoj/BaPUtCRdcIZEUo2/erprVh
lh3dys6o7lAbfG/yTdcqAoykOuWyDLq5xAg2MTIoUvp6OH83vh4Ms+xwl9W0Rr8F73IboFjTEL1m
+yTXofdg9II80x2+DGKeJ9FM8BClHHSUyPFpbZS7o62LGmZZs096lpS6yJZAM9V+AKctMHujlWoA
F3x1uDoZIU8qTC7SPguusLSkrutNDM1z5n+mKj4aRFcMfRlzBSJnhvaAmLGCLmnoQutMM7eD5YO4
2bGg0aG/8sD3wU8hoxn4/lqL4+y/2GUfE9hD+DBxuRA8nWNKqO5mhmKVp8jUDlLNPmkkfr297QzF
SjbA8qdWmPQXRJ2C77vpemqDqJ3yxoppRvMjo0wqkiT+zAzMRzGs5iOwA7YZpqWpu7Ph9XtApgRF
acdrFSOEuRAapynRPQDuj3iG9xzK0ZmLEeAamabTnOH3DENdUawqMyvqWV1LNyZEVGCoo7MvfMLW
/A6FTo6d+ZaRBHKJfTCJo7gRh98xzE01zku/gAwFzRRIDmGChOUZhITBkjIqYyBL7WT8XhXvloFw
x8PHrisqwnNJ72zE2ZKKdJJmJFQD7z1dxd5BqJeznlF5BL09OmvuOf7YsbGtRWlyXLFfNyztY0qB
zIijbjOUrlBIhI7xAqFwMkbQTak0TWEl8dkzVmdcYHSku7wBeBnNdDZ6Z+W06j5sqqfqiso783bj
38/kq3Iwvsp0spJk/J2EysivZ+dKxW4vUu2aEaUBL+uNb/5cjN2l+UXWFp1/TJOopVMpA+cCs/Ox
zs8BvCnbpiUXSMIYukb0VqdrqaQ5hk5Jqh1ml/X1084c2fCsH3KmCGXSbtSNlf6Esrwxm5uNTZ8d
ubNzqWcVlIXLtGUG6vWK+mTlGn22XVe3jr32sH5C7xDK3a0Db4sVOqX3Fy4EkrvHJsRKfVPqQRc4
Ef1LGZm2O4V6XX/Ec92KrBT8FXxdC0wGWzZpSdNqlB9GEbWOK8h9gwJhqbPPuLVAXF939VX3UHTK
ihd3I7pUiK3SE6Y70NWBMlDW4mqL99zu8ofxgt1mENk7ghbuH2OIayJWqKZcpCSh/zbZUh3vWtB0
zKKud3Pjle3gR2nZEwbwdczWVHCmG4Xb8/N3qJwPPhFB9bjT9fRqzSMSRSnFxqmQ1Ey8AFem8dB2
VLp8mSVUgffac1Ze0EShKCwud/0On/Wlu3+1+A1DBT+g881Gvtv51jwP+Lr33Dt/r4G5KW6cA3dr
nW167nvg/8Ypa9ppM8yR42u1rYevls8CW0/7jQLaNT40/Yx35jXbHd3fbL1m7Sn/duIUPBgn19Rm
0BpMMGZrN1Lm0uRQpKpN1SrtSldCizePCtYBl7clTzmtuqW97gbz0rFtpfadQCzypiWt6guaIkN0
fj6nZLUQgxG1d2HsNjEluA0pXORJYrkc/wXuqn1clAx7mJUPYLCp6cwrfvbQNNkCv8PXCzsGzzHM
hcSSRP2xEFwMi9sBmiBTyXZ0yOYm/7vnblDLqOiTB7tWZqbt7ASmozbA77wte/cd8AeKCOUHCWIG
foD6EkDCq2MPXWt44kEfFlsZ+1w/GvfMiBmIBhDoFC463OLDWkUbW9k1FomHumO7qJ2gOtXc+Uja
lJqefLjSVlv/K3Wt1jzs6z9kgpNjO4/OWwuxX/kCfIuXXxIe3tXw9cvh/IMeOF24n1W8Ul+Fto8i
QRhjlOtpoxwef+MLp3WpBNlB0v40bAdOPVTKR2iy/fL/IKUUyqqa1pyen0QrFbH+4USwo2BbLhQ6
DmaC0X9EMuwNi8/Mh7qQ/D9T4vlWPJoV9y6/N/0xbv+p6EELGkd0j/UcYZWFuylWNGYxkbBAZOUP
pg9kzv3Ji/8AUEsDBBQAAAAIALlibFsWc2NHAAYAAPgPAAAKAAAAcHl0aG9uLmJhdL1XbW/bNhD+
bsD/4SCAmTXESZxuH+pBXbNETY06tuE46Yq9uIx0irnQpErSTjwE+e0DScmW4rRNB2z54pi84z33
3MPj+TUmMwkyy5qNcXwGpwuqUqDXlAltQGGyUJpJASyD0dHkLTANCqVKUWEKUoGesTkklHMNzGjk
WbPBMgjI6MP5297ZtDe4HL7rDU5JEEVBJwC8Ywb2r6DTbGg0EDwyizpBs+G2uEwoh3hw9Es/Pon7
Rx/ik/jX0dHgvDcceKTetQsJCqMoB4Va8iUqyKSCfGVmUoAU8J6JVN5qaK1zaWuaYVjEgcCectIb
R+QhzQ+CYvG0P/zlqD+NB5cRKQyIP3MPxfKR1WA4isfnvfPJlq2QOSrNtHFpWdQHIQwFtvVMGsg4
ve5Cu82EQZUrNKggOB/FxwG020WI4SA+fzucTO1yFDhy93sQkIeOZbTmG0Cr2QBYW7zwFsUywPZ5
5OEwKPZmLDOwU/+0W2GzEZbY2+02zJDblOz//+bPHzT2pQIKFga06JWWfGEQcmpmu5BIkdJuPLjc
hXzVvYzHu5BzykRYcDKOz4f9y/hkenx2Yjmx8oNuseoyg4BUEyUBVH0ciylmTGBa24BraSR0xxeD
MuVOCOeo3Q2QS1SKpVjzXut3Eo9H43gSjz3bT0LaNt4C5sr3NWjrghyGcJTnbUPVNZovApwcjU/j
icfmOPQLTwn8dYnTm5BC8A4Z3jFtICAbb7KWl712+xkEC41XNLn5BClyNtdRAISMgAlo1f1CSKXH
4rVIRoUWn+TuyTJa62fwVVfxixD2fKbtpb2cUkDrlvIbWORhqaU3vcHJ9GQ4edPrxxA8Mg9gdGk3
6jy7Jc/Fc5jw9p9l4Vs4+BbF/BDCKZdXlEPRmFAkCK2F4Kg1pEzTK45p6FIT0qwL/rjTkaAqh023
LOXwHAqqXv8zDT+G8IZybqFBMqMWz+apu7ZPoA673hQA2jBSmKEChZa41R7eoQ2XK9QoDFCRwmA4
gUTOmbiGTMk5UGt3RY17IJuN2xkqhHwFrwYXfTh8tdNxFJN4PB6O+/Fl3CdRdAAF648u75vx8Gw6
+lC5vbUOmK+g/WKv41v542z/88BPRl0TN1Er387himpHGl1Sxq3KSmx+ew0PdnagtR3LW6mFgLbw
Z/lLGcDOJno9dl8m1NhHpiibf73vEMyMGjvI2JqZGdN+iEmZwsRItWo2vq7ejyWv60MP/7QpfHRC
dnxZHPqG5UDFCmbMABOapTY6+oCZ5Ckqa+pGsIDYCWQUwD1kTKT+ES9bc+AIKruwUlJxXCKHTu1x
rzG2aaifbYWeJuoGPS2V6fqjQS4MJByp4qtmw4H7LV9ZzH/AQG7RmcmFSO2o5QZEexmEhIXrJMDp
QiQzVPuufnvQebVz2GyUU+DLg4OXFovHRqrwCZDvN4ZVuXqHSkvwuZAORMU4MaerKwSc52YV7gI5
hMhmtKSqmB+mOscksiPUus+VwndbBWEos5Ko2oDys/Mqe5/zKNueO548HEbl8uZyuNPWzK9HHM/v
XmHvS6+NsknvJ93A25XVL5vyVv19WiiWReCu94s8gDWq2iUi1p6U1+hzQP0A5qfuLyLNV8+FuURV
wsxXWxhtUyHW5vPkuWEQjLxBAS2jkBqgGqwUBZ1j2LWvT4Lg77oEupQsBYVttLOy7dDu0tvuvJmn
i3pFUVD2lYpUNmIvJ/96jWt6qQ0PFW1mjKPF96QiM1Ho0X+1zSUiSWoPL0hjmhlMpylT2s683fdH
/XcXo7oUrRv5nUwz8YQgq5vbzG7/9vtrIRLDpNjXqzln4gaSVcJR16aeGiwf0Ynk3sbdz6Pgvoh7
X7Y1p5ge7B93A1Lzti1OLLht/xVka81U03/kWMYImo0QkGusia3qWLVsupSP5Ty39zqhQgpmf3Lm
VNk3faGtUAh5sFpWc8rZ39Sy4R+HzRBT0Lq3Vxlhpv6MyHrbHmwD9bLyZPy0oFxDslDua8rULtzi
dwrB6hiUlAZaqWJLtL+vLwbH4U+gjcy9Vpmtsz/JqbXMqEpaVUNr21KlpW7+AVBLAwQUAAAACAC5
YmxbOFZA31UAAABTAAAACwAAAHB5dGhvbncuYmF0c0hNzshXyE9L4+UqTi3JyU9OzOHlCnL1VchI
TUzJSS0uVsjMK0ktKihKLUktUtBISi0u0U1NS8svKtHk5VJSrUspMCioLMnIz9NLSixRUlDV4uUC
AFBLAwQUAAAACAAHnnFbcoTT8TgFAADRDwAAFAAAAFVuaW5zdGFsbC1QeXNoaW0ucHMxnVdtbxM5
EP4eKf9hVEXa5K6Ojq9FkVpCC0UUIrYcOtEKnN1J1tRr79nelAjy309jZ9/StOHYT8nuvD7zzHj8
eZqnEt0LoVKhlsO4LAptnI0zXcp0ZnSC1k4GzpR4PNVqIUx+mRc8cZPotVhm0ei235txw/NhvwcA
8Dm+Fy7JbgcX2iTY7436vX5vEGcifykMTCAupHBsxl0GbMYNKgeDq/WlWumEO6HV+Go91XnOVTom
oX5vcKXTUqLXmMAbLVSt7TKoLbNpJmTq30XF2mYiHxc2fxaR+0WpErIN5OYOWey4SrnUCmde8qMS
yjouJfwISbQTepjUceuDl0SHZnhFNp0268lgwaVFAqbRX1uH+Th2Rqjl7SDEYUKCJOBRoh9iAcP2
51EVEj0HYHxgddPYZEq7Wn8EP9q2ounJzVyoG4LCRqQV9Abn3wtMHKZTbZDkClGM59xFx1GxdplW
nT/39b8G/OOohpYFqMeFpZp48+8LKgqX59954rz9YBXVqnGhdIHGCut2tWbcOTTKNoqnf3jVNpQ+
7eE12gqrt8Kh8coNd0YdkD8Z4ZC91tbBUcgFuDTI0zXwokBuLDgNcwSDuV5hCsNcWCvUsrE3PgJ2
oQ0ujS5VOtVSG/gHpdT3jRuDrjSqrlOFuHJGIOX0Cl2g9KXDfH/c3gn1mFf9qHBbLpjA6XAUXi+0
QZ5kMPSm1yBU7aRLrXc8pxoHsTH9az56UnbIwBKtHBfKBkUiFL0RqsSKdbVit8y/qDm44i7J0G6r
TJH5rmokmswqGcptlx2dJOuQfLJMijuESvuB4CNR0CB8KDg3yO+6r1vJ7CLStfooBK2K/llVZocw
3lwjN57qUjlgSwd/AeMqhdD3nid7WP6JG0XMPTpLUxGAg4WQaOEeDcKC6Oth3TJuDB+QmVLBvaBm
8mapG0IrAK7QrF0m1HJ8tK9Qnspkron4Aezt9vMoBDXPyNEv9NXmUIt9tGFEwgQ+n6uVMFrlqNzt
yckrdK0Xf3Mj+FziMCJpGmUWTTRq47611G2ka26WSOOsBu3aiPxcpcPo5qbS95Izbhy1ehMSszTW
IXoetcQuhHRofFtvVX7CpwwNsvfzb5g4GuZfQrWHgy9db8CEwiqmUYdd7/C+BcWwcbPP+mYE7JsW
qhta6KWWHUbO9sJCzw7c8ZNwt+12sa8zOFerGkJUq5NHIfTStQQlW6vuSfYJBB/BYZe3H7YnQ/tc
hYXRObgMobRoYHZ2/XrfMfHKIKoHbG7YS73wO8fDnib0pjpF2l0+KlL5BrwopQxzE//t7Brd45Oe
aprt7coADtsT946bD5iUxmI1Zti5MdqchUUuFhKVk+tpx9Pm17aoqUSuygImu3EXfu0bxIkRhfPE
G7wUBhPa6nbIFztuHIslYgEsxkSr1MKzrszjmTYe/kd2h83Wwf4OeDtlCgm+0XNgIdoXUid3DXjs
zCxLaty3wnZ3z+OagD/hfenYu1LK/etVnGRIu30KydbqNz1vnSe1Ib5waMBlwoL1wQB+F84eaKAN
oLTYLvITFal65veA29f99fw/EGW/53lLnH1sUW2uQDWTaZlrZXaZ062NBUFgvoPaN6cqnZfC0pSl
79MMkzuhlhVYCW0lT+wIF1xQqZwG4Z3BdjvOvZfnsOBSkuCcJ3ckZetbFpT1BUvqpUiq7aCduh9o
4eK3DX/36vB0LWpgBv5KRjPy9Ef7BlQvQZXEOECy3ekq0epjewxODlxRSe9BtKfBUL/XpeHBK2io
1EkIF1g7jqej2PR7X79+3Rz/B1BLAQIUABQAAAAIALlibFtfyrxgXgAAAGcAAAAHAAAAAAAAAAAA
AAAAAAAAAABwaXAuYmF0UEsBAhQAFAAAAAgAo51xW1osPLRiCQAAQiIAAAsAAAAAAAAAAAAAAAAA
gwAAAHB5c2hpbS5wc20xUEsBAhQAFAAAAAgAuWJsWxZzY0cABgAA+A8AAAoAAAAAAAAAAAAAAAAA
DgoAAHB5dGhvbi5iYXRQSwECFAAUAAAACAC5YmxbOFZA31UAAABTAAAACwAAAAAAAAAAAAAAAAA2
EAAAcHl0aG9udy5iYXRQSwECFAAUAAAACAAHnnFbcoTT8TgFAADRDwAAFAAAAAAAAAAAAAAAAAC0
EAAAVW5pbnN0YWxsLVB5c2hpbS5wczFQSwUGAAAAAAUABQAhAQAAHhYAAAAA
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
```

## `.\tools\Install-Pyshim.template.ps1`

```powershell
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
__PYSHIM_EMBEDDED_ARCHIVE__
'@

Add-Type -AssemblyName System.IO.Compression.FileSystem

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
        $EnvEntries = $env:Path -split ';'
        if (-not ($EnvEntries | Where-Object { $_.TrimEnd('\\') -ieq $ShimDir.TrimEnd('\\') })) {
            $env:Path = ($EnvEntries + $ShimDir | Where-Object { $_ }) -join ';'
        }
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
```

## `.\prompt\Make-PromptCodeReference.ps1`

```powershell
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
```

## `.\bin\Make-Pyshim.ps1`

```powershell
<#
.SYNOPSIS
    Install the pyshim shims and optionally wire them into the user PATH.
.DESCRIPTION
    Copies all files from the repository shim folder (`bin/shims`) into the
    fixed installation directory (`C:\bin\shims`). Existing files are
    overwritten. If the target directory does not exist it is created.

    After copying, the script validates whether `C:\bin\shims` already lives
    in the effective PATH (process, user, or machine scopes). If the entry is
    missing you can either supply `-WritePath` up front or respond to the
    interactive prompt to append it to the user PATH. Refusing the update
    prints the manual command you need to run yourself.
.PARAMETER WritePath
    Automatically append `C:\bin\shims` to the user PATH when it is missing.
    Without this switch the script will prompt for confirmation.
.PARAMETER Help
    Display the full help text for this script.
.EXAMPLE
    .\Make-Pyshim.ps1 -WritePath

    Copies the shims into place and appends `C:\bin\shims` to the user PATH if
    it is not already present.
.#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None',DefaultParameterSetName='Default')]
Param(
    [Parameter(Mandatory=$false,ParameterSetName='Default')]
    [Alias("Path","P")]
    [Switch]$WritePath,

    [Parameter(Mandatory=$true,ParameterSetName='HelpText')]
    [Alias("h")]
    [Switch]$Help
)

# Catch Help Text Requests
if (($Help) -or ($PSCmdlet.ParameterSetName -eq 'HelpText')) {
    Get-Help -Name $MyInvocation.MyCommand.Path -Full
    Exit 0
}

# Internal self-awareness variables for verbosity/logging
$thisFunctionReference = "{0}" -f $MyInvocation.MyCommand
$thisScript = $thisFunctionReference

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

    if (-not ($SplitPaths | Where-Object { $_.TrimEnd('\') -ieq $TargetPath.TrimEnd('\') })) {
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
        if ($Entries | Where-Object { $_.TrimEnd('\') -ieq $TargetPath.TrimEnd('\') }) {
            return $true
        }
    }

    return $false
}

$ShimDir = 'C:\bin\shims'
$SourceDir = Join-Path -Path $PSScriptRoot -ChildPath 'shims'

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Shim source directory '$SourceDir' was not found."
}

if (-not (Test-Path -LiteralPath $ShimDir)) {
    if ($PSCmdlet.ShouldProcess($ShimDir,'Create shim directory')) {
        New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null
    }
}

$CopySource = Join-Path -Path $SourceDir -ChildPath '*'
if ($PSCmdlet.ShouldProcess($ShimDir,'Copy shim files')) {
    Copy-Item -Path $CopySource -Destination $ShimDir -Recurse -Force
    Write-Verbose "[$thisScript] Copied shims from '$SourceDir' to '$ShimDir'."
}

$PathScopes = Get-PyshimPathScopes
$AllScopes = @($PathScopes.Process,$PathScopes.User,$PathScopes.Machine)
$PathPresent = Test-PyshimPathPresence -TargetPath $ShimDir -Scopes $AllScopes

if ($PathPresent) {
    Write-Verbose "[$thisScript] Shim directory already present in PATH."
    return
}

$ShouldWritePath = $false
if ($WritePath) {
    $ShouldWritePath = $true
} else {
    $Response = Read-Host "Add '$ShimDir' to your user PATH? [y/N]"
    if ($Response -and ($Response.Trim() -match '^(y|yes)$')) {
        $ShouldWritePath = $true
    }
}

if ($ShouldWritePath) {
    if ($PSCmdlet.ShouldProcess('User PATH','Append shim directory')) {
        $NewUserPath = Add-PyshimPathEntry -TargetPath $ShimDir -CurrentUserPath $PathScopes.User
        [Environment]::SetEnvironmentVariable('Path',$NewUserPath,'User')
        $EnvEntries = $env:Path -split ';'
        if (-not ($EnvEntries | Where-Object { $_.TrimEnd('\') -ieq $ShimDir.TrimEnd('\') })) {
            $env:Path = ($EnvEntries + $ShimDir | Where-Object { $_ }) -join ';'
        }
        Write-Host "Added '$ShimDir' to the user PATH. Restart shells that were already open."
    }
} else {
    Write-Host "Skipping PATH update. To add it later run:`n  [Environment]::SetEnvironmentVariable('Path',( '{0};' + [Environment]::GetEnvironmentVariable('Path','User')).Trim(';'),'User')" -f $ShimDir
}
```

## `.\tools\New-PyshimInstaller.ps1`

```powershell
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

$RepoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
$SourceDir = Join-Path -Path $RepoRoot -ChildPath 'bin/shims'
$TemplatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Install-Pyshim.template.ps1'

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
```

## `.\bin\shims\pip.bat`

```batch
@echo off
setlocal
REM ensure pip matches whatever python.bat resolved
"%~dp0python.bat" -m pip %*
```

## `.\pyshim.code-workspace`

```json
{
    "folders": [
        {
            "name": "pyshim",
            "path": "."
        }
    ],
    "settings": {
        "powershell.cwd": "pyshim",
        "powershell.buttons.showPanelMovementButtons": true,
        "powershell.enableReferencesCodeLens": true,
        "powershell.codeFormatting.autoCorrectAliases": true,
        "powershell.codeFormatting.avoidSemicolonsAsLineTerminators": true,
        "powershell.codeFormatting.ignoreOneLineBlock": true,
        "powershell.codeFormatting.openBraceOnSameLine": true,
        "powershell.codeFormatting.whitespaceAfterSeparator": false,
        "powershell.codeFormatting.whitespaceAroundOperator": false,
        "powershell.codeFormatting.whitespaceBeforeOpenParen": true,
        "powershell.analyzeOpenDocumentsOnly": true,
        "editor.foldingStrategy": "indentation",
        /*"editor.defaultFormatter": "ms-vscode.powershell",*/
        "editor.formatOnSave": false,
        "editor.tabSize": 4,
        "editor.insertSpaces": true,
        "editor.detectIndentation": true,
        "editor.wordWrap": "on",
        "editor.minimap.enabled": true,
        "editor.renderWhitespace": "all",
        "editor.renderControlCharacters": true,
        "editor.renderLineHighlight": "all",
        "editor.renderFinalNewline": "on",
        "editor.rulers": [
            80,
            84,
            88,
            120,
            124,
            128,
            160
        ],
        "editor.codeLens": false,
        "editor.fontSize": 12,
        "editor.fontLigatures": true,
        "editor.lineHeight": 20,
        "editor.letterSpacing": 0.6,
        "editor.cursorBlinking": "smooth",
        "editor.cursorSmoothCaretAnimation": "on",
        "editor.cursorStyle": "line",
        "editor.cursorWidth": 2,
        "editor.cursorSurroundingLines": 3,
        "editor.cursorSurroundingLinesStyle": "default",
        "editor.hover.delay": 3000,
        "workbench.hover.delay": 3000,
        "workbench.sash.hoverDelay": 2000,
        "inlineChat.lineEmptyHint": false,
        "json.format.enable": true,
        "json.validate.enable": true,
        "json.schemas": [
            {
                "fileMatch": [
                    "manifest.json",
                    "manifest.webmanifest",
                    "app.webmanifest"
                ],
                "url": "https://json.schemastore.org/web-manifest.json"
            },{
                "fileMatch": [
                    "*_meta.json",
                    "*_directorymeta.json",
                    "*-feeds-export_index.json"
                ],
                "url": "https://cdn.h8rt3rmin8r.com/schemas/MakeIndex.meta.json"
            }
        ],
        "[powershell]": {
            "editor.defaultFormatter": "ms-vscode.powershell"
        },
        "[log]": {
            "editor.wordWrap": "off"
        }
    }
}
```

## `.\bin\shims\pyshim.psm1`

```powershell
# Save this file here: C:\bin\shims\pyshim.psm1
# Import this file from your $PROFILE in Powershell

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

    $Targets = $Targets | Sort-Object -Property Path, Origin -Unique

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
                Write-Verbose "pyshim auto-import block already present in $ProfilePath."
                continue
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
```

## `.\bin\shims\python.bat`

```batch
@echo off
REM Guard against recursion if PATH is reordered or shim calls itself
if "%PYSHIM_INVOKING%"=="1" exit /b 1
set "PYSHIM_INVOKING=1"

setlocal ENABLEDELAYEDEXPANSION
REM PYSHIM: central resolver for python on Windows (recursion-safe)

set "SHIMDIR=%~dp0"
set "GLOBAL_ENV=%SHIMDIR%python.env"
set "GLOBAL_NOPERSIST=%SHIMDIR%python.nopersist"

REM 0) One-shot flag: --interpreter "SPEC" --
set "ONESHOT_SPEC="
if /I "%~1"=="--interpreter" (
  if /I "%~3"=="--" (
    set "ONESHOT_SPEC=%~2"
    shift & shift & shift
  )
)

REM --- helpers -------------------------------------------------------
REM Resolve a SPEC (absolute path, conda:ENV, py:VER, plain)
set "RESOLVED_CMD="
call :RESOLVE_SPEC "%ONESHOT_SPEC%" RESOLVED_CMD
if defined RESOLVED_CMD goto :RUN

REM 1) Session override
if defined PYSHIM_INTERPRETER (
  call :RESOLVE_SPEC "%PYSHIM_INTERPRETER%" RESOLVED_CMD
  if defined RESOLVED_CMD goto :RUN
)

REM 2) App-target override
if defined PYSHIM_TARGET (
  set "TARGET_ENV=%SHIMDIR%python@%PYSHIM_TARGET%.env"
  if exist "%TARGET_ENV%" (
    for /f "usebackq delims=" %%P in ("%TARGET_ENV%") do set "SPEC=%%P"
    call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD
    if defined RESOLVED_CMD goto :RUN
  )
)

REM 3) .python-version (walk up)
call :FIND_DOTFILE ".python-version" PVFILE
if defined PVFILE (
  for /f "usebackq delims=" %%P in ("%PVFILE%") do set "SPEC=%%P"
  call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD
  if defined RESOLVED_CMD goto :RUN
)

REM 4) Global persistence (unless disabled)
if not exist "%GLOBAL_NOPERSIST%" if exist "%GLOBAL_ENV%" (
  for /f "usebackq delims=" %%P in ("%GLOBAL_ENV%") do set "SPEC=%%P"
  call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD
  if defined RESOLVED_CMD goto :RUN
)

REM 5) Fallback chain (recursion guards):
REM    - Prefer real py.exe if present and NOT coming from a py.bat shim
where py >NUL 2>&1
if %ERRORLEVEL%==0 if not defined PYSHIM_FROM_PY (
  set "RESOLVED_CMD=py -3.12"
  goto :RUN
)

where py >NUL 2>&1
if %ERRORLEVEL%==0 if not defined PYSHIM_FROM_PY (
  set "RESOLVED_CMD=py -3"
  goto :RUN
)

REM    - Try conda base if available
where conda >NUL 2>&1 && (set "RESOLVED_CMD=conda run -n base python" & goto :RUN)

REM    - Locate a real python.exe that is NOT this shim directory
for /f "usebackq delims=" %%P in (`where python.exe 2^>NUL`) do (
  REM skip any hit inside the shim folder
  echo "%%~dpP" | find /I "%SHIMDIR%" >NUL
  if errorlevel 1 (
    set "RESOLVED_CMD=%%P"
    goto :RUN
  )
)

REM    - Last resort: error out clearly
echo [pyshim] No real python.exe found on PATH and no usable launcher/conda. 1>&2
exit /b 9009

:RUN
%RESOLVED_CMD% %*
exit /b %ERRORLEVEL%

:RESOLVE_SPEC
REM %1 = SPEC (maybe empty), %2 = outvar
set "_spec=%~1"
if not defined _spec goto :eof

REM absolute path?
if exist "%_spec%" (
  set "%~2=%_spec%"
  goto :eof
)

REM conda:ENV
echo.%_spec%| findstr /b /c:"conda:" >NUL
if not errorlevel 1 (
  set "_env=%_spec:conda:=%"
  set "%~2=conda run -n %_env% python"
  goto :eof
)

REM py:VERSION
echo.%_spec%| findstr /b /c:"py:" >NUL
if not errorlevel 1 (
  set "_ver=%_spec:py:=%"
  set "%~2=py -%_ver%"
  goto :eof
)

REM plain token (treat as exe name): force .exe to avoid re-entering this .bat
if /I "%_spec%"=="python" set "_spec=python.exe"
set "%~2=%_spec%"
goto :eof

:FIND_DOTFILE
REM %1 = filename, %2 = outvar
set "_fn=%~1"
set "_here=%cd%"
set "_visited_dirs="
:WALKUP
if exist "%_here%\%_fn%" (
  set "%~2=%_here%\%_fn%"
  goto :eof
)
REM Guard against junction/symlink cycles
if defined _visited_dirs (
  echo.|set /p="|%_here%|" | findstr /I /C:"%_visited_dirs%" >nul && goto :eof
  set "_visited_dirs=%_visited_dirs%|%_here%"
) else (
  set "_visited_dirs=|%_here%"
)
REM Compute canonical parent using %%~f normalization
for %%P in ("%_here%\..") do set "_parent=%%~fP"
REM If parent equals current dir, we're at a root (drive or UNC); stop
if /i "%_parent%"=="%_here%" goto :eof
set "_here=%_parent%"
goto :WALKUP
```

## `.\examples\python.env`

```bash
py:3.12
```

## `.\examples\python@MyService.env`

```bash
conda:myservice
```

## `.\bin\shims\pythonw.bat`

```batch
@echo off
setlocal
REM headless interpreter (best-effort)
"%~dp0python.bat" %*
```

## `.\tests\smoke.ps1`

```powershell
$ErrorActionPreference = 'Stop'
$SepLine = "`n" + ("-" * 60) + "`n"
$TotalDurationMax = 18    # seconds
$SingleDurationMax = 3    # seconds
$StartTime = Get-Date
$TestsFailed = $false

#-------------------------------------------------------------------------------
# Helper function to run a command with timeout and exit code monitoring
#-------------------------------------------------------------------------------
function Invoke-TimedCommand {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.String]$Description,

        [Parameter(Mandatory=$true)]
        [ScriptBlock]$Command,

        [Parameter(Mandatory=$false)]
        [System.Int32]$TimeoutSeconds = $script:SingleDurationMax,

        [Parameter(Mandatory=$false)]
        [Switch]$IsGetCommand
    )

    Write-Host "    Running: $Description" -ForegroundColor Cyan
    $CommandStart = Get-Date
    $Job = Start-Job -ScriptBlock $Command

    $Completed = Wait-Job -Job $Job -Timeout $TimeoutSeconds
    $CommandEnd = Get-Date
    $Duration = ($CommandEnd - $CommandStart).TotalSeconds

    if ($null -eq $Completed) {
    Write-Host "    TIMEOUT after $Duration seconds (max: $TimeoutSeconds)" -ForegroundColor Red
        Stop-Job -Job $Job -ErrorAction SilentlyContinue
        Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
        $script:TestsFailed = $true
        return $false
    }

    $JobOutput = Receive-Job -Job $Job -ErrorAction SilentlyContinue
    $JobState = $Job.State
    $JobError = $Job.ChildJobs[0].Error

    Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue

    if ($JobState -eq 'Failed' -or ($JobError -and $JobError.Count -gt 0)) {
        Write-Host "    FAILED (duration: $Duration seconds)" -ForegroundColor Red
        if ($JobError) {
            $JobError | ForEach-Object { Write-Host "    ERROR: $_" -ForegroundColor Red }
        }
        $script:TestsFailed = $true
        return $false
    }

    Write-Host "    Result: OK (duration: $Duration seconds)" -ForegroundColor Green
    
    if ($JobOutput) {
        if ($IsGetCommand) {
            $JsonOutput = $JobOutput | Select-Object CommandType, Name, Version, Source | ConvertTo-Json -Compress
            Write-Host "    Output: $JsonOutput" -ForegroundColor Gray
        } else {
            $FlatOutput = ($JobOutput | Out-String).Trim() -replace "`r`n", ", " -replace "`n", ", "
            Write-Host "    Output: $FlatOutput" -ForegroundColor Gray
        }
    }
    return $true
}

function Write-CondaStatus {
    [CmdletBinding()]
    Param()

    Write-Host "Inspecting Conda / Miniconda environment:" -ForegroundColor Yellow

    $Candidates = @()
    if ($env:CONDA_EXE) {
        $Candidates += $env:CONDA_EXE
    }

    try {
        $CommandHit = (Get-Command conda -ErrorAction Stop).Source
        if ($CommandHit) {
            $Candidates += $CommandHit
        }
    } catch {
        # ignored on purpose
    }

    $DefaultUserInstall = Join-Path -Path $env:USERPROFILE -ChildPath 'miniconda3\Scripts\conda.exe'
    $Candidates += $DefaultUserInstall

    Write-Host "    Running: (Conda detection)" -ForegroundColor Cyan
    $Candidates = $Candidates | Where-Object { $_ } | Select-Object -Unique
    if ($Candidates.Count -gt 0) {
        Write-Host "    Output: Candidate paths -> $(($Candidates -join ', '))" -ForegroundColor Gray
    } else {
        Write-Host "    Output: No candidate paths discovered." -ForegroundColor Gray
    }

    $ResolvedConda = $null
    foreach ($Candidate in $Candidates) {
        $ResolvedCandidate = Resolve-Path -LiteralPath $Candidate -ErrorAction SilentlyContinue
        if ($ResolvedCandidate) {
            $ResolvedConda = $ResolvedCandidate.ProviderPath
            break
        }
    }

    if (-not $ResolvedConda) {
        Write-Host "    Result: Conda executable not detected." -ForegroundColor Yellow
        return
    }

    Write-Host "    Result: Found conda executable." -ForegroundColor Green
    #Write-Host "    Output: $ResolvedConda" -ForegroundColor Gray

    Write-Host "    Running: $ResolvedConda --version" -ForegroundColor Cyan
    $VersionOutput = & $ResolvedConda '--version' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Output: $((($VersionOutput | Out-String).Trim()))" -ForegroundColor Gray
    } else {
        Write-Host "    Output: Unable to determine conda version." -ForegroundColor Yellow
    }

    Write-Host "    Running: $ResolvedConda env list --json" -ForegroundColor Cyan
    $EnvJsonRaw = & $ResolvedConda 'env' 'list' '--json' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Output: Unable to enumerate conda environments." -ForegroundColor Yellow
        return
    }

    try {
        $EnvInfo = ($EnvJsonRaw | Out-String | ConvertFrom-Json)
    } catch {
        Write-Host "    Output: Failed to parse conda environment list." -ForegroundColor Yellow
        return
    }

    if (-not $EnvInfo -or -not $EnvInfo.envs) {
        Write-Host "    Output: No conda environments reported." -ForegroundColor Yellow
        return
    }

    $TargetEnvs = 'py310','py311','py312','py313','py314'
    $EnvSummaries = @()
    foreach ($Target in $TargetEnvs) {
        $MatchingPath = $EnvInfo.envs | Where-Object { $_.Split([IO.Path]::DirectorySeparatorChar)[-1].ToLower() -eq $Target }
        if (-not $MatchingPath) {
            $EnvSummaries += ('{0}: missing' -f $Target)
            continue
        }

        #Write-Host "    Running: $ResolvedConda run -n $Target python -c 'import sys; print(sys.version.split()[0])'" -ForegroundColor Cyan
        $VersionProbe = & $ResolvedConda 'run' '-n' $Target 'python' '-c' 'import sys; print(sys.version.split()[0])' 2>&1
        if ($LASTEXITCODE -eq 0) {
            $EnvSummaries += ('{0}: {1}' -f $Target, (($VersionProbe | Out-String).Trim()))
        } else {
            $EnvSummaries += ('{0}: version query failed' -f $Target)
        }
    }

    if ($EnvSummaries.Count -gt 0) {
        Write-Host "    Output: $($EnvSummaries -join ', ')" -ForegroundColor Gray
    }
}

#-------------------------------------------------------------------------------
Write-Host ''
Write-Host "Beginning smoke tests for pyshim." -ForegroundColor Green
#-------------------------------------------------------------------------------

$SepLine | Write-Host
Write-Host "Checking for py, python, and pip commands in PATH:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "where.exe py" -Command {
    where.exe py
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "where.exe python" -Command {
    where.exe python
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "where.exe pip" -Command {
    where.exe pip
    $LASTEXITCODE
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Verifying that py, python, and pip commands are functional:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "Get-Command py" -IsGetCommand -Command {
    Get-Command py -ErrorAction Stop
} | Out-Null

Invoke-TimedCommand -Description "Get-Command python" -IsGetCommand -Command {
    Get-Command python -ErrorAction Stop
} | Out-Null

Invoke-TimedCommand -Description "Get-Command pip" -IsGetCommand -Command {
    Get-Command pip -ErrorAction Stop
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Checking versions of py, python, and pip:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "py -V" -Command {
    py -V
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "python -V" -Command {
    python -V
    $LASTEXITCODE
} | Out-Null

Invoke-TimedCommand -Description "pip --version" -Command {
    pip --version
    $LASTEXITCODE
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Running a simple Python command using the pyshim function Run-WithPython:" -ForegroundColor Yellow

Invoke-TimedCommand -Description "Run-WithPython -Spec 'py:3' -- -c `"print('ok')`"" -Command {
    Import-Module 'C:\bin\shims\pyshim.psm1' -Force -DisableNameChecking
    Run-WithPython -Spec 'py:3' -- -c "print('ok')"
    $LASTEXITCODE
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Testing dotfile search from drive root (regression check for infinite loop):" -ForegroundColor Yellow

Invoke-TimedCommand -Description "python -c `"print('ok from root')`" (from C:\)" -Command {
    Push-Location C:\
    try {
        $output = & python -c "print('ok from root')" 2>&1
        $exitCode = $LASTEXITCODE
        Pop-Location
        if ($exitCode -ne 0) { throw "Exit code: $exitCode" }
        $exitCode
    } catch {
        Pop-Location
        throw
    }
} | Out-Null

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-Host "Testing dotfile search from UNC path (if available):" -ForegroundColor Yellow

$UncPath = "\\localhost\c$"
if (Test-Path -LiteralPath $UncPath -ErrorAction SilentlyContinue) {
    Invoke-TimedCommand -Description "python -c `"print('ok from UNC')`" (from $UncPath)" -Command {
        Push-Location $UncPath
        try {
            $output = & python -c "print('ok from UNC')" 2>&1
            $exitCode = $LASTEXITCODE
            Pop-Location
            if ($exitCode -ne 0) { throw "Exit code: $exitCode" }
            $exitCode
        } catch {
            Pop-Location
            throw
        }
    } | Out-Null
} else {
    Write-Host "    Skipped (UNC path not accessible)" -ForegroundColor Gray
}

#-------------------------------------------------------------------------------
$SepLine | Write-Host
Write-CondaStatus

#-------------------------------------------------------------------------------
$SepLine | Write-Host
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds

if ($TestsFailed) {
    Write-Host "Total duration: $TotalDuration seconds." -ForegroundColor Red
    Write-Host "Smoke FAILED: One or more tests failed." -ForegroundColor Red
    Write-Host "Exiting script." -ForegroundColor Red
    exit 1
} elseif ($TotalDuration -gt $TotalDurationMax) {
    Write-Host "Total duration: $TotalDuration seconds." -ForegroundColor Red
    Write-Host "Smoke FAILED: Total duration exceeds maximum of $TotalDurationMax seconds." -ForegroundColor Red
    Write-Host "Exiting script." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Total duration: $TotalDuration seconds." -ForegroundColor Green
    Write-Host "Smoke OK (Tests passed successfully)." -ForegroundColor Green
    Write-Host "Exiting script." -ForegroundColor Green
    exit 0
}
```

## `.\bin\shims\Uninstall-Pyshim.ps1`

```powershell
<#
.SYNOPSIS
Removes the pyshim shim directory and cleans up PATH entries.

.DESCRIPTION
Runs either the module-provided `Uninstall-Pyshim` cmdlet or the bundled standalone logic to delete the shim payload, optional config files, and PATH references. Provides color-coded status messages so the user can see what was removed.

.PARAMETER Force
Removes unexpected files in the shim directory instead of stopping for review.

.EXAMPLE
PS C:\> .\Uninstall-Pyshim.ps1
Runs the uninstaller in interactive mode and leaves any unexpected files behind.

.EXAMPLE
PS C:\> .\Uninstall-Pyshim.ps1 -Force
Forces removal of the shim directory even if extra files are present.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
Param(
    [Switch]$Force
)

$ShimDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ShimDir -ChildPath 'pyshim.psm1'

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

function Invoke-StandalonePyshimUninstall {
    Param(
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

    Write-PyshimMessage -Type Success -Message 'pyshim has been removed.'
}

Write-PyshimMessage -Type Info -Message 'Starting pyshim uninstall.'

if (Test-Path -LiteralPath $ModulePath) {
    try {
        Import-Module -Name $ModulePath -Force -DisableNameChecking
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
```
