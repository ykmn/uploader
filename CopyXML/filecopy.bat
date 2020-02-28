@echo off
if '%1' == '' goto :description

FOR %%d IN ("TECH-INFOSERV1" "TECH-INFOSERV2") DO (
robocopy C:\XML \\%%~d\XML %1 /IS /UNILOG+:C:\XML\LOG\%date%-robocopy.log
)

::pause
goto:end

:description
echo Usage: filecopy filename.xml

:end
