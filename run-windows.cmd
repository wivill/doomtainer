@echo off
rem Double-clickable Windows launcher (also usable as a Steam shortcut target).
rem Runs run-native.sh with Git for Windows' bash, which the repo needs anyway.
setlocal
set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%GITBASH%" (
    echo Git for Windows not found at "%GITBASH%". Install it from https://git-scm.com/download/win
    pause
    exit /b 1
)
cd /d "%~dp0"
"%GITBASH%" ./run-native.sh %*
if errorlevel 1 pause
