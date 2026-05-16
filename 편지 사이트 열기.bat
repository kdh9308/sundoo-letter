@echo off
chcp 65001 >nul 2>&1
title Sundoo Church Letter Site
cd /d "%~dp0"

REM Kill any stale Python servers from previous runs (cleans port 8000)
taskkill /F /IM python.exe /FI "WINDOWTITLE eq Sundoo*" >nul 2>nul
taskkill /F /IM py.exe /FI "WINDOWTITLE eq Sundoo*" >nul 2>nul

where py >nul 2>nul
if %ERRORLEVEL%==0 goto :run_py

where python >nul 2>nul
if %ERRORLEVEL%==0 goto :run_python

echo.
echo [ERROR] Python is not installed.
echo Please install Python from https://www.python.org/downloads/
echo.
pause
exit /b 1

:run_py
py "%~dp0server.py"
goto :done

:run_python
python "%~dp0server.py"
goto :done

:done
echo.
echo Server stopped. You can close this window.
pause >nul
