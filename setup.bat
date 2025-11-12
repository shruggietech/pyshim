@echo off
REM Quick setup script for pyshim on Windows

echo ================================================
echo pyshim - Context-Aware Python Shim Setup
echo ================================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7 or higher first
    pause
    exit /b 1
)

echo Step 1: Installing pyshim package...
pip install -e .
if errorlevel 1 (
    echo ERROR: Failed to install pyshim
    pause
    exit /b 1
)
echo [OK] pyshim package installed

echo.
echo Step 2: Running installation script...
python install.py
if errorlevel 1 (
    echo ERROR: Installation script failed
    pause
    exit /b 1
)
echo [OK] Installation complete

echo.
echo Step 3: Configuring PATH...
echo.
echo IMPORTANT: You need to add the following directory to your PATH:
echo %USERPROFILE%\.pyshim\bin
echo.
echo Choose an option:
echo   1. Add to PATH automatically (requires admin)
echo   2. Show manual instructions
echo   3. Skip (I'll do it later)
echo.
choice /c 123 /n /m "Enter your choice (1, 2, or 3): "

if errorlevel 3 goto skip_path
if errorlevel 2 goto manual_instructions
if errorlevel 1 goto auto_path

:auto_path
echo.
echo Adding to PATH...
powershell -Command "$userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if ($userPath -notmatch 'pyshim') { [Environment]::SetEnvironmentVariable('Path', '%USERPROFILE%\.pyshim\bin;' + $userPath, 'User') }"
echo [OK] PATH updated
goto next_steps

:manual_instructions
echo.
echo Manual PATH Setup Instructions:
echo ================================
echo 1. Press Win+X and select "System"
echo 2. Click "Advanced system settings"
echo 3. Click "Environment Variables"
echo 4. Under "User variables", select "Path" and click "Edit"
echo 5. Click "New" and add: %USERPROFILE%\.pyshim\bin
echo 6. Click "Move Up" until it's at the top
echo 7. Click OK to save
echo.
pause
goto next_steps

:skip_path
echo.
echo Skipping PATH setup. Remember to add manually later!
echo.
goto next_steps

:next_steps
echo.
echo ================================================
echo Setup Complete!
echo ================================================
echo.
echo Next Steps:
echo.
echo 1. RESTART your terminal for PATH changes to take effect
echo.
echo 2. Register your Python installations:
echo    pyshim config add py39 "C:\Python39\python.exe"
echo    pyshim config add py311 "C:\Python311\python.exe"
echo.
echo 3. Set a default Python:
echo    pyshim config default py311
echo.
echo 4. Verify installation:
echo    pyshim status
echo    pyshim which
echo.
echo 5. Use in your projects:
echo    cd your-project
echo    echo py311 ^> .python-version
echo    python --version
echo.
echo For more information, see the documentation in the docs/ folder
echo.
pause
