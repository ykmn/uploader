@echo off
cd "C:\Program Files (x86)\Digispot II\Uploader"
title %1
echo %date% %time% %1 >> .\log\%date%-runps.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader-2.07.016.ps1" %1 %2
:: -test
::pause
