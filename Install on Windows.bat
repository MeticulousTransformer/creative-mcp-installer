@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-MCPs.ps1" %*
set result=%ERRORLEVEL%
if not "%result%"=="0" (
  echo.
  echo Installation stopped. Read the message above, fix the missing requirement, then run this file again.
  pause
)
exit /b %result%
