# Architecture

## Overview

pyshim is designed as a lightweight, transparent wrapper around Python executables. It intercepts calls to `python`, `pip`, and `py` and routes them to the appropriate Python interpreter based on context.

## Components

### 1. Configuration System (`config.py`)

The `Config` class manages:
- Registered Python interpreters (name → path mapping)
- Default interpreter selection
- Search paths for `.python-version` files
- Persistent storage in `~/.pyshim/config.json`

**Key Methods:**
- `add_interpreter(name, path)`: Register a Python interpreter
- `get_interpreter(name)`: Retrieve interpreter path by name
- `set_default_interpreter(name)`: Set the default interpreter
- `get_default_interpreter()`: Get the default interpreter path

### 2. Context Detection (`context.py`)

The `ContextDetector` class determines which interpreter to use by examining:
- Virtual environment activation (`VIRTUAL_ENV` env var)
- Project-specific configuration (`.python-version` files)
- Environment variables (`PYENV_VERSION`)
- Default configuration

**Resolution Priority:**
1. Active virtual environment
2. Project `.python-version` file (searches up directory tree)
3. Configured default interpreter

**Key Methods:**
- `detect_virtual_environment()`: Check for active venv
- `detect_python_version_file(dir)`: Find `.python-version` file
- `resolve_interpreter(dir)`: Determine which interpreter to use

### 3. Shim Execution (`shim.py`)

Three shim classes handle different commands:

**PythonShim:**
- Routes `python` calls to resolved interpreter
- Passes all arguments through unchanged

**PipShim:**
- Routes `pip` calls to `python -m pip`
- Uses resolved interpreter to ensure pip operates on correct Python

**PyShim:**
- Routes `py` launcher calls to resolved interpreter
- Simplified implementation (can be extended for version selection)

**Key Methods:**
- `get_interpreter()`: Get the interpreter to use
- `execute(args)`: Run the command with resolved interpreter

### 4. Command-Line Interface (`cli.py`)

Provides user-facing commands for configuration:

**Commands:**
- `config add <name> <path>`: Add interpreter
- `config remove <name>`: Remove interpreter
- `config list`: List all interpreters
- `config default <name>`: Set default
- `which`: Show which interpreter will be used
- `status`: Show detailed status and configuration

## Data Flow

```
User runs: python script.py
     ↓
Shim intercepts call
     ↓
Context detection:
  1. Check VIRTUAL_ENV → venv python?
  2. Check .python-version → project python?
  3. Check default → config default?
     ↓
Resolve interpreter path
     ↓
subprocess.run([interpreter, "script.py"])
```

## File Locations

- **Configuration**: `~/.pyshim/config.json`
- **Shim executables**: `~/.pyshim/bin/`
- **Project config**: `.python-version` (in project directory)

## Configuration File Format

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

## Design Decisions

### Why Python-based?

- **Portability**: Easy to understand and modify
- **Cross-platform potential**: Can be adapted for Linux/macOS
- **No compilation**: Simple installation and updates
- **Rich ecosystem**: Can leverage Python libraries for future features

### Why subprocess instead of exec?

- **Error handling**: Better control over error conditions
- **I/O management**: Proper handling of stdin/stdout/stderr
- **Return codes**: Accurate propagation of exit codes

### Why search upward for .python-version?

- **Nested projects**: Supports project subdirectories
- **Monorepos**: Works with monorepo structures
- **Consistency**: Matches pyenv and other version managers

## Future Enhancements

Potential improvements:
1. **Binary executables**: Compile to native exe for faster startup
2. **Version selection**: Parse py launcher syntax (`-3.11`, `-3`)
3. **Auto-discovery**: Automatically find installed Pythons
4. **Project templates**: Quick setup for common project types
5. **Shell integration**: Tab completion for pyshim commands
6. **Caching**: Cache interpreter paths for performance
7. **Logging**: Debug mode with detailed execution logs
