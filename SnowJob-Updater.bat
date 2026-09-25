@echo off
title Snow Job mod updater
rem Downloads the latest updater from the SnowJob-Mods GitHub repo and runs it. Close Valheim first.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $s = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/JohmesSnow/SnowJob-Mods/main/updater/SnowJob-Updater.ps1') } catch { Write-Host ('Could not reach GitHub: ' + $_.Exception.Message) -ForegroundColor Red; Read-Host 'Press Enter to close'; exit 1 }; & ([ScriptBlock]::Create($s)) }"
