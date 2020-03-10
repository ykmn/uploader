@echo off
if '%1' == '' goto :description
set LOG=C:\XML\LOG
if not exist %LOG% mkdir %LOG%

echo %date% %time% >> %LOG%\%date%-%1.log
FOR %%d IN ("TECH-INFOSERV1" "TECH-INFOSERV2") DO (
::robocopy C:\XML \\%%~d\XML %1 /IS /IT /R:2 /W:0 /NJH /NDL /FP /NS /NC /V /LOG+:%LOG%\%date%-robocopy.log /TEE
echo %date% %time% >> %LOG%\%date%-%1.log
xcopy .\%1 \\%%~d\XML /C /Y /F >> %LOG%\%date%-%1.log
::echo %%d %ERRORLEVEL% >> %LOG%\%date%-%1.log
echo. >> %LOG%\%date%-%1.log
)

::pause
goto:end

:description
echo Usage: filecopy filename.xml

:end
