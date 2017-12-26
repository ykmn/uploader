Uploader 2.07.010
==================
26.12.2017 Roman Ermakov <r.ermakov@emg.fm>

Программа предназначена для обработки XML-файла с метаданными от Джин.ValueServer и отправки метаданных различным получателям.
В качестве получателей метаданных могут выступать:

* JSON-сервер хостинга. Метаданные будут преобразованы в JSON с текущей и следующими по плейлисту песнями в следующем виде:
```JSON
{
"stream":  "europaplus.cfg",
"songs":  [
	{ "artist":  "Arilena Ara", "runtime":  149, "dbID":  "151597", "ELEM":  0, "title":  "Nentori (Beverly Pills Remix)", "starttime":  1500984064 },
	{ "artist":  "Nickelback", "runtime":  197, "dbID":  "1274", "ELEM":  2, "title":  "If Everyone Cared", "starttime":  1500984223 },
	{ "artist":  "Charlie Puth", "runtime":  203, "dbID":  "152322", "ELEM":  5, "title":  "Attention", "starttime":  1500984426 }
	]
}
```

* Один или два FTP-сервера, на которые выгрузится XML-файл с метаданными от Джин.ValueServer.
* Один или два энкодера Omnia Z/IPStream или ProStream.
* RDS-кодер DEVA SmartGen.

Предварительные требования.
---------------------------
0. Для применения процедуры выгрузки на FTP необходимо установить модуль WinSCP для PowerShell:
```powershell
	# сохранить
Save-Module -Name WinSCP -Path <Path>
	# установить
Install-Module -Name WinSCP
	# показать команды
Get-Command -Module WinSCP
```
Процедура выгрузки на FTP использует команду ` Import-Module -Name WinSCP `
Предварительно выполните эту команду в PowerShell для проверки, что модуль импортируется. При соответствующем сообщении об ошибке скопируйте WinSCP.exe
из `%userprofile%\Documents\WindowsPowerShell\Modules\WinSCP\5.x.x.x\bin\` в `..\lib\`

Настройка.
---------------------------
1. Отредактируйте файл конфигурации *.example и сохраните его в "myradio.cfg" в папку со скриптом.
Не забудьте добавить `/` в конец FTP-пути. Если в адресе сервера FTP явно не указан порт в виде address:port , то будет использоваться порт по-умолчанию (:21).
В файле конфигурации строки, начинающиеся с [ и # не обрабатываются, их можно использовать как названия секций и комментарии.


2. Файл `runps.bat` нужен для запуска PowerShell-скрипта из Джина.ValueServer. Этот файл должен находиться в рабочей папке с PS-скриптом, например, в "C:\Program Files (x86)\Digispot II\Uploader"
В связи с особенностями запуска приложений из Джина, в `runps.bat` необходим явный переход в папку, где находится скрипт.
На рабочую папку должны быть даны права на чтение, запись, удаление папок и файлов.

В файле runps.bat находится:
```Batchfile
@echo off
cd "C:\Program Files (x86)\Digispot II\Uploader"
:: раскомментируйте строку для отладки - при каждом запуске в test.log будет сохраняться время запуска и файл конфигурации.
::echo %date% %time% %1 >> .\test.log
powershell -NoProfile -ExecutionPolicy bypass -File "uploader-2.ps1" %1
```

Алгоритм работы:
----------------

* PS-скрипт запускается из Джин.ValueServer через "костыль" `runps.bat` с именем файла конфигурации в виде обязательного параметра. Например: `runps myradio.cfg`
* В рабочей папке создаются папки .\LOG и .\TMP
* Получается текущее время **$scriptstart**, когда запустился скрипт. Поскольку есть возможность запускать несколько экземпляров скрипта, сохраняющих информацию в один лог, это значение текущего времени в дальнейшем используется как идентификатор всего, что связано с текущим запущенным экземпляром скрипта.
* Создаётся локальная копия XML-файла с суффиксом **$scriptstart**.
* Создаётся массив, в котором будут храниться идентификатор потока (такой же как файл конфигурации, например myradio.cfg) и найденные песни.
* Из всех веток с идентификаторами элемента ELEM_0 ... ELEM_23 выбираются объекты с типом фонограммы = 3 (песня).
* Для каждого объекта "песня" выбираются значения: **Type**, **dbID**, **Artist**, **Name**, **Starttime**, **Runtime**.
* Идентификатор каждого элемента (например, ELEM_6) разделяется на две части, правая часть конвертируется в десятичное число и сохраняется как порядковый номер элемента.
* Если в МБД используются пользовательские атрибуты (User Attributes) "Русский исполнитель" и "Русское название композиции", то в файле конфигурации в значениях RARTISTID и RTITLEID необходимо указать соответствующие им ID. Значения ID пользовательских атрибутов можно посмотреть в вашем выгружаемом XML от Value.Server:
```XML
<root>
  <ELEM_0>
    <Elem>
      <UserAttribs>
        <ELEM>
          <ID dt="i4">7</ID>
          <Name>Русский исполнитель</Name>
          <Value>АЛЛА ПУГАЧЁВА</Value>
        </ELEM>
        <ELEM>
          <ID dt="i4">17</ID>
          <Name>Русское название композиции</Name>
          <Value>ПРОСТИ, ПОВЕРЬ</Value>
        </ELEM>
      </UserAttribs>
