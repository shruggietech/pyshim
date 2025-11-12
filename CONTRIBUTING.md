# Contributing to pyshim

Thank you for your interest in contributing to pyshim! This document provides guidelines and instructions for contributing.

## Getting Started

### Prerequisites

- Python 3.7 or higher
- Git
- Windows (for testing Windows-specific features)

### Setting Up Development Environment

1. **Fork and clone the repository**

```bash
git clone https://github.com/YOUR_USERNAME/pyshim.git
cd pyshim
```

2. **Create a virtual environment**

```bash
python -m venv venv
venv\Scripts\activate  # Windows
```

3. **Install in development mode**

```bash
pip install -e .
```

4. **Install development dependencies**

```bash
pip install pytest pytest-cov black flake8 mypy
```

## Development Workflow

### Running Tests

```bash
# Run all tests
python -m unittest discover tests

# Run specific test file
python -m unittest tests.test_config

# Run with coverage
coverage run -m unittest discover tests
coverage report
coverage html  # Generate HTML report
```

### Code Style

We follow PEP 8 style guidelines.

**Format code with black:**
```bash
black pyshim tests
```

**Check style with flake8:**
```bash
flake8 pyshim tests --max-line-length=100
```

**Type checking with mypy:**
```bash
mypy pyshim
```

### Making Changes

1. **Create a feature branch**

```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes**

- Write clear, concise code
- Follow existing code style
- Add docstrings to functions and classes
- Update tests as needed

3. **Write tests**

All new features should include tests:

```python
# tests/test_your_feature.py
import unittest
from pyshim.your_module import YourClass

class TestYourFeature(unittest.TestCase):
    def test_something(self):
        # Test your feature
        self.assertEqual(expected, actual)
```

4. **Run tests**

```bash
python -m unittest discover tests
```

5. **Commit your changes**

```bash
git add .
git commit -m "Add feature: brief description"
```

Use clear commit messages:
- `Add feature: ...`
- `Fix bug: ...`
- `Update docs: ...`
- `Refactor: ...`

6. **Push and create pull request**

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## Types of Contributions

### Bug Reports

**Before submitting:**
- Check if the bug is already reported in Issues
- Verify it's actually a bug (not expected behavior)
- Test with the latest version

**When submitting:**
- Use a clear, descriptive title
- Describe expected vs. actual behavior
- Provide steps to reproduce
- Include system information (Windows version, Python version)
- Include relevant logs or error messages

**Template:**
```markdown
**Description**
Brief description of the bug

**Steps to Reproduce**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- OS: Windows 10/11
- Python: 3.11.0
- pyshim: 0.1.0

**Additional Context**
Any other relevant information
```

### Feature Requests

**Before submitting:**
- Check if the feature is already requested
- Consider if it fits pyshim's scope
- Think about implementation approach

**When submitting:**
- Describe the problem it solves
- Explain the proposed solution
- Provide use cases
- Consider alternatives

**Template:**
```markdown
**Problem**
What problem does this solve?

**Proposed Solution**
How should it work?

**Use Cases**
When would this be useful?

**Alternatives**
What other approaches were considered?
```

### Documentation

Documentation improvements are always welcome!

**Areas to contribute:**
- README improvements
- Additional examples
- FAQ entries
- API documentation
- Installation guides
- Tutorials

**Guidelines:**
- Use clear, simple language
- Provide working examples
- Test all commands/code
- Follow existing formatting

### Code Contributions

**Good first issues:**
- Adding more test coverage
- Improving error messages
- Adding type hints
- Refactoring for clarity

**Larger features:**
- Discuss in an issue first
- Break into smaller PRs if possible
- Update documentation
- Add comprehensive tests

## Pull Request Guidelines

### Before Submitting

- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with main

### PR Description

Include:
- What the PR does
- Why the change is needed
- How to test the changes
- Related issues (if any)

**Template:**
```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
How to test these changes

## Related Issues
Closes #123
```

### Review Process

1. Maintainers will review your PR
2. Address any feedback
3. Once approved, it will be merged
4. Your contribution will be included in the next release!

## Code Architecture

### Project Structure

```
pyshim/
├── pyshim/
│   ├── __init__.py      # Package metadata
│   ├── config.py        # Configuration management
│   ├── context.py       # Context detection
│   ├── shim.py          # Main shim logic
│   ├── cli.py           # Command-line interface
│   └── templates/       # Batch file templates
├── tests/
│   ├── test_config.py
│   ├── test_context.py
│   └── test_shim.py
├── docs/                # Documentation
└── install.py           # Installation script
```

### Key Components

**Config (`config.py`):**
- Manages configuration file
- Stores interpreter mappings
- Handles defaults

**Context (`context.py`):**
- Detects virtual environments
- Searches for .python-version files
- Resolves interpreter priority

**Shim (`shim.py`):**
- Main entry points
- Executes resolved Python
- Handles pip and py commands

**CLI (`cli.py`):**
- User-facing commands
- Configuration management
- Status reporting

## Testing Guidelines

### Test Organization

- One test file per module
- Group related tests in classes
- Use descriptive test names

### Test Coverage

Aim for >80% coverage:

```bash
coverage run -m unittest discover tests
coverage report
```

### Test Best Practices

```python
# Good: Descriptive name, clear assertion
def test_add_interpreter_stores_correct_path(self):
    self.config.add_interpreter("py39", "/path/to/python.exe")
    self.assertEqual(self.config.get_interpreter("py39"), "/path/to/python.exe")

# Good: Test edge cases
def test_add_interpreter_with_nonexistent_path_raises_error(self):
    with self.assertRaises(ValueError):
        self.config.add_interpreter("fake", "/nonexistent/python.exe")

# Good: Clean setup and teardown
def setUp(self):
    self.temp_dir = tempfile.mkdtemp()
    # Setup test fixtures

def tearDown(self):
    shutil.rmtree(self.temp_dir, ignore_errors=True)
```

## Documentation Guidelines

### Docstrings

Use Google-style docstrings:

```python
def resolve_interpreter(self, start_dir: Optional[str] = None) -> Optional[str]:
    """Resolve which Python interpreter to use based on context.
    
    Priority order:
    1. Active virtual environment
    2. Project-specific configuration (.python-version)
    3. Default interpreter from config
    
    Args:
        start_dir: Directory to start context search from
        
    Returns:
        Path to Python executable to use, None if no interpreter found
    """
```

### README Updates

When adding features:
- Update README.md
- Add examples
- Update feature list

### Creating Examples

Provide working, tested examples:

```markdown
### Example: Using Project-Specific Python

\`\`\`powershell
cd C:\Projects\myproject
echo py311 > .python-version
python --version  # Uses Python 3.11
\`\`\`
```

## Communication

### Where to Ask Questions

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, ideas
- **Pull Request Comments**: Code-specific questions

### Being Respectful

- Be kind and respectful
- Assume good intentions
- Provide constructive feedback
- Help others learn

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Credited in release notes
- Thanked in pull request comments

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing:
1. Check existing documentation
2. Search closed issues
3. Open a new discussion
4. Ask in your pull request

Thank you for contributing to pyshim! 🎉
