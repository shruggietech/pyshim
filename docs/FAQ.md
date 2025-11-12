# Frequently Asked Questions (FAQ)

## General Questions

### What is pyshim?

pyshim is a lightweight command router for Windows that intercepts calls to `python`, `pip`, and `py` commands and routes them to the appropriate Python interpreter based on context (virtual environments, project configuration, or defaults).

### Why do I need pyshim?

Without pyshim:
- You manually switch between Python versions
- Different projects may use the wrong Python accidentally
- System-wide Python can conflict with project needs
- Virtual environments might not be activated consistently

With pyshim:
- Automatic Python version selection per project
- No manual switching needed
- Projects are isolated and deterministic
- Works seamlessly with virtual environments

### How is pyshim different from pyenv?

**pyshim:**
- Windows-focused
- Lightweight Python-based implementation
- Simple configuration via JSON
- Works with existing Python installations
- No compilation required

**pyenv:**
- Unix/Linux/macOS focused (pyenv-win for Windows)
- Can download and build Python versions
- More complex, feature-rich
- Requires more setup

pyshim is simpler and focused specifically on routing to existing Python installations.

### How is pyshim different from the Windows py launcher?

**Windows py launcher (`py.exe`):**
- Selects Python based on shebang lines (`#!/usr/bin/env python3.11`)
- Global Python version selection
- Limited project-specific configuration

**pyshim:**
- Context-aware (virtual environments, `.python-version` files)
- Project-specific configuration via `.python-version`
- Consistent interface for `python`, `pip`, and `py`
- Clear priority order

## Installation Questions

### Do I need administrator rights to install pyshim?

No for the pyshim package itself. However:
- Installing with `pip` may need admin if installing system-wide
- Modifying PATH in system settings needs admin
- User PATH modification doesn't need admin (recommended)

Install to user directory and modify user PATH only.

### Can I install pyshim alongside existing Python installations?

Yes! pyshim doesn't modify your Python installations. It sits in front of them in your PATH and routes commands to the appropriate interpreter.

### Where should pyshim be in my PATH?

pyshim's bin directory (`%USERPROFILE%\.pyshim\bin`) should be **first** in your PATH, before any Python installations. This ensures pyshim intercepts Python commands.

```
✓ Good PATH order:
C:\Users\You\.pyshim\bin
C:\Python311
C:\Python39

✗ Bad PATH order:
C:\Python311
C:\Users\You\.pyshim\bin
```

### Does pyshim work with Anaconda/Miniconda?

Yes, you can register conda environments as interpreters:

```powershell
pyshim config add conda-base "C:\Anaconda3\python.exe"
pyshim config add conda-tf "C:\Anaconda3\envs\tensorflow\python.exe"
```

However, conda's own activation mechanism is more appropriate for conda environments.

## Configuration Questions

### Where is pyshim's configuration stored?

Configuration is stored in `%USERPROFILE%\.pyshim\config.json`

You can view it:
```powershell
type %USERPROFILE%\.pyshim\config.json
```

### Can I manually edit the configuration file?

Yes, but use the CLI commands when possible:

```powershell
# Safer (validates)
pyshim config add py311 "C:\Python311\python.exe"

# Manual editing (no validation)
notepad %USERPROFILE%\.pyshim\config.json
```

### How do I backup my configuration?

```powershell
# Backup
copy %USERPROFILE%\.pyshim\config.json %USERPROFILE%\.pyshim\config.json.backup

# Restore
copy %USERPROFILE%\.pyshim\config.json.backup %USERPROFILE%\.pyshim\config.json
```

### Can I have different configurations for different users?

Yes! Each Windows user has their own `%USERPROFILE%\.pyshim\config.json`.

## Usage Questions

### How do I use a specific Python version for a project?

Create a `.python-version` file in your project:

```powershell
cd C:\Projects\myproject
echo py311 > .python-version
```

Now `python` commands in that directory use Python 3.11.

### Can I use absolute paths in .python-version?

Yes! Both work:

```
# Named interpreter
py311

# Direct path
C:\Python311\python.exe
```

### What happens if the Python in .python-version isn't configured?

pyshim will try to use it if it's a valid path. If it's a name that's not configured, it falls back to the default interpreter.

```powershell
# Check which interpreter will be used
pyshim which

# Check status
pyshim status
```

### Do subdirectories inherit .python-version?

Yes! pyshim searches up the directory tree:

```
C:\Projects\myapp\.python-version  (py311)
C:\Projects\myapp\src\             (uses py311)
C:\Projects\myapp\src\utils\       (uses py311)
C:\Projects\myapp\tests\           (uses py311)
```

### How do I override .python-version temporarily?

Activate a virtual environment:

```powershell
# Project specifies py311
python --version  # 3.11.x

# Create and activate venv with py39
echo py39 > .python-version-temp
python -m venv venv39
.\venv39\Scripts\activate

# Now using venv (based on py39)
python --version  # 3.9.x from venv
```

Virtual environments have highest priority.

### Can I use pyshim with Docker?

You can use pyshim in Docker containers, but it's usually unnecessary since Docker containers typically have a single Python version.

