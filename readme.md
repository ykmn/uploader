# Uploader DJin XML
![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)
[![Licence](https://img.shields.io/github/license/ykmn/ff-Logger?style=for-the-badge)](./LICENSE)
![Microsoft Windows](https://img.shields.io/badge/Microsoft-Windows-%FF5F91FF.svg?style=for-the-badge&logo=Microsoft%20Windows&logoColor=white)

> 06.05.2025 Roman Ermakov <r.ermakov@emg.fm>

Программы предназначены для обработки XML-файла с метаданными от Джин.ValueServer или Джин.Что-в-эфире
и отправки метаданных различным получателям. В качестве получателей метаданных могут выступать:

* JSON-сервер хостинга, получающий преобразованые в JSON метаданные с текущей и следующими по плейлисту песнями в следующем виде:
```json
{
"stream":  "myradio.cfg",
"songs":  [
	{ "artist":  "Arilena Ara", "runtime":  149, "dbID":  "151597", "ELEM":  0, "title":  "Nentori (Beverly Pills Remix)", "starttime":  1500984064 },
	{ "artist":  "Nickelback", "runtime":  197, "dbID":  "1274", "ELEM":  2, "title":  "If Everyone Cared", "starttime":  1500984223 },
	{ "artist":  "Charlie Puth", "runtime":  203, "dbID":  "152322", "ELEM":  5, "title":  "Attention", "starttime":  1500984426 }
	]
}
```

* JSON-сервер хостинга, на который методом POST отправится XML-файл с метаданными от Джин "Что в эфире".

* локальная папка, в которую сохранится JSON-файл в формате:
```json
{
  "dbID": "178717",
  "title": "Moonlit Floor",
  "artist": "Lisa",
  "at": "LISA - MOONLIT FLOOR"
}
```

* один или несколько FTP-серверов, на которые выгрузится XML-файл с метаданными от Джин "Что в эфире".
* один или несколько энкодеров Omnia Z/IPStream или ProStream.
* один или несколько RDS-кодеров DEVA SmartGen с передачей данных по TCP/UDP или встроенных в FM-процессор Orban 8700i RDS-кодеров с передачей данных по TCP.

Принцип работы.
---------------
* [FileMonitor.ps1](FileMonitor/FileMonitor readme.md) следит за указанной папкой, и если в ней изменился XML-файл из списка, скрипт копирует этот файл в подпапку UPLOAD\,
запускает обработчик `uploader3` и в качестве параметра передаёт ему имя изменённого XML-файла.
Дополнительно `FileMonitor` может переименовать этот XML-файл.

* [uploader3](v3/Uploader readme.md) работает с XML-файлами, которые генерирует модуль Джин [Что играет в плеере 3.0 Расширенный](https://redmine.digispot.ru/projects/digispot/wiki/%D0%A7%D1%82%D0%BE_%D0%B8%D0%B3%D1%80%D0%B0%D0%B5%D1%82_%D0%B2_%D0%BF%D0%BB%D0%B5%D0%B5%D1%80%D0%B5_%D0%B2_%D0%B2%D0%B8%D0%B4%D0%B5_XML_v_3_0).
Запуск этого скрипта выполняется скриптом [FileMonitor.ps1](FileMonitor/FileMonitor readme.md)
