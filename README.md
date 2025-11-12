# pyshim

A deterministic, context-aware Python shim for Windows that lets you control which Python interpreter is used by apps, projects, and background tools (without breaking the global environment).

## What is pyshim?

pyshim is a lightweight command router that sits in front of `python.exe`, `pip.exe`, and `py.exe`. It intercepts all calls to these commands and dynamically decides which Python interpreter to run based on context and configuration.

## Features

- **Context-Aware**: Automatically selects the right Python interpreter based on:
  - Active virtual environments
  - Project-specific `.python-version` files
  - Configured default interpreter
  
- **Deterministic**: Clear, predictable priority order for interpreter selection
  
- **Non-Invasive**: Works alongside existing Python installations without modification
  
- **Easy Configuration**: Simple CLI for managing Python interpreters

## Installation

### Prerequisites

- Windows operating system
- Python 3.7 or higher already installed

### Install from source

```bash
# Clone the repository
git clone https://github.com/shruggietech/pyshim.git
cd pyshim

# Install the package
pip install -e .

# Run the installation script
python install.py
```

The installation script will:
1. Create a shim directory at `~/.pyshim/bin`
2. Install shim executables for `python`, `pip`, and `py`
3. Provide instructions for adding the shim directory to your PATH

### Add to PATH

After installation, add `%USERPROFILE%\.pyshim\bin` to your PATH environment variable:

**Using PowerShell (as Administrator):**
```powershell
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$env:USERPROFILE\.pyshim\bin", "User")
```

**Using System Properties:**
1. Press Win+X and select "System"
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", select "Path" and click "Edit"
5. Add: `%USERPROFILE%\.pyshim\bin`
6. Click OK to save

**Important**: Restart your terminal/command prompt after updating PATH.

## Quick Start

### 1. Register Python Interpreters

```bash
# Add your installed Python interpreters
pyshim config add python39 "C:\Python39\python.exe"
pyshim config add python311 "C:\Python311\python.exe"
pyshim config add python312 "C:\Users\YourName\AppData\Local\Programs\Python\Python312\python.exe"

# List registered interpreters
pyshim config list
```

### 2. Set a Default Interpreter

```bash
# Set Python 3.11 as your default
pyshim config default python311

# Verify configuration
pyshim status
```

### 3. Use Project-Specific Python Versions

Create a `.python-version` file in your project directory:

```bash
cd my-project
echo python39 > .python-version
```

Now when you run `python` from within that project directory, pyshim will use Python 3.9.

## Usage

### Configuration Commands

```bash
# Add a Python interpreter
pyshim config add <name> <path>

# Remove an interpreter
pyshim config remove <name>

# List all configured interpreters
pyshim config list

# Set default interpreter
pyshim config default <name>
```

### Status and Information

```bash
# Show which interpreter will be used
pyshim which

# Show detailed status
pyshim status
```

### Running Python

Once configured, simply use `python`, `pip`, and `py` as normal:

```bash
# These commands will use the resolved interpreter
python --version
python script.py
pip install requests
py -3 script.py
```

## How It Works

### Priority Order

pyshim resolves which Python interpreter to use with the following priority:

1. **Active Virtual Environment** - If `VIRTUAL_ENV` is set, use that Python
2. **Project Configuration** - Look for `.python-version` file in current directory or parents
3. **Default Interpreter** - Use the configured default interpreter

### Context Detection

- **Virtual Environments**: Detects the `VIRTUAL_ENV` environment variable
- **Project Files**: Searches for `.python-version` files from the current directory up to the filesystem root
- **Default Fallback**: Uses the configured default interpreter

### .python-version File

The `.python-version` file can contain:
- A registered interpreter name: `python311`
- A direct path to Python: `C:\Python311\python.exe`

Example:
```
# .python-version
python39
```

## Configuration File

Configuration is stored in `~/.pyshim/config.json`:

```json
{
  "interpreters": {
    "python39": "C:\\Python39\\python.exe",
    "python311": "C:\\Python311\\python.exe"
  },
  "default_interpreter": "python311",
  "search_paths": []
}
```

## Examples

### Example 1: Project with Specific Python Version

```bash
# Create a project
mkdir my-app
cd my-app

# Specify Python version for this project
echo python39 > .python-version

# This will use Python 3.9
python --version
pip install flask
```

### Example 2: Using Virtual Environments

```bash
# Create virtual environment with project Python
python -m venv venv

# Activate it
venv\Scripts\activate

# Now pyshim detects the venv and uses it
python --version  # Uses venv Python
pip install requests  # Installs to venv
```

### Example 3: Multiple Projects

```bash
# Project A uses Python 3.9
cd project-a
echo python39 > .python-version
python --version  # → Python 3.9

# Project B uses Python 3.11
cd ../project-b
echo python311 > .python-version
python --version  # → Python 3.11

# Project C uses default
cd ../project-c
# (no .python-version file)
python --version  # → Default (Python 3.11)
```

## Troubleshooting

### pyshim command not found

- Ensure `~/.pyshim/bin` is in your PATH
- Restart your terminal after updating PATH
- Verify installation: `where pyshim` (should show path in `.pyshim\bin`)

### No Python interpreter configured

```bash
# Check configuration
pyshim config list

# Add interpreters
pyshim config add python311 "C:\Python311\python.exe"
pyshim config default python311
```

### Wrong Python version being used

```bash
# Check which interpreter will be used
pyshim which

# Check for .python-version files
cd /d %cd%
dir /s /b .python-version

# Verify configuration
pyshim status
```

### Shim not intercepting Python calls

- Ensure `.pyshim\bin` is at the beginning of your PATH (higher priority than other Python installations)
- Restart your terminal
- Check for conflicts: `where python` should show pyshim first

## Development

### Running Tests

```bash
# Run all tests
python -m unittest discover tests

# Run specific test file
python -m unittest tests.test_config

# Run with coverage
pip install coverage
coverage run -m unittest discover tests
coverage report
```

### Project Structure

```
pyshim/
├── pyshim/
│   ├── __init__.py      # Package initialization
│   ├── config.py        # Configuration management
│   ├── context.py       # Context detection
│   ├── shim.py          # Main shim execution
│   └── cli.py           # Command-line interface
├── tests/
│   ├── test_config.py   # Configuration tests
│   ├── test_context.py  # Context detection tests
│   └── test_shim.py     # Shim execution tests
├── install.py           # Installation script
├── pyproject.toml       # Package configuration
└── README.md           # This file
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Inspired by:
- [pyenv](https://github.com/pyenv/pyenv) - Python version management
- [rbenv](https://github.com/rbenv/rbenv) - Ruby version management
- Windows py launcher - Built-in Python launcher for Windows
