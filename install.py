"""Windows installation script for pyshim."""

import os
import sys
import shutil
import subprocess
from pathlib import Path


def find_python_installations():
    """Find Python installations on Windows."""
    installations = []
    
    # Check common installation locations
    search_paths = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Python",
        Path(os.environ.get("PROGRAMFILES", "")) / "Python",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Python",
        Path("C:\\Python"),
    ]
    
    for base_path in search_paths:
        if not base_path.exists():
            continue
        
        # Look for Python* directories
        try:
            for item in base_path.iterdir():
                if item.is_dir() and "python" in item.name.lower():
                    python_exe = item / "python.exe"
                    if python_exe.exists():
                        installations.append(str(python_exe))
        except Exception:
            pass
    
    # Check if py launcher is available
    try:
        result = subprocess.run(
            ["py", "-0"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            # Parse py launcher output
            for line in result.stdout.splitlines():
                if line.strip() and not line.startswith(" "):
                    # Extract version info
                    pass
    except Exception:
        pass
    
    return installations


def create_shim_directory():
    """Create directory for shim executables."""
    shim_dir = Path.home() / ".pyshim" / "bin"
    shim_dir.mkdir(parents=True, exist_ok=True)
    return shim_dir


def install_shims(shim_dir):
    """Install shim executables to the shim directory."""
    # For Python-based shims, we'll create batch files and scripts
    
    # Create batch files for Windows
    batch_template = """@echo off
python -m pyshim.shim {command} %*
"""
    
    commands = {
        "python.bat": "python",
        "pip.bat": "pip",
        "py.bat": "py",
    }
    
    for filename, command in commands.items():
        batch_file = shim_dir / filename
        content = f'@echo off\npython -m pyshim.shim:{command} %*\n'
        batch_file.write_text(content)
        print(f"Created shim: {batch_file}")


def setup_path_instructions(shim_dir):
    """Provide instructions for adding shim directory to PATH."""
    print("\n" + "="*60)
    print("Installation complete!")
    print("="*60)
    print(f"\nShim directory: {shim_dir}")
    print("\nTo complete installation, add the shim directory to your PATH:")
    print("1. Press Win+X and select 'System'")
    print("2. Click 'Advanced system settings'")
    print("3. Click 'Environment Variables'")
    print("4. Under 'User variables', select 'Path' and click 'Edit'")
    print(f"5. Add this directory: {shim_dir}")
    print("6. Click OK to save")
    print("\nAlternatively, run this PowerShell command as Administrator:")
    print(f'   [Environment]::SetEnvironmentVariable("Path", "$env:Path;{shim_dir}", "User")')
    print("\nAfter updating PATH, restart your terminal for changes to take effect.")
    print("\nNext steps:")
    print("1. Run 'pyshim config add <name> <path>' to register Python interpreters")
    print("2. Run 'pyshim config default <name>' to set your default interpreter")
    print("3. Run 'pyshim status' to verify configuration")


def main():
    """Main installation routine."""
    print("Installing pyshim - Context-aware Python shim for Windows")
    print("="*60)
    
    # Create shim directory
    print("\nCreating shim directory...")
    shim_dir = create_shim_directory()
    
    # Install shims
    print("\nInstalling shim executables...")
    install_shims(shim_dir)
    
    # Find Python installations
    print("\nSearching for Python installations...")
    installations = find_python_installations()
    
    if installations:
        print(f"\nFound {len(installations)} Python installation(s):")
        for i, install in enumerate(installations, 1):
            print(f"  {i}. {install}")
    else:
        print("\nNo Python installations found automatically.")
    
    # Provide PATH setup instructions
    setup_path_instructions(shim_dir)


if __name__ == "__main__":
    main()
