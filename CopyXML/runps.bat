@echo off
if "%1"=="" goto:howto
cd "C:\XML"
title %1 %2 %3 %4
echo %date% %time% %1 %2 %3 %4 >> .\log\%date%-%~nx0.log
::powershell -NoProfile -ExecutionPolicy bypass -File "CopyXML.ps1" %1 %2 %3 %4
powershell -NoProfile -ExecutionPolicy bypass -File %1 %2 %3 %4
::pause
goto:end

:howto
echo RunPS.bat   Wrapper for execution PowerShell scripts from Digispot DJin
echo.
echo Usage:
echo runps yourPowerShellScript.ps1 [parameter1] [parameter2] [parameter3]
echo.
:end