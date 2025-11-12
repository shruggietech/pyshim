@echo off
REM Shim for py.exe that routes to the appropriate Python interpreter
python -c "from pyshim.shim import main_py; main_py()" %*
