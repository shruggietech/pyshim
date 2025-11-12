"""Context detection for determining which Python interpreter to use."""

import os
from pathlib import Path
from typing import Optional


class ContextDetector:
    """Detects context to determine appropriate Python interpreter."""
    
    def __init__(self, config):
        """Initialize context detector.
        
        Args:
            config: Config instance for accessing interpreter information
        """
        self.config = config
    
    def detect_python_version_file(self, start_dir: Optional[str] = None) -> Optional[str]:
        """Search for .python-version file in current or parent directories.
        
        Args:
            start_dir: Directory to start searching from (defaults to current directory)
            
        Returns:
            Content of .python-version file if found, None otherwise
        """
        if start_dir is None:
            start_dir = os.getcwd()
        
        current = Path(start_dir).resolve()
        
        # Search upward through directory tree
        while True:
            version_file = current / ".python-version"
            if version_file.exists():
                try:
                    return version_file.read_text().strip()
                except Exception:
                    pass
            
            # Stop at filesystem root
            parent = current.parent
            if parent == current:
                break
            current = parent
        
        return None
    
    def detect_virtual_environment(self) -> Optional[str]:
        """Detect if running in a virtual environment.
        
        Returns:
            Path to Python executable in virtual environment, None otherwise
        """
        # Check VIRTUAL_ENV environment variable
        venv_path = os.environ.get("VIRTUAL_ENV")
        if venv_path:
            # Try common paths for Python executable in venv
            for python_name in ["python.exe", "python3.exe", "python"]:
                python_path = Path(venv_path) / "Scripts" / python_name
                if python_path.exists():
                    return str(python_path)
                
                # Also check bin/ directory (for cross-platform compatibility)
                python_path = Path(venv_path) / "bin" / python_name
                if python_path.exists():
                    return str(python_path)
        
        return None
    
    def detect_pyenv_version(self) -> Optional[str]:
        """Detect pyenv version specification.
        
        Returns:
            Python version specified by pyenv, None otherwise
        """
        # Check PYENV_VERSION environment variable
        pyenv_version = os.environ.get("PYENV_VERSION")
        if pyenv_version:
            return pyenv_version
        
        # Check for .python-version file (pyenv compatible)
        return self.detect_python_version_file()
    
    def detect_project_python(self, start_dir: Optional[str] = None) -> Optional[str]:
        """Detect project-specific Python configuration.
        
        Args:
            start_dir: Directory to start searching from (defaults to current directory)
            
        Returns:
            Python interpreter name or path based on project configuration
        """
        # Check for .python-version file
        version_spec = self.detect_python_version_file(start_dir)
        if version_spec:
            # Try to find interpreter by name in config
            interpreter_path = self.config.get_interpreter(version_spec)
            if interpreter_path:
                return interpreter_path
            
            # Check if it's a direct path
            if Path(version_spec).exists():
                return version_spec
        
        return None
    
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
        # 1. Check for active virtual environment
        venv_python = self.detect_virtual_environment()
        if venv_python:
            return venv_python
        
        # 2. Check for project-specific configuration
        project_python = self.detect_project_python(start_dir)
        if project_python:
            return project_python
        
        # 3. Use default interpreter from config
        default_python = self.config.get_default_interpreter()
        if default_python:
            return default_python
        
        return None