```

* Значение **Artist** приводится к нижнему регистру, затем к TitleCase (первая буква заглавная, остальные строчные).
* Значение **Name** приводится к нижнему регистру, затем к TitleCase (первая буква заглавная, остальные строчные).
* Значение **Runtime** переводится из миллисекунд в секунды и округляется в бо́льшую сторону.
* Значение **Starttime** переводится из миллисекунд с начала суток в количество секунд с 1.01.1970 0:00:00 (UnixTime) и из полученного значения вычитается часовой пояс (-10800 сек. для GMT+3)
* Производится замена текста в строках **Artist** и **Name** по "таблице замены" - удаляются строки *PI_*, *ID_EP LIVE*, *NEW_*, *MD_*, *EDIT_*, нижние подчёркивания заменяются на пробел, два пробела заменяются на один, заменяются исключения в регистре букв типа *ABBA*, *LP*, *DJ*

* Если текущий элемент (**ELEM_0**) песня и его статус *Playing* и значение **dbID** не равно *null*, то готовый массив сортируется по полю ELEM, и в массиве оставляются только три элемента - текущая песня и две следующие.
* Массив со значениями песен конвертируется в JSON и сохраняется в json-файл с текущим временем скрипта **$scriptstart**.
* Если текущий json-файл не отличается от "последнего удачного", то программа завершает работу.
* Если текущий json-файл отличается от "последнего удачного" и в файле конфигурации задано действие `JSON=TRUE`, то происходит JSON POST и текущий json-файл сохраняется как "последний удачный".

* Получаются значения **Artist**, **Title** и **Type** для текущего элемента (ELEM_0).
* Загрузка радиотекста в RDS происходит, если текущий элемент (ELEM_0) имеет статус *Playing* и в файле конфигурации задано действие `RDS=TRUE`.
* Если значение типа текущего элемента равно *1* (реклама), то строка радиотекста составляется из значений адреса сайта и телефона из файла конфигурации. Значение RT+ при этом обнуляется.
* Если значение типа текущего элемента равно *2* (джингл), то строка радиотекста составляется из значения адреса сайта из файла конфигурации. Значение RT+ при этом обнуляется.
* Если значение типа текущего элемента равно *3* (джингл), то строка радиотекста составляется в формате *Artist - Name :: адрес сайта*. В строку RT+ при этом записываются значения, относящиеся к **Artist** и **Name** из строки радиотекста.
* Значение типа текущего элемента сравнивается с "последним удачным" значением типа. Если оно одинаковое (несколько джинглов или рекламных роликов подряд), то загрузка радиотекста в RDS прекращается, иначе в RDS-кодер с ip-адресом и портом из файла конфигурации отправляются строка RT и через 4 секунды строка RT+; значение типа текущего элемента сохраняется как "последнее удачное".

* Если текущий элемент (ELEM_0) имеет статус *Playing* и его тип "песня", то собирается строка для отправки в Omnia ProStream в формате "Artist - Name", а если тип "не песня", то строка будет пустой ("").
* Если в файле конфигурации задано действие `PROSTREAM1=TRUE`, то значение типа текущего элемента сравнивается с "последним удачным" значением типа. Если оно одинаковое (несколько джинглов или рекламных роликов подряд), то отправка метаданных в ProStream прекращается, иначе в ProStream с ip-адресом и портом из файла конфигурации отправляются текстовая строка в формате фильтра "Character Parser Sample" и значение типа текущего элемента сохраняется как "последнее удачное".
* Если в файле конфигурации задано действие `PROSTREAM2=TRUE`, то выполняется отправка метаданных во второй ProStream.

* Если в файле конфигурации задано действие `FTP1=TRUE`, и текущий элемент (ELEM_0) имеет статус *Playing*, и его тип "песня", и среди установленных модулей PowerShel есть WinSCP, то выполняется отправка на FTP локальной копии XML-файла под оригинальным именем.
* Если в файле конфигурации задано действие `FTP2=TRUE`, то выполняется локальной копии XML-файла на второй FTP.

* В лог-файл `.\LOG\%DATE%-myradio.cfg` сохраняются отчёты и комментарии о всех основных действиях скрипта.

Пример лога:
------------
```INI
17:52:02.495 : ** Script 20170726-175202-495 Started
17:52:02.729 : Now playing: 3/ Robin Schulz/James Blunt - Ok
17:52:02.948 : [*] Script 20170726-175202-495 finished normally
17:52:03.963 : ** Script 20170726-175203-963 Started
17:52:04.182 : Now playing: 3/ Robin Schulz/James Blunt - Ok
17:52:04.198 : JSON saved to C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175203-963.json.
17:52:04.979 : [+] 20170726-175203-963 JSON push engaged. Element: 3, Status: Playing, JSON=TRUE
17:52:04.979 : NOWPLAYING: 3/ Robin Schulz/James Blunt - Ok
17:52:04.979 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175203-963.rds-current.txt 
17:52:05.010 : [+] RDS string TEXT=Robin Schulz/James Blunt - Ok ** www.europaplus.ru sent to 127.0.0.1 : 1024
17:52:09.042 : [-] RDS send to 127.0.0.1 : 1024 result: Exception calling "Write" with "3" argument(s): "Unable to write data to the transport connection: An existing connection was forcibly closed by the remote host."
17:52:09.057 : [+] PROSTREAM1 string t=Robin Schulz/James Blunt - Ok
 sent to prostream-server1 : 6002
