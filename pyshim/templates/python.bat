@echo off
REM Shim for python.exe that routes to the appropriate Python interpreter
python -c "from pyshim.shim import main_python; main_python()" %*
