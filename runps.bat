:: echo %date% %time% %1 >> .\test.log
@cd "C:\Program Files (x86)\Digispot II\Uploader"
powershell -NoProfile -ExecutionPolicy bypass -File "uploader2.ps1" %1
