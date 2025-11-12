@echo off
REM Guard against recursion if PATH is reordered or shim calls itself
if "%PYSHIM_INVOKING%"=="1" exit /b 1
set "PYSHIM_INVOKING=1"

setlocal ENABLEDELAYEDEXPANSION
REM PYSHIM: central resolver for python on Windows (recursion-safe)

set "SHIMDIR=%~dp0"
set "GLOBAL_ENV=%SHIMDIR%python.env"
set "GLOBAL_NOPERSIST=%SHIMDIR%python.nopersist"

REM 0) One-shot flag: --interpreter "SPEC" --
set "ONESHOT_SPEC="
if /I "%~1"=="--interpreter" (
  if /I "%~3"=="--" (
    set "ONESHOT_SPEC=%~2"
    shift & shift & shift
  )
)

REM --- helpers -------------------------------------------------------
REM Resolve a SPEC (absolute path, conda:ENV, py:VER, plain)
set "RESOLVED_CMD="
call :RESOLVE_SPEC "%ONESHOT_SPEC%" RESOLVED_CMD
if defined RESOLVED_CMD goto :RUN

REM 1) Session override
if defined PYSHIM_INTERPRETER (
  call :RESOLVE_SPEC "%PYSHIM_INTERPRETER%" RESOLVED_CMD
  if defined RESOLVED_CMD goto :RUN
)

REM 2) App-target override
if defined PYSHIM_TARGET (
  set "TARGET_ENV=%SHIMDIR%python@%PYSHIM_TARGET%.env"
  if exist "%TARGET_ENV%" (
    for /f "usebackq delims=" %%P in ("%TARGET_ENV%") do set "SPEC=%%P"
    call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD
    if defined RESOLVED_CMD goto :RUN
  )
)

REM 3) .python-version (walk up)
call :FIND_DOTFILE ".python-version" PVFILE
if defined PVFILE (
  for /f "usebackq delims=" %%P in ("%PVFILE%") do set "SPEC=%%P"
  call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD
  if defined RESOLVED_CMD goto :RUN
)

REM 4) Global persistence (unless disabled)
if not exist "%GLOBAL_NOPERSIST%" if exist "%GLOBAL_ENV%" (
  for /f "usebackq delims=" %%P in ("%GLOBAL_ENV%") do set "SPEC=%%P"
  call :RESOLVE_SPEC "%SPEC%" RESOLVED_CMD
  if defined RESOLVED_CMD goto :RUN
)

REM 5) Fallback chain (recursion guards):
REM    - Prefer real py.exe if present and NOT coming from a py.bat shim
where py >NUL 2>&1
if %ERRORLEVEL%==0 if not defined PYSHIM_FROM_PY (
  set "RESOLVED_CMD=py -3.12"
  goto :RUN
)

where py >NUL 2>&1
if %ERRORLEVEL%==0 if not defined PYSHIM_FROM_PY (
  set "RESOLVED_CMD=py -3"
  goto :RUN
)

REM    - Try conda base if available
where conda >NUL 2>&1 && (set "RESOLVED_CMD=conda run -n base python" & goto :RUN)

REM    - Locate a real python.exe that is NOT this shim directory
for /f "usebackq delims=" %%P in (`where python.exe 2^>NUL`) do (
  REM skip any hit inside the shim folder
  echo "%%~dpP" | find /I "%SHIMDIR%" >NUL
  if errorlevel 1 (
    set "RESOLVED_CMD=%%P"
    goto :RUN
  )
)

REM    - Last resort: error out clearly
echo [pyshim] No real python.exe found on PATH and no usable launcher/conda. 1>&2
exit /b 9009

:RUN
%RESOLVED_CMD% %*
exit /b %ERRORLEVEL%

:RESOLVE_SPEC
REM %1 = SPEC (maybe empty), %2 = outvar
set "_spec=%~1"
if not defined _spec goto :eof

REM absolute path?
if exist "%_spec%" (
  set "%~2=%_spec%"
  goto :eof
)

REM conda:ENV
echo.%_spec%| findstr /b /c:"conda:" >NUL
if not errorlevel 1 (
  set "_env=%_spec:conda:=%"
  set "%~2=conda run -n %_env% python"
  goto :eof
)

REM py:VERSION
echo.%_spec%| findstr /b /c:"py:" >NUL
if not errorlevel 1 (
  set "_ver=%_spec:py:=%"
  set "%~2=py -%_ver%"
  goto :eof
)

REM plain token (treat as exe name): force .exe to avoid re-entering this .bat
if /I "%_spec%"=="python" set "_spec=python.exe"
set "%~2=%_spec%"
goto :eof

:FIND_DOTFILE
REM %1 = filename, %2 = outvar
set "_fn=%~1"
set "_here=%cd%"
set "_visited_dirs="
:WALKUP
if exist "%_here%\%_fn%" (
  set "%~2=%_here%\%_fn%"
  goto :eof
)
REM Guard against junction/symlink cycles
if defined _visited_dirs (
  echo.|set /p="|%_here%|" | findstr /I /C:"%_visited_dirs%" >nul && goto :eof
  set "_visited_dirs=%_visited_dirs%|%_here%"
) else (
  set "_visited_dirs=|%_here%"
)
REM Compute canonical parent using %%~f normalization
for %%P in ("%_here%\..") do set "_parent=%%~fP"
REM If parent equals current dir, we're at a root (drive or UNC); stop
if /i "%_parent%"=="%_here%" goto :eof
set "_here=%_parent%"
goto :WALKUP
