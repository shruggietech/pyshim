# Usage Examples

This document provides practical examples of using pyshim in various scenarios.

## Basic Setup

### Initial Configuration

```powershell
# Install pyshim
pip install pyshim
python install.py

# Add to PATH (restart terminal after)
# See INSTALLATION.md for details

# Register your Python installations
pyshim config add py39 "C:\Python39\python.exe"
pyshim config add py311 "C:\Python311\python.exe"
pyshim config add py312 "C:\Python312\python.exe"

# Set default
pyshim config default py311

# Verify
pyshim status
```

## Scenario 1: Legacy Project (Python 3.9)

You have an old project that requires Python 3.9.

```powershell
# Navigate to your project
cd C:\Projects\legacy-app

# Set Python version for this project
echo py39 > .python-version

# Now all Python commands use 3.9
python --version
# Output: Python 3.9.x

# Install dependencies
pip install -r requirements.txt

# Run the application
python app.py
```

All subdirectories inherit this setting:

```powershell
cd C:\Projects\legacy-app\src\utils
python --version
# Still Python 3.9.x
```

## Scenario 2: Modern Project (Python 3.11)

Starting a new project with Python 3.11.

```powershell
# Create project directory
mkdir C:\Projects\modern-api
cd C:\Projects\modern-api

# Set Python version
echo py311 > .python-version

# Create virtual environment
python -m venv venv

# Activate venv
.\venv\Scripts\activate

# pyshim detects venv automatically
python --version
# Uses venv Python (based on 3.11)

# Install packages
pip install fastapi uvicorn pytest

# Work in your project
python -m pytest
python -m uvicorn main:app
```

## Scenario 3: Multiple Projects with Different Pythons

Working on several projects simultaneously.

**Project Structure:**
```
C:\Projects\
├── old-django-app\       # Python 3.9
├── flask-api\            # Python 3.11
├── ml-experiment\        # Python 3.12
└── utilities\            # Default (3.11)
```

**Setup:**

```powershell
# old-django-app (Python 3.9)
cd C:\Projects\old-django-app
echo py39 > .python-version

# flask-api (Python 3.11)
cd C:\Projects\flask-api
echo py311 > .python-version

# ml-experiment (Python 3.12)
cd C:\Projects\ml-experiment
echo py312 > .python-version

# utilities - no .python-version, uses default (3.11)
```

**Usage:**

```powershell
# Work on Django app
cd C:\Projects\old-django-app
python --version  # → 3.9.x
python manage.py runserver

# Switch to Flask API
cd C:\Projects\flask-api
python --version  # → 3.11.x
python app.py

# Work on ML project
cd C:\Projects\ml-experiment
python --version  # → 3.12.x
python train.py

# Use utilities
cd C:\Projects\utilities
python --version  # → 3.11.x (default)
```

## Scenario 4: Testing Across Python Versions

Testing library compatibility across multiple Python versions.

```powershell
# Project setup
cd C:\Projects\my-library

# Test with Python 3.9
echo py39 > .python-version
python -m venv venv39
.\venv39\Scripts\activate
pip install -e .
pytest
deactivate

# Test with Python 3.11
echo py311 > .python-version
python -m venv venv311
.\venv311\Scripts\activate
pip install -e .
pytest
deactivate

# Test with Python 3.12
echo py312 > .python-version
python -m venv venv312
.\venv312\Scripts\activate
pip install -e .
pytest
deactivate
```

## Scenario 5: Team Collaboration

Ensuring all team members use the same Python version.

**Repository Setup:**

```powershell
# In your project root
echo py311 > .python-version

# Add to git
git add .python-version
git commit -m "Specify Python 3.11 for this project"
git push
```

**Team Member Setup:**

```powershell
# Team member clones the repo
git clone https://github.com/company/project.git
cd project

# pyshim automatically detects .python-version
python --version
# → Python 3.11.x (if they have py311 configured)

# If they don't have 3.11:
pyshim which
# → Shows error or different version

# They need to install and configure 3.11
pyshim config add py311 "C:\Python311\python.exe"

# Now it works
python --version
# → Python 3.11.x
```

## Scenario 6: Global vs. Local Python

Different Python for system tasks vs. projects.

```powershell
# Set system default to Python 3.11
pyshim config default py311

# System-wide scripts use 3.11
cd C:\
python --version  # → 3.11.x

# But specific project uses 3.9
cd C:\Projects\legacy-app
python --version  # → 3.9.x (from .python-version)

# Another project uses 3.12
cd C:\Projects\experimental
python --version  # → 3.12.x (from .python-version)

# Back to system default
cd C:\
python --version  # → 3.11.x
```

