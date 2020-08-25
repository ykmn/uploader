@echo off
::cd "C:\Program Files (x86)\Digispot II\Uploader"
cd C:\Users\r.ermakov\Documents\GitHub\uploader\v3
title %1
echo %date% %time% %1 >> log\runps.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader3.01.003.ps1" %1 %2
::pause