@echo off
cd "C:\Program Files (x86)\Digispot II\Uploader"
echo %date% %time% %1 >> log\runps.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader-2.07.015.ps1" %1 %2
