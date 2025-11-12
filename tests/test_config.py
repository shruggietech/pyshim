"""Tests for pyshim configuration management."""

import json
import tempfile
import unittest
from pathlib import Path

from pyshim.config import Config


class TestConfig(unittest.TestCase):
    """Test cases for Config class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_dir = Path(self.temp_dir) / ".pyshim"
        self.config_file = self.config_dir / "config.json"
        
        # Override config paths for testing
        Config.CONFIG_DIR = self.config_dir
        Config.CONFIG_FILE = self.config_file
        
        self.config = Config()
    
    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_init_creates_default_config(self):
        """Test that initialization creates default configuration."""
        self.assertIsNotNone(self.config._config)
        self.assertIn("interpreters", self.config._config)
        self.assertIn("default_interpreter", self.config._config)
        self.assertIn("search_paths", self.config._config)
    
    def test_add_interpreter(self):
        """Test adding a Python interpreter."""
        # Create a dummy Python executable
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.config.add_interpreter("test-python", str(python_path))
        
        self.assertIn("test-python", self.config._config["interpreters"])
        self.assertEqual(
            self.config._config["interpreters"]["test-python"],
            str(python_path.resolve())
        )
    
    def test_add_nonexistent_interpreter_raises_error(self):
        """Test that adding non-existent interpreter raises ValueError."""
        with self.assertRaises(ValueError):
            self.config.add_interpreter("fake", "/nonexistent/path/python.exe")
    
    def test_remove_interpreter(self):
        """Test removing a Python interpreter."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.config.add_interpreter("test-python", str(python_path))
        self.assertIn("test-python", self.config._config["interpreters"])
        
        self.config.remove_interpreter("test-python")
        self.assertNotIn("test-python", self.config._config["interpreters"])
    
    def test_get_interpreter(self):
        """Test getting interpreter path by name."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.config.add_interpreter("test-python", str(python_path))
        
        result = self.config.get_interpreter("test-python")
        self.assertEqual(result, str(python_path.resolve()))
    
    def test_get_nonexistent_interpreter(self):
        """Test getting non-existent interpreter returns None."""
        result = self.config.get_interpreter("nonexistent")
        self.assertIsNone(result)
    
    def test_list_interpreters(self):
        """Test listing all interpreters."""
        python1 = Path(self.temp_dir) / "python1.exe"
        python2 = Path(self.temp_dir) / "python2.exe"
        python1.touch()
        python2.touch()
        
        self.config.add_interpreter("python1", str(python1))
        self.config.add_interpreter("python2", str(python2))
        
        interpreters = self.config.list_interpreters()
        self.assertEqual(len(interpreters), 2)
        self.assertIn("python1", interpreters)
        self.assertIn("python2", interpreters)
    
    def test_set_default_interpreter(self):
        """Test setting default interpreter."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.config.add_interpreter("test-python", str(python_path))
        self.config.set_default_interpreter("test-python")
        
        self.assertEqual(self.config._config["default_interpreter"], "test-python")
    
    def test_set_nonexistent_default_raises_error(self):
        """Test that setting non-existent default raises ValueError."""
        with self.assertRaises(ValueError):
            self.config.set_default_interpreter("nonexistent")
    
    def test_get_default_interpreter(self):
        """Test getting default interpreter path."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.config.add_interpreter("test-python", str(python_path))
        self.config.set_default_interpreter("test-python")
        
        result = self.config.get_default_interpreter()
        self.assertEqual(result, str(python_path.resolve()))
    
    def test_get_default_when_none_set(self):
        """Test getting default when none is set returns None."""
        result = self.config.get_default_interpreter()
        self.assertIsNone(result)
    
    def test_save_and_load_config(self):
        """Test that configuration is saved and loaded correctly."""
        python_path = Path(self.temp_dir) / "python.exe"
        python_path.touch()
        
        self.config.add_interpreter("test-python", str(python_path))
        self.config.set_default_interpreter("test-python")
        
        # Create new config instance to load from file
        new_config = Config()
        
        self.assertEqual(
            new_config.get_interpreter("test-python"),
            str(python_path.resolve())
        )
        self.assertEqual(
            new_config._config["default_interpreter"],
            "test-python"
        )
    
    def test_add_search_path(self):
        """Test adding a search path."""
        search_path = Path(self.temp_dir) / "projects"
        search_path.mkdir()
        
        self.config.add_search_path(str(search_path))
        
        self.assertIn(str(search_path.resolve()), self.config._config["search_paths"])
    
    def test_get_search_paths(self):
        """Test getting search paths."""
        path1 = Path(self.temp_dir) / "path1"
        path2 = Path(self.temp_dir) / "path2"
        path1.mkdir()
        path2.mkdir()
        
        self.config.add_search_path(str(path1))
        self.config.add_search_path(str(path2))
        
        paths = self.config.get_search_paths()
        self.assertEqual(len(paths), 2)
        self.assertIn(str(path1.resolve()), paths)
        self.assertIn(str(path2.resolve()), paths)


if __name__ == "__main__":
    unittest.main()
