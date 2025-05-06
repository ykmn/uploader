@echo off
cd "C:\Program Files (x86)\Digispot II\Uploader"
title %1

:: assuming date format as 31.12.2024
for /F "tokens=1-3 delims=. " %%a in ("%date%") do ( set yyyymmdd=%%c-%%b-%%a )
echo %yyyymmdd% %time% %1 >> .\log\"%yyyymmdd% Running runps3.log"

pwsh -NoProfile -ExecutionPolicy bypass -File "uploader3.06.004.ps1" %1 %2
::pause