17:52:09.089 : [+] PROSTREAM2 string t=Robin Schulz/James Blunt - Ok
 sent to prostream-server2 : 6002
17:52:10.511 : [+] FTP1 upload of C:\Program Files (x86)\Digispot II\Uploader\tmp\EP-MSK2.xml.20170726-175203-963 to ftp1.hosting.local OK
17:52:13.339 : [+] FTP2 upload of C:\Program Files (x86)\Digispot II\Uploader\tmp\EP-MSK2.xml.20170726-175203-963 to ftp2.hosting.local OK
17:52:13.479 : [*] Script 20170726-175203-963 finished normally
17:53:37.701 : ** Script 20170726-175337-701 Started
17:53:37.904 : Now playing: 3/ Robin Schulz/James Blunt - Ok
17:53:37.935 : JSON saved to C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175337-701.json.
17:53:37.935 : [-] Script 20170726-175337-701 Previous and current JSONs are same
17:53:37.935 : [*] Script 20170726-175337-701 breaks
17:53:38.592 : ** Script 20170726-175338-592 Started
17:53:38.810 : Now playing: 2/  - Vilet
17:53:39.076 : [*] Script 20170726-175338-592 finished normally
17:53:39.732 : ** Script 20170726-175339-732 Started
17:53:39.951 : Now playing: 2/  - Vilet
17:53:39.967 : NOWPLAYING: 2/  - Vilet
17:53:39.967 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175339-732.rds-current.txt 
17:53:40.092 : [+] RDS string TEXT=www.europaplus.ru sent to 127.0.0.1 : 1024
17:53:44.154 : [+] RDS string RT+TAG=04,00,00,01,00,00,1,1 sent to 127.0.0.1 : 1024
17:53:44.170 : [+] PROSTREAM1 string t=
 sent to prostream-server1 : 6002
17:53:44.201 : [+] PROSTREAM2 string t=
 sent to prostream-server2 : 6002
