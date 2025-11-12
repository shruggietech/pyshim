"""Tests for shim execution."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from pyshim.config import Config
from pyshim.shim import PythonShim, PipShim, PyShim


class TestPythonShim(unittest.TestCase):
    """Test cases for PythonShim class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_dir = Path(self.temp_dir) / ".pyshim"
        self.config_file = self.config_dir / "config.json"
        
        # Override config paths for testing
        Config.CONFIG_DIR = self.config_dir
        Config.CONFIG_FILE = self.config_file
        
        self.shim = PythonShim()
    
    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_get_interpreter_returns_configured(self):
        """Test that get_interpreter returns configured interpreter."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.shim.config.add_interpreter("test", str(python_path))
        self.shim.config.set_default_interpreter("test")
        
        result = self.shim.get_interpreter()
        self.assertEqual(result, str(python_path.resolve()))
    
    def test_get_interpreter_returns_none_when_not_configured(self):
        """Test that get_interpreter returns None when nothing configured."""
        result = self.shim.get_interpreter()
        self.assertIsNone(result)
    
    @patch('pyshim.shim.subprocess.run')
    def test_execute_calls_subprocess_with_interpreter(self, mock_run):
        """Test that execute calls subprocess with correct arguments."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.shim.config.add_interpreter("test", str(python_path))
        self.shim.config.set_default_interpreter("test")
        
        mock_run.return_value = Mock(returncode=0)
        
        result = self.shim.execute(["--version"])
        
        mock_run.assert_called_once()
        call_args = mock_run.call_args[0][0]
        self.assertEqual(call_args[0], str(python_path.resolve()))
        self.assertEqual(call_args[1], "--version")
        self.assertEqual(result, 0)
    
    def test_execute_returns_error_when_no_interpreter(self):
        """Test that execute returns error when no interpreter configured."""
        result = self.shim.execute(["--version"])
        self.assertEqual(result, 1)
    
    def test_execute_returns_error_when_interpreter_not_found(self):
        """Test that execute returns error when interpreter file not found."""
        self.shim.config._config["interpreters"]["test"] = "/nonexistent/python.exe"
        self.shim.config._config["default_interpreter"] = "test"
        
        result = self.shim.execute(["--version"])
        self.assertEqual(result, 1)


class TestPipShim(unittest.TestCase):
    """Test cases for PipShim class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_dir = Path(self.temp_dir) / ".pyshim"
        self.config_file = self.config_dir / "config.json"
        
        Config.CONFIG_DIR = self.config_dir
        Config.CONFIG_FILE = self.config_file
        
        self.shim = PipShim()
    
    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    @patch('pyshim.shim.subprocess.run')
    def test_execute_calls_pip_as_module(self, mock_run):
        """Test that pip shim calls Python with -m pip."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.shim.python_shim.config.add_interpreter("test", str(python_path))
        self.shim.python_shim.config.set_default_interpreter("test")
        
        mock_run.return_value = Mock(returncode=0)
        
        result = self.shim.execute(["install", "package"])
        
        mock_run.assert_called_once()
        call_args = mock_run.call_args[0][0]
        self.assertEqual(call_args[0], str(python_path.resolve()))
        self.assertEqual(call_args[1], "-m")
        self.assertEqual(call_args[2], "pip")
        self.assertEqual(call_args[3], "install")
        self.assertEqual(call_args[4], "package")


class TestPyShim(unittest.TestCase):
    """Test cases for PyShim class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_dir = Path(self.temp_dir) / ".pyshim"
        self.config_file = self.config_dir / "config.json"
        
        Config.CONFIG_DIR = self.config_dir
        Config.CONFIG_FILE = self.config_file
        
        self.shim = PyShim()
    
    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    @patch('pyshim.shim.subprocess.run')
    def test_execute_routes_to_python(self, mock_run):
        """Test that py shim routes to configured Python."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.shim.python_shim.config.add_interpreter("test", str(python_path))
        self.shim.python_shim.config.set_default_interpreter("test")
        
        mock_run.return_value = Mock(returncode=0)
        
        result = self.shim.execute(["--version"])
        
        mock_run.assert_called_once()
        call_args = mock_run.call_args[0][0]
        self.assertEqual(call_args[0], str(python_path.resolve()))
        self.assertEqual(call_args[1], "--version")


if __name__ == "__main__":
    unittest.main()
