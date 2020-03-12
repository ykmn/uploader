@echo off
if '%1' == '' goto :description
set LOG=LOG
if not exist %LOG% mkdir %LOG%

echo %date% %time% Script started >> %LOG%\%date%-%1.log
:: "RETRO-AIR-2" "RETRO-AIR-1" "EUROPA-AIR-2" "EUROPA-AIR-5" "AIR-INET1" "AIR-INET2" "AIR-AUTO1" "AIR-AUTO2" "DOROG-AIR-1" "RADIO7-AIR-1"

FOR %%d IN ("RETRO-AIR-2" "RETRO-AIR-1" "EUROPA-AIR-2" "AIR-INET1" "AIR-INET2" "AIR-AUTO1" "AIR-AUTO2" "DOROG-AIR-1" "RADIO7-AIR-1") DO (
 xcopy .\%1 \\%%~d\c$\XML /C /Y /F >> %LOG%\%date%-%1.log
 echo %date% %time% Copy to %%~d Errorlevel %ERRORLEVEL% >> %LOG%\%date%-%1.log
 echo %date% %time% Copy to %%~d Errorlevel %ERRORLEVEL%
)
::pause
echo %date% %time% Script finished >> %LOG%\%date%-%1.log
echo. >> %LOG%\%date%-%1.log
goto:end

:description
echo Usage: filecopy-update filecopy.bat
echo Updates filecopy.bat on servers

:end