17:53:44.389 : [*] Script 20170726-175339-732 finished normally
17:53:44.936 : ** Script 20170726-175344-936 Started
17:53:45.154 : Now playing: 2/  - Vilet
17:53:45.154 : NOWPLAYING: 2/  - Vilet
17:53:45.154 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175344-936.rds-current.txt 
17:53:45.264 : [-] Script 20170726-175344-936 Previous and current NOWPLAYING types are same (2). Skipping RDS processing.
17:53:45.264 : [*] Script 20170726-175344-936 breaks
17:53:45.279 : [-] Script 20170726-175344-936 Previous and current NOWPLAYING types are same (2). Skipping PROSTREAM1 processing.
17:53:45.279 : [*] Script 20170726-175344-936 breaks
17:53:45.483 : [*] Script 20170726-175344-936 finished normally
17:53:46.045 : ** Script 20170726-175346-045 Started
17:53:46.373 : Now playing: 2/  - J07 2016 Rapidfire V2
17:53:46.639 : [*] Script 20170726-175346-045 finished normally
17:53:47.186 : ** Script 20170726-175347-186 Started
17:53:47.467 : Now playing: 2/  - J07 2016 Rapidfire V2
17:53:47.483 : NOWPLAYING: 2/  - J07 2016 Rapidfire V2
17:53:47.483 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175347-186.rds-current.txt 
17:53:47.576 : [-] Script 20170726-175347-186 Previous and current NOWPLAYING types are same (2). Skipping RDS processing.
17:53:47.576 : [*] Script 20170726-175347-186 breaks
17:53:47.576 : [-] Script 20170726-175347-186 Previous and current NOWPLAYING types are same (2). Skipping PROSTREAM1 processing.
17:53:47.576 : [*] Script 20170726-175347-186 breaks
17:53:47.764 : [*] Script 20170726-175347-186 finished normally
17:53:48.311 : ** Script 20170726-175348-311 Started
17:53:48.623 : Now playing: 2/  - J07 2016 Rapidfire V2
17:53:48.623 : NOWPLAYING: 2/  - J07 2016 Rapidfire V2
17:53:48.623 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175348-311.rds-current.txt 
17:53:48.764 : [-] Script 20170726-175348-311 Previous and current NOWPLAYING types are same (2). Skipping RDS processing.
17:53:48.764 : [*] Script 20170726-175348-311 breaks
17:53:48.764 : [-] Script 20170726-175348-311 Previous and current NOWPLAYING types are same (2). Skipping PROSTREAM1 processing.
17:53:48.764 : [*] Script 20170726-175348-311 breaks
17:53:48.951 : [*] Script 20170726-175348-311 finished normally
17:53:49.889 : ** Script 20170726-175349-889 Started
17:53:50.108 : Now playing: 3/ Kadebostany - Mind If I Stay (Astero Remix)
17:53:50.389 : [*] Script 20170726-175349-889 finished normally
17:53:50.951 : ** Script 20170726-175350-951 Started
17:53:51.186 : Now playing: 3/ Kadebostany - Mind If I Stay (Astero Remix)
17:53:51.217 : JSON saved to C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175350-951.json.
17:53:51.561 : [+] 20170726-175350-951 JSON push engaged. Element: 3, Status: Playing, JSON=TRUE
17:53:51.561 : NOWPLAYING: 3/ Kadebostany - Mind If I Stay (Astero Remix)
17:53:51.561 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175350-951.rds-current.txt 
17:53:51.608 : [+] RDS string TEXT=Kadebostany - Mind If I Stay (Astero Remix) ** www.europaplus.ru sent to 127.0.0.1 : 1024
17:53:55.608 : [+] RDS string RT+TAG=04,00,11,01,14,29,1,1 sent to 127.0.0.1 : 1024
17:53:55.639 : [+] PROSTREAM1 string t=Kadebostany - Mind If I Stay (Astero Remix)
 sent to prostream-server1 : 6002
17:53:55.670 : [+] PROSTREAM2 string t=Kadebostany - Mind If I Stay (Astero Remix)
 sent to prostream-server2 : 6002
17:53:56.561 : [+] FTP1 upload of C:\Program Files (x86)\Digispot II\Uploader\tmp\EP-MSK2.xml.20170726-175350-951 to ftp1.hosting.local OK
17:53:59.514 : [+] FTP2 upload of C:\Program Files (x86)\Digispot II\Uploader\tmp\EP-MSK2.xml.20170726-175350-951 to ftp2.hosting.local OK
17:53:59.639 : [*] Script 20170726-175350-951 finished normally
17:56:53.145 : ** Script 20170726-175653-145 Started
17:56:53.395 : Now playing: 3/ Kadebostany - Mind If I Stay (Astero Remix)
17:56:53.458 : JSON saved to C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175653-145.json.
17:56:53.473 : [-] Script 20170726-175653-145 Previous and current JSONs are same
17:56:53.473 : [*] Script 20170726-175653-145 breaks
17:56:56.442 : ** Script 20170726-175656-442 Started
17:56:56.755 : Now playing: 3/ Kadebostany - Mind If I Stay (Astero Remix)
17:56:56.770 : JSON saved to C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175656-442.json.
17:56:56.786 : [-] Script 20170726-175656-442 Previous and current JSONs are same
17:56:56.802 : [*] Script 20170726-175656-442 breaks
17:56:57.458 : ** Script 20170726-175657-458 Started
17:56:57.692 : Now playing: 2/  - J07 2016 Rapidfire Dry
17:56:57.942 : [*] Script 20170726-175657-458 finished normally
17:56:58.536 : ** Script 20170726-175658-536 Started
17:56:58.755 : Now playing: 2/  - J07 2016 Rapidfire Dry
17:56:58.755 : NOWPLAYING: 2/  - J07 2016 Rapidfire Dry
17:56:58.755 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175658-536.rds-current.txt 
17:56:58.880 : [+] RDS string TEXT=www.europaplus.ru sent to 127.0.0.1 : 1024
17:57:02.927 : [-] RDS send to 127.0.0.1 : 1024 result: Exception calling "Write" with "3" argument(s): "Unable to write data to the transport connection: An existing connection was forcibly closed by the remote host."
17:57:02.942 : [+] PROSTREAM1 string t=
 sent to prostream-server1 : 6002
