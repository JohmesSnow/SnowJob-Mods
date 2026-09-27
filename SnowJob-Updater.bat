@echo off
title Snow Job mod updater
rem Runs SnowJob-Updater.ps1 from this folder (keep both files together). The updater keeps itself and the
rem mod pack up to date from github.com/JohmesSnow/SnowJob-Mods. Close Valheim first.
if not exist "%~dp0SnowJob-Updater.ps1" (
  echo SnowJob-Updater.ps1 is missing. Extract the whole SnowJob-Updater.zip, not just this file.
  echo Download: https://github.com/JohmesSnow/SnowJob-Mods/releases/latest/download/SnowJob-Updater.zip
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SnowJob-Updater.ps1" %*
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="0" goto :eof
if "%CODE%"=="10" goto :eof
if "%CODE%"=="11" goto :eof
echo.
if "%CODE%"=="9009" echo PowerShell could not be started. It may be blocked by antivirus.
echo Something went wrong (code %CODE%). Take a screenshot of this window and send it to the group,
echo together with the log file: %TEMP%\SnowJob-Updater.log
echo.
pause
