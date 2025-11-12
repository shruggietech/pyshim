# Windows Installation Guide

## Prerequisites

1. Windows 7 or later
2. Python 3.7+ already installed
3. Administrator access (for PATH modification)

## Installation Steps

### Step 1: Install pyshim Package

**Option A: Install from source**
```powershell
# Clone the repository
git clone https://github.com/shruggietech/pyshim.git
cd pyshim

# Install the package
pip install -e .
```

**Option B: Install from PyPI** (when published)
```powershell
pip install pyshim
```

### Step 2: Run Installation Script

```powershell
python install.py
```

This creates:
- Shim directory: `%USERPROFILE%\.pyshim\bin`
- Shim executables: `python.bat`, `pip.bat`, `py.bat`
- Configuration directory: `%USERPROFILE%\.pyshim`

### Step 3: Add to PATH

**Important**: The shim directory must be **first** in your PATH to intercept Python calls.

**Method 1: PowerShell (Recommended)**

Run PowerShell **as Administrator**:
```powershell
# Add to user PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$shimPath = "$env:USERPROFILE\.pyshim\bin"
[Environment]::SetEnvironmentVariable("Path", "$shimPath;$userPath", "User")
```

**Method 2: System Properties GUI**

1. Press `Win + X` → Select "System"
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", select "Path"
5. Click "Edit"
6. Click "New"
7. Add: `%USERPROFILE%\.pyshim\bin`
8. Click "Move Up" until it's at the top
9. Click OK on all dialogs

**Method 3: Command Prompt (as Administrator)**
```cmd
setx PATH "%USERPROFILE%\.pyshim\bin;%PATH%"
```

### Step 4: Restart Terminal

Close and reopen all terminal windows for PATH changes to take effect.

### Step 5: Verify Installation

```powershell
# Verify pyshim is accessible
pyshim --version

# Check that shim is being used
where.exe python
# Should show: C:\Users\YourName\.pyshim\bin\python.bat (first)

where.exe pip
# Should show: C:\Users\YourName\.pyshim\bin\pip.bat (first)
```

## Post-Installation Configuration

### Register Python Interpreters

```powershell
# Find your Python installations
where.exe python.exe /R C:\

# Add them to pyshim
pyshim config add python39 "C:\Python39\python.exe"
pyshim config add python311 "C:\Python311\python.exe"
pyshim config add python312 "C:\Users\YourName\AppData\Local\Programs\Python\Python312\python.exe"

# List registered interpreters
pyshim config list
```

### Set Default Interpreter

```powershell
# Set your preferred default
pyshim config default python311

# Verify
pyshim status
pyshim which
```

### Test It Works

```powershell
# Test Python
python --version

# Test pip
pip --version

# Create a test project
mkdir test-project
cd test-project
echo python39 > .python-version
python --version  # Should use Python 3.9
```

## Troubleshooting

### "pyshim is not recognized"

**Cause**: pyshim not installed or not in PATH

**Solution**:
```powershell
# Verify installation
pip show pyshim

# Re-run installation
python install.py

# Check PATH
$env:Path -split ';' | Select-String "pyshim"
```

### "python is not recognized"

**Cause**: Shims not created or PATH not updated

**Solution**:
```powershell
# Check shim directory exists
dir $env:USERPROFILE\.pyshim\bin

# Re-run install script
python install.py

# Update PATH (see Step 3)
```

### Shims not intercepting Python

**Cause**: Other Python installations earlier in PATH

**Solution**:
```powershell
# Check PATH order
where.exe python

# Should show pyshim FIRST:
# C:\Users\YourName\.pyshim\bin\python.bat
# C:\Python311\python.exe
# etc.

# If not, reorder PATH to put pyshim first
```

### "No Python interpreter configured"

**Cause**: No interpreters registered yet

**Solution**:
```powershell
# Add at least one interpreter
pyshim config add python311 "C:\Python311\python.exe"

# Set as default
pyshim config default python311
```

## Uninstallation

### Remove from PATH

**PowerShell:**
```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = ($userPath -split ';' | Where-Object { $_ -notmatch 'pyshim' }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
```

### Remove Files

```powershell
# Remove shim directory
Remove-Item -Recurse -Force "$env:USERPROFILE\.pyshim"

# Uninstall package
pip uninstall pyshim
```

## Advanced Configuration

### Custom Shim Location

Edit `install.py` before running:
```python
# Change shim directory location
shim_dir = Path("C:/custom/path/to/shims")
```

### Multiple Python Versions

```powershell
# Register all your Python versions
pyshim config add py37 "C:\Python37\python.exe"
pyshim config add py38 "C:\Python38\python.exe"
pyshim config add py39 "C:\Python39\python.exe"
pyshim config add py310 "C:\Python310\python.exe"
pyshim config add py311 "C:\Python311\python.exe"
pyshim config add py312 "C:\Python312\python.exe"

# Set latest as default
pyshim config default py312
```

### Project-Specific Setup

```powershell
# Create project
mkdir MyProject
cd MyProject

# Set Python version for this project
echo py39 > .python-version

# Create virtual environment
python -m venv venv

# Activate venv
.\venv\Scripts\activate

# pyshim will now use venv Python
python --version
```

## Automation

### Batch Script for Quick Setup

Create `setup-pyshim.bat`:
```batch
@echo off
echo Installing pyshim...
pip install pyshim
python -m pyshim.install

echo.
echo Configuring Python interpreters...
pyshim config add py39 "C:\Python39\python.exe"
pyshim config add py311 "C:\Python311\python.exe"
pyshim config default py311

echo.
echo Installation complete!
echo Please restart your terminal and run: pyshim status
pause
```

Run as administrator:
```powershell
.\setup-pyshim.bat
```
