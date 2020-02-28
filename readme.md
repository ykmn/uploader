Uploader DJin XML
==================
28.02.2020 Roman Ermakov <r.ermakov@emg.fm>

Программы предназначены для обработки XML-файла с метаданными от Джин.ValueServer или Джин.Что-в-эфире
и отправки метаданных различным получателям. В качестве получателей метаданных могут выступать:

* JSON-сервер хостинга. Метаданные будут преобразованы в JSON с текущей и следующими по плейлисту песнями в следующем виде:
```JSON
{
"stream":  "myradio.cfg",
"songs":  [
	{ "artist":  "Arilena Ara", "runtime":  149, "dbID":  "151597", "ELEM":  0, "title":  "Nentori (Beverly Pills Remix)", "starttime":  1500984064 },
	{ "artist":  "Nickelback", "runtime":  197, "dbID":  "1274", "ELEM":  2, "title":  "If Everyone Cared", "starttime":  1500984223 },
	{ "artist":  "Charlie Puth", "runtime":  203, "dbID":  "152322", "ELEM":  5, "title":  "Attention", "starttime":  1500984426 }
	]
}
```

* Один или два FTP-сервера, на которые выгрузится XML-файл с метаданными от Джин.ValueServer.
* Один или два энкодера Omnia Z/IPStream или ProStream.
* RDS-кодер DEVA SmartGen с передачей данных по TCP/UDP или встроенный RDS-кодер FM-процессора Orban 8700i с передачей данных по TCP.

Принцип работы.
---------------
* [FileMonitor.ps1](FileMonitor/readme.md) следит за указанной папкой, и если в ней изменился XML-файл из списка, скрипт копирует этот файл в подпапку UPLOAD\,
запускает обработчик `uploader2` или `uploader2` и в качестве параметра передаёт ему имя изменённого XML-файла.
Дополнительно `FileMonitor` может переименовать этот XML-файл.

* [uploader2](v2/readme.md) работает с XML-файлами, которые генерирует Джин.ValueServer.
Запуск скрипта `uploader2` может выполнять как Джин.ValueServer, так и [FileMonitor.ps1](FileMonitor/readme.md)

* [uploader3](v3/readme.md) работает с XML-файлами, которые генерирует модуль Джин [Что играет в плеере 3.0 Расширенный](https://redmine.digispot.ru/projects/digispot/wiki/%D0%A7%D1%82%D0%BE_%D0%B8%D0%B3%D1%80%D0%B0%D0%B5%D1%82_%D0%B2_%D0%BF%D0%BB%D0%B5%D0%B5%D1%80%D0%B5_%D0%B2_%D0%B2%D0%B8%D0%B4%D0%B5_XML_v_3_0).
Запуск этого скрипта выполняется скриптом [FileMonitor.ps1](FileMonitor/readme.md)
