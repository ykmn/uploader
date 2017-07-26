cd "C:\Program Files (x86)\Digispot II\Uploader"
echo %date% %time% %1 >> .\test.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader-2.07b5.ps1" %1