If needed:
```dockerfile
FROM python:3.11-windowsservercore

RUN pip install pyshim
RUN python -m pyshim.install
# ... configure pyshim
```

## Troubleshooting Questions

### pyshim command not found

**Cause**: pyshim not in PATH or not installed

**Fix**:
```powershell
# Check installation
pip show pyshim

# Reinstall if needed
pip install --force-reinstall pyshim

# Check PATH
echo %PATH% | findstr pyshim

# Add to PATH
setx PATH "%USERPROFILE%\.pyshim\bin;%PATH%"

# Restart terminal
```

### Python still using wrong version

**Cause**: PATH order or missing .python-version

**Fix**:
```powershell
# Check which python is first
where python
# Should show: C:\Users\You\.pyshim\bin\python.bat

# Check pyshim's choice
pyshim which

# Check for .python-version
dir /s /b .python-version

# Set version
echo py311 > .python-version
```

### "No Python interpreter configured" error

**Cause**: No default interpreter set

**Fix**:
```powershell
# Add at least one interpreter
pyshim config add py311 "C:\Python311\python.exe"

# Set as default
pyshim config default py311

# Verify
pyshim status
```

### Shims not working after installation

**Cause**: Terminal not restarted or PATH not updated

**Fix**:
1. Close all terminal windows
2. Open new terminal
3. Test: `where python` should show pyshim first
4. If not, check PATH was updated correctly

### Virtual environment not detected

**Cause**: `VIRTUAL_ENV` environment variable not set

**Fix**:
```powershell
# Check if activated
echo %VIRTUAL_ENV%

# Should show venv path when activated
.\venv\Scripts\activate

# Verify
echo %VIRTUAL_ENV%
pyshim status
```

### Cannot find Python executable at configured path

**Cause**: Python moved or uninstalled

**Fix**:
```powershell
# Find Python installations
where /R C:\ python.exe

# Update configuration
pyshim config remove old-python
pyshim config add py311 "C:\New\Path\python.exe"
```

## Advanced Questions

### Can I use pyshim with tox?

Yes! tox creates its own virtual environments:

```ini
# tox.ini
[tox]
envlist = py39,py311,py312

[testenv]
deps = pytest
commands = pytest
```

```powershell
# pyshim routes to correct Python for creating envs
tox
```

### Can I use pyshim in scripts?

Yes, scripts that call `python` will use pyshim:

```batch
REM script.bat
@echo off
cd C:\Projects\myapp
python script.py
```

The script will use the Python specified in `C:\Projects\myapp\.python-version`.

### Can I disable pyshim temporarily?

Yes, call Python directly:

```powershell
# Using pyshim (respects .python-version)
python script.py

# Bypassing pyshim
C:\Python311\python.exe script.py
```

Or remove pyshim from PATH temporarily:

```powershell
# Current session only
$env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notmatch 'pyshim' }) -join ';'
```

### How can I contribute to pyshim?

See the project repository:
- Report issues: GitHub Issues
- Submit pull requests: Fork and PR
- Suggest features: GitHub Discussions

### Is pyshim production-ready?

pyshim is suitable for:
- ✓ Development environments
- ✓ Personal projects
- ✓ Team development
- ✓ CI/CD pipelines

Use with caution for:
- ⚠ Production servers (simpler to use one Python version)
- ⚠ Critical systems (test thoroughly first)

### How do I uninstall pyshim?

```powershell
# Remove from PATH
# (via System Properties or PowerShell - see INSTALLATION.md)

# Uninstall package
pip uninstall pyshim

# Remove configuration
rmdir /s %USERPROFILE%\.pyshim

# Verify
where python
# Should show original Python installations
```

### Does pyshim affect performance?

Minimal impact:
- Startup overhead: ~50-100ms (Python import + config read)
- Runtime: Zero (once Python starts, it runs normally)

For most use cases, this is negligible. For very short-running scripts that run thousands of times, you might notice slight overhead.

### Can I use pyshim with PyCharm/VSCode?

**PyCharm:**
Configure interpreter directly in project settings. PyCharm has its own interpreter management.

**VSCode:**
VSCode's Python extension works with pyshim. Set up:
1. Let pyshim resolve the interpreter
2. Or configure VSCode to use specific Python path

pyshim is most useful for terminal/command-line usage.

### Does pyshim work with GitHub Actions/CI?

Yes! Example:

```yaml
- name: Install pyshim
  run: |
    pip install pyshim
    python install.py
    
- name: Configure
  run: |
    pyshim config add py311 "$(which python)"
    
- name: Use
  run: python script.py  # Uses pyshim
```

### Can multiple users share a pyshim configuration?

Each user has their own configuration in `%USERPROFILE%\.pyshim\`.

For shared configuration:
1. Create a template `config.json`
2. Copy to each user's `.pyshim` directory
3. Or create a setup script that configures pyshim for all users

### What Python versions does pyshim support?

pyshim itself requires Python 3.7+.

It can manage any Python version (2.7, 3.x, etc.) as long as the interpreter executable exists.

### Is there a Linux/macOS version?

Currently pyshim is Windows-only. The architecture is designed to be portable, so Linux/macOS versions are possible future enhancements.

For now, Linux/macOS users should use:
- pyenv
- asdf
- Built-in version managers
