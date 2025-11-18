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

## Install (Recommended)

1. **Install the Windows Python Launcher** (if you do not already have `py.exe`):
   - Download any modern Python from [python.org](https://www.python.org/downloads/).
   - During setup, tick **"Install launcher for all users (recommended)"**.

2. **Download the latest release** from [github.com/shruggietech/pyshim/releases](https://github.com/shruggietech/pyshim/releases):
   - Grab `Install-Pyshim.ps1` (required).
   - (Optional) Grab `Install-CondaPythons.ps1` if you want prebuilt Conda envs `py310`–`py314`.

3. **Run the installer** in an elevated PowerShell window (writes to `C:\bin\shims`):

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Install-Pyshim.ps1 -WritePath
   ```

   The script copies the shims to `C:\bin\shims` and adds that directory to your user PATH when it is missing. Skip `-WritePath` if you prefer to be prompted.

4. **(Optional) Provision Conda environments** after the main installer finishes:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Install-CondaPythons.ps1
   ```

   Supply `-ForceRecreate` to rebuild existing envs or `-CondaPath` if `conda.exe` lives elsewhere.

5. **Load the module in PowerShell** (add this to your profile for persistence):

   ```powershell
   Import-Module 'C:\bin\shims\pyshim.psm1'
   ```

   Restart any open terminals afterward so they pick up the PATH change.

### Manual install (advanced)

You can still do things the hard way if you want complete manual control:

1. Create `C:\bin\shims` yourself.
2. Copy `python.bat`, `pip.bat`, `pythonw.bat`, `pyshim.psm1`, and `Uninstall-Pyshim.ps1` into that folder.
3. Put `C:\bin\shims` at the front of your user PATH.
4. Import the module from your PowerShell profile.

The single-file installer automates all of these steps, so prefer it for real machines.

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

If you added `Import-Module 'C:\bin\shims\pyshim.psm1'` to your PowerShell profile, remove that line manually. After the script runs, restart your shells to pick up the cleaned PATH.

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
└── bin\
    └── shims\
        ├── python.bat
        ├── pip.bat
        ├── pythonw.bat
        ├── pyshim.psm1
      ├── Uninstall-Pyshim.ps1
      ├── python.env
      ├── python@MyService.env
      └── python.nopersist
```

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

## Maintainers: Building the Installer

- Run `pwsh ./tools/New-PyshimInstaller.ps1` whenever the shims change. This regenerates `dist/Install-Pyshim.ps1` with the latest batch files, module, and the bundled `Uninstall-Pyshim.ps1`.
- Publish `dist/Install-Pyshim.ps1` (and optionally `tools/Install-CondaPythons.ps1`) as release assets so end users can install without cloning the repo.
- The GitHub workflow `.github/workflows/build-installer.yml` does this automatically when triggered manually or when a release is published. The artifact named `pyshim-tools` includes both scripts.

Keep contributor-only notes down here so users don’t confuse the installer generator with the installer itself.

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
