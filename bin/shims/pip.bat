@echo off
setlocal
REM ensure pip matches whatever python.bat resolved
"%~dp0python.bat" -m pip %*
