@echo off
cd "C:\Program Files (x86)\Digispot II\Uploader"
::cd C:\Users\r.ermakov\Documents\GitHub\uploader\
title %1
echo %date% %time% %1 >> .\log\%date%-runps3.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader3.06.004.ps1" %1 %2
::pause