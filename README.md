# pyshim

A deterministic, context-aware **Python shim** for Windows that lets you control *which* Python interpreter is used by apps, projects, and background tools — without breaking the global environment.

---

## Overview

**pyshim** is a lightweight command router that sits in front of `python.exe`.  
It intercepts all calls to `python` and dynamically decides which interpreter to run based on context and configuration.

This is especially useful when:

- Multiple Python versions (e.g., 3.8, 3.11, 3.12) are installed.
- You want per-project or per-app version pinning.
- You need background tools and scripts to consistently use the same interpreter as your shell session.
- You don’t want to fight Windows’ confusing PATH order or `py launcher` behavior.

---

## How It Works

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

## Prerequisites

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

## Install (Recommended)

1. **Download the Windows installer** from [the latest releases](https://github.com/shruggietech/pyshim/releases/latest):
   - Grab `Pyshim.Setup.exe`. The WinForms bootstrapper requires a single UAC approval and bundles the latest shims, module, and helper scripts.

2. **Run `Pyshim.Setup.exe`** (UAC prompt expected) and pick the actions you want:
   - Keep `C:\bin\shims` at the front of both the machine and user PATH values.
   - Copy the shims, refresh the shared Conda environments, and insert the guarded `Enable-PyshimProfile` block for CurrentUser and AllUsers scopes.
   - The log window mirrors every command so you can see exactly what changed; clear any checkbox to skip that step.

3. **Re-run the installer anytime** to repair an existing deployment or refresh PATH/profile wiring. The operations are idempotent, so nothing is duplicated.

### Manual Install (PowerShell)

Only take this path when you cannot run the GUI installer (locked-down servers, offline images, etc.). You are responsible for the work the installer normally automates:

1. **Stage the payload** – Download the latest release asset or clone the repo, then copy `python.bat`, `pip.bat`, `pythonw.bat`, `pyshim.psm1`, the Conda helper scripts, and `Uninstall-Pyshim.ps1` into `C:\bin\shims` (create the directory first).
2. **Wire up PATH** – Ensure `C:\bin\shims` sits at the end of your user PATH at minimum (`[Environment]::SetEnvironmentVariable('Path', '<existing>;C:\bin\shims','User')`). Update the current `$env:Path` so open shells can see it immediately.
3. **Trust the module for the session** – In PowerShell 7 run `Import-Module 'C:\bin\shims\pyshim.psm1' -DisableNameChecking -ErrorAction SilentlyContinue -WarningAction SilentlyContinue` to load the helper cmdlets.
4. **Persist the auto-import** – Execute `Enable-PyshimProfile` (add `-Scope AllUsersAllHosts` and run elevated if you need system-wide coverage, `-IncludeWindowsPowerShell` for legacy shells). This inserts the guarded import block that the installer normally writes.
5. **Refresh managed Conda envs (optional)** – Run `Refresh-CondaPythons -IgnoreMissing` or `Install-CondaPythons` from the shim directory if you rely on the curated `py310..py314` interpreters. Supply `-CondaPath` when detection fails.

Following every step above reproduces the installer’s behaviour; skipping any of them means you are also skipping that piece of automation.

Need a headless option for CI or fleet tools? Use `dist/Install-Pyshim.ps1 -WritePath -Confirm:$false`, which performs the same actions as the GUI but stays scriptable.

#### PowerShell Installer Caveats

- Even though the script is Authenticode-signed, Windows still honors the local execution policy. If your policy blocks unsigned scripts, start by unblocking and verifying the file:

   ```powershell
   Unblock-File .\Install-Pyshim.ps1
   Get-AuthenticodeSignature .\Install-Pyshim.ps1 | Format-List Status,StatusMessage,SignerCertificate
   ```

- Run the installer from an elevated PowerShell 7 session so it can touch `C:\bin\shims`, machine PATH, and AllUsers profiles:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   pwsh -NoLogo -Command "powershell.exe -ExecutionPolicy Bypass -File .\Install-Pyshim.ps1 -WritePath -Confirm:\$false"
   ```

- When automating, pair `-WritePath` with `-Confirm:$false` and consider `-SkipCondaRefresh` if your build agents provision Conda separately.

---

## Uninstall

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

## Update

To pick up the newest release without hunting through GitHub, run the module helper:

```powershell
Update-Pyshim
```

By default it grabs the latest release asset and reruns `Install-Pyshim.ps1` for you. Add `-WritePath` if you also want to ensure `C:\bin\shims` stays on your PATH, or `-Tag 'v0.1.1-alpha'` to pin a specific release. Supply a `GITHUB_TOKEN` environment variable (or pass `-Token`) if your network sits behind aggressive rate limiting.

---

## Auto-load in PowerShell

- Run `Enable-PyshimProfile` after importing the module to append a guarded auto-import block to your `CurrentUser` profiles. Re-run it anytime; the sentinel comments prevent duplicates.
- Pass `-Scope AllUsersAllHosts` (and run elevated) to cover background agents or shared build accounts. Add `-IncludeWindowsPowerShell` if you still launch legacy `powershell.exe` shells that need the shim.
- The cmdlet creates `.pyshim.bak` backups the first time it touches each profile unless you pass `-NoBackup`. Opening profiles with `-NoProfile` skips the block by definition.
- The inserted code simply checks for `C:\bin\shims\pyshim.psm1` and imports it with `Write-Verbose` logging when anything goes sideways, so your existing profile customizations stay in control.

### Conda Environment Helpers

- Once the module is imported you can run `Install-CondaPythons`, `Remove-CondaPythons`, or `Refresh-CondaPythons` to manage the shared `py310..py314` Conda environments. Each cmdlet accepts `-CondaPath` when auto-detection fails and honors `-WhatIf/-Confirm`.
- The scripts `Install-CondaPythons.ps1`, `Remove-CondaPythons.ps1`, and `Refresh-CondaPythons.ps1` live in `C:\bin\shims` (mirrored under `tools/` for repository workflows) and simply forward to those cmdlets.
- `Install-Pyshim.ps1` now runs `Refresh-CondaPythons -IgnoreMissing` by default; pass `-SkipCondaRefresh` to opt out during installation.

---

## Usage

### Global Interpreter

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

### Session-Only Interpreter

```powershell
Use-Python -Spec 'conda:tools'
```

This sets the interpreter for the **current shell session** only.
Background apps will still use the global default.

---

### Disable Global Persistence

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

### Per-App Overrides

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

### Per-Project Versions

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

### One-Shot Command Execution

You can also run a single command with a specific interpreter, without persistence:

```powershell
Run-WithPython -Spec 'py:3.11' -- -m pip --version
```

---

## Package Strategy

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

## Quick Test

Once installed, open PowerShell and run:

```powershell
Use-Python -Spec 'py:3.12' -Persist
python -V
pip --version
Run-WithPython -Spec 'py:3.11' -- -c "print('hello from 3.11')"
```

---

## Example Directory Layout

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

## Naming Conventions

- `python.env` — global persistent interpreter spec.
- `.python-version` — project-local interpreter spec.
- `python@AppName.env` — per-application interpreter spec.
- `python.nopersist` — disables persistence globally.
- `Uninstall-Pyshim.ps1` — local uninstaller dropped by the installer.

---

## Supported Spec Formats

| Format                  | Description                           |
| ----------------------- | ------------------------------------- |
| `py:3.12`               | Use Python 3.12 via Windows launcher. |
| `conda:myenv`           | Use Conda environment `myenv`.        |
| `C:\Path\to\python.exe` | Use this exact interpreter binary.    |

---

## Example Workflows

### Developer Switching Between Projects

```powershell
cd ~/dev/project-a
python -V  # => Python 3.12 (from .python-version)

cd ~/dev/project-b
python -V  # => Python 3.10 (different .python-version)
```

### Background Service Isolation

```powershell
Set-AppPython -App 'DataIndexer' -Spec 'conda:data'
set PYSHIM_TARGET=DataIndexer
python -m indexer.main
```

### Temporary Testing

```powershell
Run-WithPython -Spec 'py:3.9' -- -c "import sys; print(sys.version)"
```

---

## Maintainers: Building the Installers

- Run both payload generators whenever `bin/shims` changes so the script and GUI installers stay in sync:

   ```powershell
   pwsh ./tools/New-PyshimInstaller.ps1 -Force
   pwsh ./tools/New-PyshimSetupPayload.ps1 -Force
   ```

- Publish *two* installer artifacts per release:
   1. `dist/Install-Pyshim.ps1` — the unattended PowerShell installer that automation still uses.
   2. `installer/Pyshim.Setup/bin/Release/net8.0-windows/win-x64/publish/Pyshim.Setup.exe` — the WinForms GUI that end users run.

- Build the GUI installer with `dotnet publish installer/Pyshim.Setup/Pyshim.Setup.csproj -c Release -r win-x64 -p:PublishSingleFile=true --self-contained false`. The output folder already contains the manifest that forces elevation.

- GitHub Actions workflow `.github/workflows/build-installer.yml` now runs both payload generators, publishes the GUI installer, signs both artifacts, and uploads them to releases automatically.
- Store the code-signing certificate as repository secrets so the workflow can sign unattended:
   - `WINDOWS_CODESIGN_PFX` — base64-encoded `.pfx` containing the code-signing certificate + private key.
   - `WINDOWS_CODESIGN_PASSWORD` — password protecting the PFX.
   The workflow uses the local composite action `.github/actions/sign-installers` to wrap `signtool` + `Set-AuthenticodeSignature` with those inputs.

Keep contributor-only notes down here so users don’t confuse the installer generators with the installers themselves.

---

## License

MIT License
Copyright (c) 2025 ShruggieTech

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...

*(full license text included in [LICENSE](LICENSE))*

---

## Links

- [ShruggieTech](https://shruggie.tech/)
- [Latest Releases](https://github.com/shruggietech/pyshim/releases)
- [dev-handbook Integration Docs](https://github.com/shruggietech/dev-handbook)

---

## Credits

Designed and maintained by h8rt3rmin8r for **ShruggieTech LLC**.
Originally conceived as part of the internal “dev-handbook” initiative for consistent Python environments across projects.

```text
¯\_(ツ)_/¯
```
