@echo off
title Snow Job mod updater
rem Downloads the latest updater from the SnowJob-Mods GitHub repo and runs it. Close Valheim first.
rem If anything goes wrong the window stays open and a log is written to %TEMP%\SnowJob-Updater.log
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $s = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/JohmesSnow/SnowJob-Mods/main/updater/SnowJob-Updater.ps1') } catch { Write-Host ('Could not reach GitHub: ' + $_.Exception.Message) -ForegroundColor Red; exit 12 }; try { & ([ScriptBlock]::Create($s)) } catch { Write-Host ('The updater stopped with an error: ' + $_) -ForegroundColor Red; Write-Host $_.ScriptStackTrace; exit 13 } }"
set "CODE=%ERRORLEVEL%"
if "%CODE%"=="0" goto :eof
if "%CODE%"=="10" goto :eof
if "%CODE%"=="11" goto :eof
echo.
if "%CODE%"=="9009" echo PowerShell could not be started. It may be blocked by antivirus.
if "%CODE%"=="12" echo Check your internet connection, VPN or antivirus web protection.
echo Something went wrong (code %CODE%). Take a screenshot of this window and send it to the group,
echo together with the log file: %TEMP%\SnowJob-Updater.log
echo.
pause
