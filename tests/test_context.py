"""Tests for context detection."""

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from pyshim.config import Config
from pyshim.context import ContextDetector


class TestContextDetector(unittest.TestCase):
    """Test cases for ContextDetector class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_dir = Path(self.temp_dir) / ".pyshim"
        self.config_file = self.config_dir / "config.json"
        
        # Override config paths for testing
        Config.CONFIG_DIR = self.config_dir
        Config.CONFIG_FILE = self.config_file
        
        self.config = Config()
        self.detector = ContextDetector(self.config)
    
    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_detect_python_version_file_in_current_dir(self):
        """Test detecting .python-version in current directory."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        version_file = test_dir / ".python-version"
        version_file.write_text("3.11")
        
        result = self.detector.detect_python_version_file(str(test_dir))
        self.assertEqual(result, "3.11")
    
    def test_detect_python_version_file_in_parent_dir(self):
        """Test detecting .python-version in parent directory."""
        parent_dir = Path(self.temp_dir) / "parent"
        child_dir = parent_dir / "child" / "grandchild"
        child_dir.mkdir(parents=True)
        
        version_file = parent_dir / ".python-version"
        version_file.write_text("3.10")
        
        result = self.detector.detect_python_version_file(str(child_dir))
        self.assertEqual(result, "3.10")
    
    def test_detect_python_version_file_not_found(self):
        """Test when no .python-version file is found."""
        test_dir = Path(self.temp_dir) / "empty"
        test_dir.mkdir()
        
        result = self.detector.detect_python_version_file(str(test_dir))
        self.assertIsNone(result)
    
    @patch.dict(os.environ, {"VIRTUAL_ENV": ""})
    def test_detect_virtual_environment_with_env_var(self):
        """Test detecting virtual environment via VIRTUAL_ENV."""
        venv_dir = Path(self.temp_dir) / "venv"
        scripts_dir = venv_dir / "Scripts"
        scripts_dir.mkdir(parents=True)
        
        python_exe = scripts_dir / "python.exe"
        python_exe.touch()
        
        with patch.dict(os.environ, {"VIRTUAL_ENV": str(venv_dir)}):
            result = self.detector.detect_virtual_environment()
            self.assertEqual(result, str(python_exe))
    
    @patch.dict(os.environ, {}, clear=True)
    def test_detect_virtual_environment_not_active(self):
        """Test when no virtual environment is active."""
        result = self.detector.detect_virtual_environment()
        self.assertIsNone(result)
    
    @patch.dict(os.environ, {"PYENV_VERSION": "3.11.0"})
    def test_detect_pyenv_version_from_env(self):
        """Test detecting pyenv version from environment variable."""
        result = self.detector.detect_pyenv_version()
        self.assertEqual(result, "3.11.0")
    
    def test_detect_project_python_with_version_file(self):
        """Test detecting project Python from .python-version file."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        python_path = Path(self.temp_dir) / "python311.exe"
        python_path.touch()
        
        # Add interpreter to config
        self.config.add_interpreter("3.11", str(python_path))
        
        # Create .python-version file
        version_file = test_dir / ".python-version"
        version_file.write_text("3.11")
        
        result = self.detector.detect_project_python(str(test_dir))
        self.assertEqual(result, str(python_path.resolve()))
    
    def test_detect_project_python_with_direct_path(self):
        """Test detecting project Python with direct path in version file."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        python_path = Path(self.temp_dir) / "custom" / "python.exe"
        python_path.parent.mkdir(parents=True)
        python_path.touch()
        
        # Create .python-version file with direct path
        version_file = test_dir / ".python-version"
        version_file.write_text(str(python_path))
        
        result = self.detector.detect_project_python(str(test_dir))
        self.assertEqual(result, str(python_path))
    
    def test_resolve_interpreter_priority_venv(self):
        """Test that virtual environment has highest priority."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        # Set up virtual environment
        venv_dir = test_dir / "venv"
        scripts_dir = venv_dir / "Scripts"
        scripts_dir.mkdir(parents=True)
        venv_python = scripts_dir / "python.exe"
        venv_python.touch()
        
        # Set up project Python
        project_python = Path(self.temp_dir) / "python311.exe"
        project_python.touch()
        self.config.add_interpreter("3.11", str(project_python))
        
        version_file = test_dir / ".python-version"
        version_file.write_text("3.11")
        
        # Set up default Python
        default_python = Path(self.temp_dir) / "python39.exe"
        default_python.touch()
        self.config.add_interpreter("default", str(default_python))
        self.config.set_default_interpreter("default")
        
        # Virtual environment should take priority
        with patch.dict(os.environ, {"VIRTUAL_ENV": str(venv_dir)}):
            result = self.detector.resolve_interpreter(str(test_dir))
            self.assertEqual(result, str(venv_python))
    
    def test_resolve_interpreter_priority_project(self):
        """Test that project config has priority over default."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        # Set up project Python
        project_python = Path(self.temp_dir) / "python311.exe"
        project_python.touch()
        self.config.add_interpreter("3.11", str(project_python))
        
        version_file = test_dir / ".python-version"
        version_file.write_text("3.11")
        
        # Set up default Python
        default_python = Path(self.temp_dir) / "python39.exe"
        default_python.touch()
        self.config.add_interpreter("default", str(default_python))
        self.config.set_default_interpreter("default")
        
        # Project Python should take priority over default
        result = self.detector.resolve_interpreter(str(test_dir))
        self.assertEqual(result, str(project_python.resolve()))
    
    def test_resolve_interpreter_fallback_to_default(self):
        """Test falling back to default interpreter."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        # Only set up default Python
        default_python = Path(self.temp_dir) / "python39.exe"
        default_python.touch()
        self.config.add_interpreter("default", str(default_python))
        self.config.set_default_interpreter("default")
        
        result = self.detector.resolve_interpreter(str(test_dir))
        self.assertEqual(result, str(default_python.resolve()))
    
    def test_resolve_interpreter_none_configured(self):
        """Test when no interpreter is configured."""
        test_dir = Path(self.temp_dir) / "project"
        test_dir.mkdir()
        
        result = self.detector.resolve_interpreter(str(test_dir))
        self.assertIsNone(result)


if __name__ == "__main__":
    unittest.main()