17:57:02.942 : [+] PROSTREAM2 string t=
 sent to prostream-server2 : 6002
17:57:03.161 : [*] Script 20170726-175658-536 finished normally
17:57:04.396 : ** Script 20170726-175704-396 Started
17:57:04.614 : Now playing: 3/ Alan Walker - Faded
17:57:04.864 : [*] Script 20170726-175704-396 finished normally
17:57:05.489 : ** Script 20170726-175705-489 Started
17:57:05.849 : Now playing: 3/ Alan Walker - Faded
17:57:05.880 : JSON saved to C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175705-489.json.
17:57:06.568 : [+] 20170726-175705-489 JSON push engaged. Element: 3, Status: Playing, JSON=TRUE
17:57:06.568 : NOWPLAYING: 3/ Alan Walker - Faded
17:57:06.568 : Temp NOWPLAYING file: C:\Program Files (x86)\Digispot II\Uploader\jsons\ep.cfg.20170726-175705-489.rds-current.txt 
17:57:06.599 : [+] RDS string TEXT=Alan Walker - Faded ** www.europaplus.ru sent to 127.0.0.1 : 1024
17:57:10.599 : [+] RDS string RT+TAG=04,00,11,01,14,05,1,1 sent to 127.0.0.1 : 1024
17:57:10.615 : [+] PROSTREAM1 string t=Alan Walker - Faded
 sent to prostream-server1 : 6002
17:57:10.615 : [+] PROSTREAM2 string t=Alan Walker - Faded
 sent to prostream-server2 : 6002
17:57:11.365 : [+] FTP1 upload of C:\Program Files (x86)\Digispot II\Uploader\tmp\EP-MSK2.xml.20170726-175705-489 to ftp1.hosting.local OK
17:57:14.271 : [+] FTP2 upload of C:\Program Files (x86)\Digispot II\Uploader\tmp\EP-MSK2.xml.20170726-175705-489 to ftp2.hosting.local OK
17:57:14.380 : [*] Script 20170726-175705-489 finished normally
```

Версии:
-------
v1.00 2015-10-09 отправка XML на удалённые FTP.
v1.01 2015-10-30 добавлено протоколирование результатов загрузки.
v2.00 2016-01-14 добавлен разбор XML на A/T.
v2.01 2016-11-17 добавлена оценка типа элемента (музыка/джингы/реклама); добавлена отправка в RDS-кодер DEVA.
v2.02 2016-11-18 добавлено окультуривание Artist/Title; добавлена поддержка RT+ для RDS; некоторые дополнительные проверки.
v2.03 2017-03-24 способ проверки хоста изменён с пинга на Microsoft PortQuery
v2.04 2017-03-29 добавлено удаление служебной информации из A/T; настройки теперь во внешнем файле конфигурации!
v2.05 2017-05-25 A/T и другие данные сохраняются в .json; отправка JSON на HTTP и выгрузка XML на FTP только если текущий тип элемента - музыка;
v2.06 2017-06-06 добавлена проверка, запущен ли другой экземпляр скрипта, чтобы избежать множественной отправки одинаковых данных (https://redmine.digispot.ru/issues/44826)
v2.07 2017-07-13 скрипт переписан на Windows Powershell; добавлена отправка A/T в Omnia ProStream; добавлено множество дополнительных проверок и условий.
v2.07.010 2017-12-26 количество найденных следующих песен ограничено двумя; добавлено использование русских A/T из пользовательских атрибутов.
