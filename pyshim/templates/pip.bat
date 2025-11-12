@echo off
REM Shim for pip.exe that routes to the appropriate Python interpreter
python -c "from pyshim.shim import main_pip; main_pip()" %*