## Scenario 7: Data Science Workflow

Using different Python versions for different experiments.

```powershell
# Main data science directory
cd C:\DataScience

# Experiment 1: Classic ML with stable Python
mkdir experiment1
cd experiment1
echo py311 > .python-version
python -m venv venv
.\venv\Scripts\activate
pip install pandas scikit-learn matplotlib
python train_model.py

# Experiment 2: Cutting-edge with latest Python
cd ..
mkdir experiment2
cd experiment2
echo py312 > .python-version
python -m venv venv
.\venv\Scripts\activate
pip install torch transformers
python train_transformer.py

# Experiment 3: Legacy code with old Python
cd ..
mkdir experiment3
cd experiment3
echo py39 > .python-version
python -m venv venv
.\venv\Scripts\activate
pip install tensorflow==2.4.0
python legacy_analysis.py
```

## Scenario 8: CI/CD Integration

Using pyshim in automated builds.

**GitHub Actions Example:**

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      
      - name: Install pyshim
        run: |
          pip install pyshim
          python install.py
          
      - name: Configure Python
        run: |
          pyshim config add py311 "$(which python)"
          pyshim config default py311
          
      - name: Verify Python version
        run: |
          pyshim which
          python --version
          
      - name: Install dependencies
        run: pip install -r requirements.txt
        
      - name: Run tests
        run: pytest
```

## Scenario 9: Virtual Environment Management

Working with multiple virtual environments.

```powershell
# Project with multiple environments
cd C:\Projects\web-app

# Development environment (latest Python)
echo py312 > .python-version
python -m venv venv-dev
.\venv-dev\Scripts\activate
pip install -r requirements-dev.txt
python manage.py runserver
deactivate

# Production environment (stable Python)
echo py311 > .python-version
python -m venv venv-prod
.\venv-prod\Scripts\activate
pip install -r requirements.txt
python manage.py check --deploy
deactivate

# Testing environment
echo py311 > .python-version
python -m venv venv-test
.\venv-test\Scripts\activate
pip install pytest pytest-cov
pytest --cov
deactivate
```

## Scenario 10: Migrating Between Python Versions

Gradually migrating a project from Python 3.9 to 3.11.

```powershell
cd C:\Projects\migration-project

# Start with Python 3.9
echo py39 > .python-version
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt

# Run tests with 3.9
pytest
# All pass ✓

# Try with 3.11
deactivate
echo py311 > .python-version
python -m venv venv311
.\venv311\Scripts\activate
pip install -r requirements.txt

# Run tests with 3.11
pytest
# Some fail - need to fix

# Fix compatibility issues
# ... edit code ...

# Test again
pytest
# All pass ✓

# Commit the change
git add .python-version
git commit -m "Migrate to Python 3.11"
```

## Troubleshooting Examples

### Example: Wrong Python Version

```powershell
# Check what's being used
pyshim which
# → C:\Python39\python.exe

# Check for .python-version files
cd C:\Projects\myapp
dir /s /b .python-version
# → C:\Projects\myapp\.python-version

# Check its content
type .python-version
# → py39

# Change to use Python 3.11
echo py311 > .python-version

# Verify
pyshim which
# → C:\Python311\python.exe
```

### Example: Environment Conflicts

```powershell
# Check status
pyshim status
# Shows:
#   Current interpreter: C:\Projects\old-venv\Scripts\python.exe
#   Virtual environment: C:\Projects\old-venv\Scripts\python.exe
#   .python-version found: py311

# Deactivate old venv
deactivate

# Create new venv with correct Python
python -m venv venv
.\venv\Scripts\activate

# Now using correct Python
pyshim status
# Shows:
#   Current interpreter: C:\Projects\myapp\venv\Scripts\python.exe
```

## Best Practices

### 1. Always Specify Version in Projects

```powershell
# Good: Every project has .python-version
C:\Projects\app1\.python-version  # → py311
C:\Projects\app2\.python-version  # → py39
C:\Projects\lib1\.python-version  # → py311
```

### 2. Commit .python-version to Git

```powershell
git add .python-version
git commit -m "Specify Python version"
```

### 3. Document Required Python in README

```markdown
# My Project

Requires Python 3.11. A `.python-version` file is included.

If using pyshim:
- Configure Python 3.11: `pyshim config add py311 "path/to/python311"`
- Navigate to project: `cd my-project`
- Python 3.11 will be used automatically
```

### 4. Use Virtual Environments

```powershell
# Always create venv after setting .python-version
echo py311 > .python-version
python -m venv venv
.\venv\Scripts\activate
```

### 5. Verify Configuration

```powershell
# Before starting work
pyshim status
python --version
pip --version
```
