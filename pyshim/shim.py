"""Main shim executable that intercepts Python calls."""

import os
import sys
import subprocess
from pathlib import Path
from typing import List, Optional

from .config import Config
from .context import ContextDetector


class PythonShim:
    """Main shim class that routes Python calls to appropriate interpreter."""
    
    def __init__(self):
        """Initialize the Python shim."""
        self.config = Config()
        self.context = ContextDetector(self.config)
    
    def get_interpreter(self) -> Optional[str]:
        """Determine which Python interpreter to use.
        
        Returns:
            Path to Python executable or None if not found
        """
        return self.context.resolve_interpreter()
    
    def execute(self, args: List[str]) -> int:
        """Execute Python with the resolved interpreter.
        
        Args:
            args: Command line arguments to pass to Python
            
        Returns:
            Exit code from the Python process
        """
        interpreter = self.get_interpreter()
        
        if not interpreter:
            print("pyshim: No Python interpreter configured", file=sys.stderr)
            print("Run 'pyshim config add <name> <path>' to add an interpreter", file=sys.stderr)
            return 1
        
        if not Path(interpreter).exists():
            print(f"pyshim: Python interpreter not found at {interpreter}", file=sys.stderr)
            return 1
        
        # Execute the Python interpreter with all arguments
        try:
            result = subprocess.run(
                [interpreter] + args,
                stdout=sys.stdout,
                stderr=sys.stderr,
                stdin=sys.stdin
            )
            return result.returncode
        except Exception as e:
            print(f"pyshim: Error executing Python: {e}", file=sys.stderr)
            return 1


class PipShim:
    """Shim for pip that uses the resolved Python interpreter."""
    
    def __init__(self):
        """Initialize the pip shim."""
        self.python_shim = PythonShim()
    
    def execute(self, args: List[str]) -> int:
        """Execute pip using the resolved Python interpreter.
        
        Args:
            args: Command line arguments to pass to pip
            
        Returns:
            Exit code from the pip process
        """
        interpreter = self.python_shim.get_interpreter()
        
        if not interpreter:
            print("pyshim: No Python interpreter configured", file=sys.stderr)
            return 1
        
        # Execute pip as a module with the resolved Python interpreter
        pip_args = ["-m", "pip"] + args
        return self.python_shim.execute(pip_args)


class PyShim:
    """Shim for py launcher that uses the resolved Python interpreter."""
    
    def __init__(self):
        """Initialize the py shim."""
        self.python_shim = PythonShim()
    
    def execute(self, args: List[str]) -> int:
        """Execute using the py launcher logic with resolved interpreter.
        
        Args:
            args: Command line arguments
            
        Returns:
            Exit code from the process
        """
        # For simplicity, route to the resolved Python interpreter
        # In future, could implement version selection like py launcher
        return self.python_shim.execute(args)


def main_python():
    """Main entry point for python.exe shim."""
    shim = PythonShim()
    sys.exit(shim.execute(sys.argv[1:]))


def main_pip():
    """Main entry point for pip.exe shim."""
    shim = PipShim()
    sys.exit(shim.execute(sys.argv[1:]))


def main_py():
    """Main entry point for py.exe shim."""
    shim = PyShim()
    sys.exit(shim.execute(sys.argv[1:]))
