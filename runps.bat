cd "C:\Program Files (x86)\Digispot II\Uploader"
echo %date% %time% %1 >> .\test.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader2.ps1" %1
