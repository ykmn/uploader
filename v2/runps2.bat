@echo off
cd "C:\Program Files (x86)\Digispot II\Uploader"
title %1
echo %date% %time% %1 >> log\runps.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader2.ps1" %1 %2
::pause