"""Configuration management for pyshim."""

import json
import os
from pathlib import Path
from typing import Dict, Optional, List


class Config:
    """Manages pyshim configuration."""
    
    CONFIG_DIR = Path.home() / ".pyshim"
    CONFIG_FILE = CONFIG_DIR / "config.json"
    
    def __init__(self):
        """Initialize configuration."""
        self.config_dir = self.CONFIG_DIR
        self.config_file = self.CONFIG_FILE
        self._config: Dict = {}
        self._load_config()
    
    def _load_config(self):
        """Load configuration from file."""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self._config = json.load(f)
        else:
            self._config = {
                "interpreters": {},
                "default_interpreter": None,
                "search_paths": []
            }
    
    def save(self):
        """Save configuration to file."""
        self.config_dir.mkdir(parents=True, exist_ok=True)
        with open(self.config_file, 'w') as f:
            json.dump(self._config, f, indent=2)
    
    def add_interpreter(self, name: str, path: str):
        """Add a Python interpreter to the configuration.
        
        Args:
            name: Name identifier for the interpreter
            path: Full path to the Python executable
        """
        if not Path(path).exists():
            raise ValueError(f"Python interpreter not found at {path}")
        
        self._config["interpreters"][name] = str(Path(path).resolve())
        self.save()
    
    def remove_interpreter(self, name: str):
        """Remove a Python interpreter from configuration.
        
        Args:
            name: Name identifier for the interpreter
        """
        if name in self._config["interpreters"]:
            del self._config["interpreters"][name]
            self.save()
    
    def get_interpreter(self, name: str) -> Optional[str]:
        """Get path to a named interpreter.
        
        Args:
            name: Name identifier for the interpreter
            
        Returns:
            Path to the Python executable or None if not found
        """
        return self._config["interpreters"].get(name)
    
    def list_interpreters(self) -> Dict[str, str]:
        """List all registered interpreters.
        
        Returns:
            Dictionary mapping interpreter names to paths
        """
        return self._config["interpreters"].copy()
    
    def set_default_interpreter(self, name: str):
        """Set the default Python interpreter.
        
        Args:
            name: Name identifier for the interpreter
        """
        if name not in self._config["interpreters"]:
            raise ValueError(f"Interpreter '{name}' not found in configuration")
        
        self._config["default_interpreter"] = name
        self.save()
    
    def get_default_interpreter(self) -> Optional[str]:
        """Get the default Python interpreter path.
        
        Returns:
            Path to the default Python executable or None
        """
        default_name = self._config.get("default_interpreter")
        if default_name:
            return self.get_interpreter(default_name)
        return None
    
    def add_search_path(self, path: str):
        """Add a directory to search for .python-version files.
        
        Args:
            path: Directory path to add to search paths
        """
        path_str = str(Path(path).resolve())
        if path_str not in self._config["search_paths"]:
            self._config["search_paths"].append(path_str)
            self.save()
    
    def get_search_paths(self) -> List[str]:
        """Get list of search paths.
        
        Returns:
            List of directory paths to search for version files
        """
        return self._config["search_paths"].copy()
