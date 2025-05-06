<#
.NOTES
    Copyright (c) Roman Ermakov <r.ermakov@emg.fm>
    Use of this sample source code is subject to the terms of the
    GNU General Public License under which you licensed this sample source code. If
    you did not accept the terms of the license agreement, you are not
    authorized to use this sample source code.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    THIS CODE IS PROVIDED "AS IS" WITH NO WARRANTIES.
    
.SYNOPSIS
    Sends DJin Current Playing metadata to some destinations
    
.DESCRIPTION
    Upload DJin Current Playing XML to FTP server
    Push DJin Current Playing metadata as JSON to HTTP server
    Saving DJin Current Playing to local JSON file for local web server
    Push DJin Current Playing Artist-Title to RDS encoder as RaioText and RadioText+
    Push DJin Current Playing Artist-Title to Omnia ProStream X/2

.LINK
    https://github.com/ykmn/uploader/v3/blob/master/readme.md

.EXAMPLE
    uploader3.ps1 config.cfg -force

.PARAMETER force
    Force upload operations even if the data is the same.

.PARAMETER cfg
    Configuration file name without ".json" extension

    * please validate json before use
    * notice double slashes \\ for each single slash \ in XML file path
{
    "XMLf":"\\\\tech-infoserv1\\c$\\XML\\UPLOAD\\EP-MSK2v3.xml",
    "rArtistID":    "8",
    "rTitleID":     "19",
    "altArtistID":  "8",
    "altTitleID":   "19",
    "_comment1":    "EP: 8/19/FALSE/8/19; RR: 7/17/TRUE/7/17; R7: 0/0/FALSE/0/0; DR: 7/17/FALSE/0/0",
    "DefaultAT":    "ru",
    "_comment2":    "если ru, то брать AT для RDS из пользовательских атрибутов",
    "AltAT":        "false",
    "_comment3":    "если TRUE, то в основных атрибутах находится транслит, а в пользовательских - русские AT, если FALSE, то основных атрибутах находятся русские AT",
    "jsonlocal": true,
    "ftp": [
        {
            "pass":     "password",
            "path":     "/ftproot/folder/",
            "server":   "127.0.0.1",
            "user":     "anonymous"
        },
        {
            "pass":     "password",
            "path":     "/ftp/",
            "server":   "localhost:21",
            "user":     "radio"
        }
    ],
    "jsoncustom": [
        {
            "jsonserver": "https://127.0.0.1:8080/handler"
        }
    ],
    "post": [
        {
            "server": "https://webhook.site/e362b6bf-d73b-4f5d-9697-092e23a4b102",
            "token": "1234567890"
        },
        {
            "server": "https://webhook.site/e362b6bf-d73b-4f5d-9697-092e23a4b102",
            "token": "0987654321"
        },
        {
            "server": "https://localhost:8089/post?priority=3",
            "token": "abcdefghijklmnopqrstuvwxyz"
        }
    ],
    "prostream": [
        {
            "port":     "6002",
            "server":   "localhost"
        },
        {
            "port":     "6002",
            "server":   "127.0.0.1"
        }
    ],
    "rds": [
        {
            "commercialText":   "Reklama: +7(495)620-4664",
            "device":           "SmartGen",
            "address":          "localhost",
            "NonMusic":         "Europa Plus Moscow",
            "port":             "5001",
            "porttype":         "UDP",
            "site":             "www.europaplus.ru"
        },
        {
            "commercialText":   "Reklama: +7(495)620-4664",
            "device":           "LinkShare",
            "address":          "127.0.0.1",
            "NonMusic":         "Europa Plus Moscow",
            "port":             "5000",
            "porttype":         "TCP",
            "site":             "www.europaplus.ru"
        }

    ]
}


#>

<#
uploader.ps1

v1.00 2015-10-09 sending xml to remote FTP sites.
v1.01 2015-10-30 logging send results.
v2.00 2016-01-14 implemented xml parsing.
v2.01 2016-11-17 implemented evaluation element type (music/jingle/commercial); added sending to DEVA RDS-coder.
v2.02 2016-11-18 Capitalizing Artist And Title; implemented RT+ field; added some checkups.
v2.03 2017-03-24 changing host probe from ping to Microsoft PortQuery
v2.04 2017-03-29 more cleanup for Camel Case; settings are now in external config file!
v2.05 2017-05-25 extracting A/T and other values to .json; pushing JSON to HTTP and uploading to FTP only if current type is music;
v2.06 2017-06-06 checking for another instance of script, added "fun with flags".
v2.07 2017-07-26 script remixed for Windows Powershell: changed everything - see README.md
V3.00 2020-02-12 discard use of ValueServer, using XML from DJin cur_playing.xml instead ("max data" v3.0 type).
V3.01 2020-05-13 optimized logging; changed metadata source inside XML.
V3.02 2022-02-10 Added RDS for Sound4 Link&Share protocol, some SmartGen RT+ cleanup.
V3.03 2022-07-11 XMLs with Retransmission Blocks now upload to FTP too.
V3.04 2024-11-13 Saving Artist-Title to local JSON for videowall output.
V3.05 2024-11-19 Refactoring; sending XML with POST request to 2 servers. BREAKING CHANGE: settings in .cfg shoulb be as PARAMETER = value (was PARAMETER=value)
V3.06 2024-12-23 BREAKING CHANGE: settings are now in .json; array with 'unlimited' recepients of each receiver type; changed FTP method; fixed cyrillic AT for jsonlocal; translit for ProStream.
#>

# Handling command-line parameters
param (
    #[Parameter(Mandatory=$true)][string]$cfg = "test.cfg.json",
    [Parameter(Mandatory=$true)][string]$cfg,
    [Parameter(Mandatory=$false)][switch]$force,
    [Parameter(Mandatory=$false)][switch]$test
)
# If $force set to $true then we didn't compare jsons and forcing push to webserver and RDS

#####################################################################################
Clear-Host
Write-Host "`nUploader 3.06.004 <r.ermakov@emg.fm> 2025-04-22 https://github.com/ykmn/uploader"
Write-Host "This script uses Extended cur_playing.XML from DJin X-Player.`n"

# If $test set to $true then temporary xmls and jsons will not be removed
#if ($force -eq $true) { $forced = "FORCED" } else {$forced = "" }
$forced = ""

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "`n`nThis script works with Windows PowerShell 5.0 or newer.`nPlease upgrade!`n"
    Break
}

#[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
#[Console]::OutputEncoding = [System.Text.Encoding]::Default
#[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#[string]$currentdir = Get-Location
$currentdir = Split-Path $MyInvocation.MyCommand.Path -Parent
Write-Host "Current folder:" $currentdir
$sOutFile =""
#Set-Location -Path "C:\Program Files (x86)\Digispot II\Uploader\"
#Set-Location -Path "C:\Users\r.ermakov\Documents\GitHub\uploader\"


function New-FTPUpload2  {
param ($ftp, $user, $pass, $xmlf, $remotepath)
    Write-Host "FTP settings:" -BackgroundColor DarkGreen
    Write-Host "original file for upload -" $xmlf.FullName
    Write-Host "local copy of a file for upload -" $dest.Fullname
    # Make sure you have "/" in FTPPATH1 on your config flie
    $remotepath = $remotepath + $xmlf.Name
    Write-Host "remote path -" $remotepath
    $ftp,$port = $ftp.split(':')
    Write-Host Uploading to $ftp port $port
    try {
    # Setup session options
        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
            Protocol = [WinSCP.Protocol]::ftp
            HostName = $ftp
            UserName = $user
            Password = $pass
            PortNumber = $port
            Timeout = "5"
            #SshHostKeyFingerprint = "ssh-rsa 2048 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
        }
        $session = New-Object WinSCP.Session
        try {
            # Connect
            $session.Open($sessionOptions)
            # Upload files
            $transferOptions = New-Object WinSCP.TransferOptions
            $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
            $transferResult = $session.PutFiles($dest.FullName, $remotepath)
            # Throw on any error
            $transferResult.Check()
            # Print results
            foreach ($transfer in $transferResult.Transfers) {
                $now = Get-Date -Format HH:mm:ss.fff
                Write-Log -message "[+] : $scriptstart $feature $forced upload of $($transfer.FileName) to $ftp OK" -color Green
            }
        } finally {
            # Disconnect, clean up
            $session.Dispose()
        }
    } catch [Exception] {
        Write-Log -message "[-] : $scriptstart $feature $forced error uploading to to $ftp : $($_.Exception.Message)" -color Red
    }
}

function New-TCPSend {
param ($feature, $remoteHost, $port, $message)
# Sending to tcp port
    $sock = New-Object System.Net.Sockets.TcpClient($remoteHost, $port)
    $encodedData = [System.Text.Encoding]::ASCII.GetBytes($message)
    $Error.Clear()
    try { 
        $stream = $sock.GetStream()
        $stream.Write($encodedData, 0, $encodedData.Length)
        $sock.Close()
        $now = Get-Date -Format HH:mm:ss.fff
        Write-Log -message "[+] : $scriptstart $feature $forced string $message sent to $remotehost : $port" -color Green
    } catch {
        "oops"
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage "///" $FailedItem
        Write-Host "TCP-Client errorcode:" $Error -BackgroundColor Red -ForegroundColor White
        $now = Get-Date -Format HH:mm:ss.fff
        Write-Log -message "[-] : $scriptstart $feature $forced error tcp-sending to $remotehost : $port result: $Error" -color Red
    }
}

function New-UDPSend {
param ($feature, $remoteHost, $port, $message)
# Sending to udp port
    $Error.Clear()
    try { 
        #[int] $Port = 20000
        $Address = [system.net.IPAddress]::Parse($remoteHost)

        # Create IP Endpoint
        $End = New-Object System.Net.IPEndPoint $address, $port

        # Create Socket
        $saddrf   = [System.Net.Sockets.AddressFamily]::InterNetwork
        $stype    = [System.Net.Sockets.SocketType]::Dgram
        $ptype    = [System.Net.Sockets.ProtocolType]::UDP
        $sock     = New-Object System.Net.Sockets.Socket $saddrf, $stype, $ptype
        $sock.TTL = 26

        # Connect to socket
        $sock.Connect($end)

        # Create encoded buffer
        $Enc     = [System.Text.Encoding]::ASCII
        $Buffer  = $Enc.GetBytes($message)

        # Send the buffer
        $Sent   = $sock.Send($Buffer)
        $sock.Close()
        $now = Get-Date -Format HH:mm:ss.fff
        Write-Log -message "[+] : $scriptstart $feature $forced string $message sent ( $Sent bytes) to $remotehost : $port" -color Green
} catch {
        "oops"
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage "///" $FailedItem
        Write-Host "TCP-Client errorcode:" $Error -BackgroundColor Red -ForegroundColor White
        $now = Get-Date -Format HH:mm:ss.fff
        Write-Log -message "[-] : $scriptstart $feature $forced error udp-sending to $remotehost : $port result: $Error" -color Red
    }
}

function Convert2Latin($inString) {
    # Обрезаем пустые пробелы по краям
    $inString = $inString.Trim()
    
    # Определяем таблицу соответствия
    $char_ru="а","А","б","Б","в","В","г","Г","д","Д","е","Е","ё","Ё","ж", "Ж", "з","З","и","И","й","Й","к","К","л","Л","м","М","н","Н","о","О","п","П","р","Р","с","С","т","Т","у","У","ф","Ф","х", "Х", "ц", "Ц", "ч", "Ч", "ш", "Ш", "щ",  "Щ","ъ","Ъ","ы","Ы","ь","Ь","э","Э","ю", "Ю", "я", "Я"
    $char_en="a","A","b","B","v","V","g","G","d","D","e","E","e","E","zh","Zh","z","Z","i","I","y","Y","k","K","l","L","m","M","n","N","o","O","p","P","r","R","s","S","t","T","u","U","f","F","kh","Kh","ts","Ts","ch","Ch","sh","Sh","sch","Sch","","","y","Y","","",  "e","E","yu","Yu","ya","Ya"
    $TempString = ""
    
    # Перебираем слово по буквам
    for ($i = 0; $i -lt $inString.Length; $i++)
    { 
        $t = -1
        # Выясняем позицию заменямой буквы в массиве
        Do {$t = $t+1} Until (($inString[$i] -ceq $char_ru[$t]) -or ($t -eq 100))
        # Дополняем строку конвертированного? одновременно производя замену русской буквы на английскую
        $TempString = $TempString + ($inString[$i] -creplace $char_ru[$t], $char_en[$t])
    }
    return $TempString
}

# Log management
function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$false)][string]$color
    )
    $PSscript = Split-Path $MyInvocation.ScriptName -Leaf
    #$logfile = $currentdir + "\log\" + $(Get-Date -Format yyyy-MM-dd) + "-" + $MyInvocation.MyCommand.Name + ".log"
    #$LogFile = $currentdir + "\log\" + $(Get-Date -Format yyyy-MM-dd) + "-" + $PSscript + ".log"
    $LogFile = $currentdir + "\log\" + $(Get-Date -Format yyyy-MM-dd) + "-" + $cfg + ".log"
    $LogNow = Get-Date -Format HH:mm:ss.fff
    $message = "$LogNow : " + $message
    if (!($color)) {
        Write-Host $message    
    } else {
        Write-Host $message -ForegroundColor $color
    }
    $message | Out-File $LogFile -Append -Encoding "UTF8"
}

if (!(Test-Path $currentdir"\"$cfg".json")) {
    Write-Host "No config file found."
    Break
}


# Reading settings from .cfg.json file to $h array
# Since 3.06.000 settings are in .json format
$settings = Get-Content -Raw $cfg".json" | ConvertFrom-Json

## obsolete PARAMETER = VALUE settings parser
# Get-Content $cfg | ForEach-Object -begin { $h=@{} } -process {
#     $k = [regex]::split($_,' = ');
#     if (($k[0].CompareTo("") -ne 0) `
#       -and ($k[0].StartsWith("[") -ne $True) `
#       -and ($k[0].StartsWith("#") -ne $True) )
#     {
#         $h.Add($k[0], $k[1])
#     }
# }

Write-Host "Using configuration from $cfg"
Write-Host

# Setup folders structure
if (!(Test-Path $currentdir"\log")) {
    New-Item -Path $currentdir"\log" -Force -ItemType Directory | Out-Null
}
if (!(Test-Path $currentdir"\history")) {
    New-Item -Path $currentdir"\history" -Force -ItemType Directory | Out-Null
}
if (!(Test-Path $currentdir"\tmp")) {
    New-Item -Path $currentdir"\tmp" -Force -ItemType Directory | Out-Null
}
if (!(Test-Path $currentdir"\jsons")) {
    New-Item -Path $currentdir"\jsons" -Force -ItemType Directory | Out-Null
}
$scriptstart = Get-Date -Format yyyyMMdd-HHmmss-fff
Write-Log -message "*** : $scriptstart Script started $forced"

# Creating copy of XML file for processing
#$xmlfile = $h.Get_Item("XMLF")
$xmlfile = $settings.XMLF
$xmlf = Get-ChildItem -Path $xmlfile
$dest = $currentdir + "\tmp\" + $xmlf.Name + "." + $scriptstart
if (!(Test-Path $xmlf)) {
    Write-Log -message "[-] : $scriptstart No XML file found." -color Red
    Break
}
Write-Host "Copying $xmlf" -NoNewline
Write-Host " to $dest..."
Write-Host

Copy-Item -Path $xmlf -Destination $dest -Force -Recurse
Copy-Item -Path $xmlf -Destination $xmlf".bak" -Force -Recurse
# Parsing songs and saving to json
$dest = Get-ChildItem -Path $dest
Write-Host "Searching for songs in XML:" $dest.FullName
Write-Host

# Here goes replacement table
$ReplacementTable = @{
    '&Quot;' = '"';
    '&Apos;' = "'";
    '&Amp;' = '&';
    'Pi ' = '';
    'Pi_' = '';
    'New_' = '';
    'Md_' = '';
    'Edit_' = '';
    '_' = ' ';
    'Dj ' = 'DJ ';
    'Thk' = 'THK';
    ' Ft.' = ' feat.';
    'Feat.' = 'feat.';
    'Ajr' = 'AJR';
    'Lp' = 'LP';
    'Abba' = 'ABBA';
    'MoDjo' = 'Modjo';
    'Jp' = 'JP';
    'Mccartney' = 'McCartney';
    'Onerepublic' = 'OneRepublic';
    ' Vs' = ' vs.';
    'Sos ' = 'SOS ';
    'Dcne' = 'DCNE';
    '  ' = ' '
    };

# Reading XML
#[string]$dest1 = $dest
#[xml]$xmlfile = Get-Content -Path $dest1
$xmlfile = (Select-Xml -Path $dest -XPath / ).Node
$xmlfile.PreserveWhitespace = $false




##############################
# CURRENT
##############################

# Getting current A/T
$elem = $xmlfile.ELEM_LIST.ChildNodes[0]
$type = $elem.Elem.FONO_INFO.Type.'#text'
$artist = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Artist
$title = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Name
$dbid = $elem.Elem.FONO_INFO.dbID.'#text'
$status = $elem.Status
$retransmission = $elem.RETRANSMISSION

Write-Host "Retransmission type:" $retransmission -BackgroundColor Yellow -ForegroundColor Black


# get UserAttribs Russian Artist and Title IDs from config
if ($settings.altat -eq $true) { # кириллица в пользовательских полях карточки
    Write-Host "Russian Artist and Title expected to be in UserAttribs" -BackgroundColor Yellow -ForegroundColor Black
    ForEach ($userattr in $elem.Elem.UserAttribs.ChildNodes) {
    Write-Host $userattr.Name  -BackgroundColor Red -NoNewline
    Write-Host $userattr.ID.'#text' " : "  -BackgroundColor Blue -NoNewline

    # get UserAttribs Russian Artist and Title IDs from config
        if ($userattr.ID.'#text' -eq $settings.altartistid) {
            # Get cyrillic artist from UserAttribs
            $altartist = $userattr.Value
            Write-Host $altartist -BackgroundColor DarkGreen
            if ($altartist) { $artist = $altartist }
        }
        if ($userattr.ID.'#text' -eq $settings.alttitleid) {
            # Get cyrillic title from UserAttribs
            $alttitle = $userattr.Value
            Write-Host $alttitle -BackgroundColor DarkGreen
            if ($alttitle) { $title = $alttitle }
        }
    }
}


# If ; in Artist then artist should be inside name
<#
if (Select-String -pattern ";" -InputObject $artist) {
    $now = Get-Date -Format HH:mm:ss.fff
    Write-Log -message "    : Artist $artist contains ';' - artist will be disabled."
    Write-Host "Artist $artist contains ';' - artist will be disabled." -ForegroundColor Yellow
    $artist=""
}
#>

Write-Host DETECTED CURRENT SONG: -BackgroundColor Yellow -ForegroundColor Black
Write-Host Type:$type / Artist:$artist / Title:$title / DBid:$dbid -BackgroundColor Yellow -ForegroundColor Black

# Culture and replacements for A/T
ForEach ($i in $ReplacementTable.Keys) {
    # If variable defined
        if ($artist) { $artist = $artist -replace $i, $ReplacementTable[$i] }
        if ($title) { $title = $title -replace $i, $ReplacementTable[$i] }
}
if ($artist -ne $null) {
    $artist = (Get-Culture).TextInfo.ToTitleCase($artist.ToLower())
    $artist = $artist.Trim()
} else { $artist = "" }
if ($title -ne $null) { 
    $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())
    $title = $title.Trim()
} else { $title = "" }
ForEach ($i in $ReplacementTable.Keys) {
    # if variable defined
        if ($artist) { $artist = $artist.replace($i, $ReplacementTable[$i]) }
        if ($title) { $title = $title.replace($i, $ReplacementTable[$i]) }
}

# Now we have $artist $title $type of "now playing" ELEM_0
Write-Log -message "    : $scriptstart Now $status : $type/ $artist - $title" -color Cyan
Write-Host
Write-Host STORING NOW PLAYING SONG: -BackgroundColor Yellow -ForegroundColor Black
Write-Host Type:$type / Artist:$artist / Title:$title / DBid:$dbid -BackgroundColor Yellow -ForegroundColor Black

# Saving history file
$historyFile = $currentdir + "\history\" + $(Get-Date -Format yyyy-MM-dd) + "-" + $cfg + "-history.txt"
$LogNow = Get-Date -Format HH:mm:ss.fff
$message = $(Get-Date -Format HH:mm:ss.fff) + " /" + $type + "/ " + $artist + " - " + $title
$message | Out-File $historyFile -Append -Encoding "UTF8"



# Storing current AT for ProStream and RDS
$cArtist = $artist
$cTitle = $title

##### end of CURRENT section
############################




##############################
# JSONLOCAL
##############################
if ( `
    ($settings.JSONLOCAL -eq "true") `
    -and ($status -eq "playing") `
) {
        $feature = "JSONLOCAL"
        Write-Host
        Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor Black
        Write-Host

        if ($type -eq "3") {
            # it's a song
            # Restoring AT
            $artist = $cArtist
            $title = $cTitle
            $at = $($artist +" - "+ $title).ToUpper()
        } else {
            # it is jingle or news or commercial
            $at = ""
        }

        $current = @{
            at = $at
            dbID = $dbid
            artist = $artist
            title = $title
        }

    $slOutFile = $currentdir + "\jsons\" + $cfg + ".local.json"

    # replacing unexpectedly serialized symbols
    $json = (ConvertTo-Json -InputObject ($current)) -replace '\\u0026', '&' `
                                                     -replace '\\u0027', "'" `
                                                     -replace '\\u003c', '<' `
                                                     -replace '\\u003e', '>'
    Write-Host "Ready to write JSON Local to $slOutFile :" -ForegroundColor DarkGreen
    $json
    # trick to save UTF-8 file without BOM
    [IO.File]::WriteAllLines($slOutFile, $json)
    Write-Log -message "    : $scriptstart LOCALJSON saved to $slOutFile."

}

##############################
# POST
##############################
# https://docs.hostingradio.ru/books/metadannye/page/nastroika-otpravki-metadannyx-iz-digispot-post-zaprosom
if ( `
    ( ($settings.post.Length -gt 0) `
	-and ($status -eq "playing") `
    -or ($forced -eq "FORCED") )`
) {
    foreach ( $post in $settings.post ) {
        $feature = "XML POST"
        $index = [array]::IndexOf($settings.post, $post)+1      # starting from 0
        Write-Host
        Write-Host "---- Running $feature $index ----" -BackgroundColor DarkGreen -ForegroundColor Black
        Write-Host
        
        $token = $post.token
        $header = @{
            Authorization="Bearer $token";
            ContentType="application/xml";
            Charset="UTF-8"
        }
        $uri = $post.server
        Write-Host "Ready to post XML to $uri :" -ForegroundColor DarkGreen
        $Error.Clear()
        try { 
            Write-Log -message "[+] : $scriptstart $feature $index $forced started to $uri" -color Green
            Invoke-WebRequest -Uri $uri -Headers $header -ContentType "application/xml" -Method POST -Body $xmlfile
        } catch { 
            Write-Host "Webrequest errorcode:" $Error -BackgroundColor Red -ForegroundColor White
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Log -message "[-] : $scriptstart $feature $index $forced to $uri error: $Error" -color Red
        }
        Write-Log -message "    : $scriptstart $feature $index $forced operation done."
    }
}


##############################
# CUSTOM JSON
##############################
# If current element is a song and playing
# then do json stuff - convert, save and upload.
# RDS and FTP goes independently.
if ( `
    ( ($settings.jsoncustom.Length -gt 0) `
	-and ($status -eq "playing") `
    -and ($type -eq "3") `
    -or ($forced -eq "FORCED") )`
) {
    foreach ( $post in $settings.jsoncustom ) {
        $index = [array]::IndexOf($settings.jsoncustom, $post)+1
        $feature = "JSONCUSTOM"
        Write-Host
        Write-Host "---- Running $feature $index ----" -BackgroundColor DarkGreen -ForegroundColor Black

        # Creating songs array for JSON
        $stream = @{stream = $cfg}
        [array]$songs = @();

        <# Required json format:
        { "stream":  "myradio.cfg",
        "songs":  [
            { "artist":  "Arilena Ara", "runtime":  149, "dbID":  "151597", "title":  "Nentori (Beverly Pills Remix)", "starttime":  1500984064 },
            { "artist":  "Nickelback", "runtime":  197, "dbID":  "1274", "title":  "If Everyone Cared", "starttime":  1500984223 },
            { "artist":  "Charlie Puth", "runtime":  203, "dbID":  "152322", "title":  "Attention", "starttime":  1500984426 }
        ]
        }    #>

        Write-Output "ELEMENTS LIST:"
        Write-Output $xmlfile.ELEM_LIST.ELEM | Format-Table

        # Filling the array of next-up songs (Type=3)
        ForEach ( $elem in $xmlfile.ELEM_LIST.ChildNodes  | Where-Object {$_.Elem.FONO_INFO.Type.'#text' -eq '3'} ) {
            $type = $elem.Elem.FONO_INFO.Type.'#text'
            $artist = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Artist
            $title = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Name
            $dbid = $elem.Elem.FONO_INFO.dbID.'#text'
            Write-Host Type:$type / Artist:$artist / Title:$title / DBid:$dbid -BackgroundColor Yellow -ForegroundColor Black


            # if ; in Artist then artist should be inside Name
        <#
            if (Select-String -pattern ";" -InputObject $artist) {
                $now = Get-Date -Format HH:mm:ss.fff
                Write-Log -message "    : Artist $artist contains ';' - artist will be disabled."
                Write-Host "Artist $artist contains ';' - artist will be disabled." -ForegroundColor Yellow
                $artist=""
            }
        #>

            # Searching for Russian Artist/Title
            # Your MDB may have translit in main fields and cyrillic on UserAttribs
            # If so use ALTAT=TRUE in .cfg, check for correct ID in UserAttribs .XML section,
            # and set therse values in .cfg
            # <UserAttribs>
            #    <ELEM><ID dt="i4">7</ID>
            #          <Name>Русский исполнитель</Name><Value>Алла Пугачева</Value></ELEM>
            #    <ELEM><ID dt="i4">17</ID>
            #          <Name>Русское название композиции</Name><Value>Прости, поверь</Value></ELEM>
            # </UserAttribs>
            #
            # If your MDB have cyrillic in main fields please use ALTAT=FALSE,
            # and AT will be transliterated for RDS.
            $altat = $settings.AltAT
            $altartistid = $settings.ALTARTISTID
            $alttitleid = $settings.ALTTITLEID

            Write-Host "Search for UserAttribs:"
            ForEach ($userattr in $elem.Elem.UserAttribs.ChildNodes) {
                Write-Host " " $userattr.Name " " -BackgroundColor Red -NoNewline
                Write-Host " " $userattr.ID.'#text' " " -BackgroundColor Blue -NoNewline
                # get UserAttribs Russian Artist and Title IDs from config
                if ($altat -eq "TRUE") { # кириллица в пользовательских полях карточки
                    if ($userattr.ID.'#text' -eq $altartistid) {
                        # Get cyrillic artist from UserAttribs
                        $altartist = $userattr.Value
                        Write-Host " " $altartist " " -BackgroundColor DarkGreen
                        if ($altartist) { $artist = $altartist }
                    }
                    if ($userattr.ID.'#text' -eq $alttitleid) {
                        # Get cyrillic title from UserAttribs
                        $alttitle = $userattr.Value
                        Write-Host " " $alttitle " " -BackgroundColor DarkGreen
                        if ($alttitle) { $title = $alttitle }
                    }
                }
            }

            # Culture and replacements for A/T
            ForEach ($i in $ReplacementTable.Keys) {
                # if variable defined
                    if ($artist) { $artist = $artist.replace($i, $ReplacementTable[$i]) }
                    if ($title) { $title = $title.replace($i, $ReplacementTable[$i]) }
            }
            if ($artist -ne $null) {
                $artist = (Get-Culture).TextInfo.ToTitleCase($artist.ToLower())
                $artist = $artist.Trim()
            } else { $artist = "" }
            if ($title -ne $null) {
                $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())
                $title = $title.Trim()
            } else { $title = "" }
            ForEach ($i in $ReplacementTable.Keys) {
                # if variable defined
                    if ($artist) { $artist = $artist.replace($i, $ReplacementTable[$i]) }
                    if ($title) { $title = $title.replace($i, $ReplacementTable[$i]) }
            }

            # Getting time and converting to Unix Time
            # starttime = XML value in milliseconds from 0:00 today
            # $unixstarttime = value in seconds from 1.01.1970 0:00
            # -10800 = corrects UTC +3 in seconds
            [int]$starttime = $elem.Elem.StartTime.'#text'
            [int]$runtime = [math]::Floor([decimal]$elem.Elem.Runtime.'#text' / 1000)
            $utoday = Get-Date -Format dd/MM/yyyy | Get-Date -UFormat %s
            [int]$unixstarttime = [int][double]$utoday + [int](([int][double]$starttime) / 1000) -10800

            Write-Host "Element:" $artist "-" $title
            #Write-Host "Values: " $type"/"$dbid"/"$artist"/"$title"/"$unixstarttime"/"$runtime"`n"
            $current = @{
                dbID = $dbid
                artist = $artist
                title = $title
                starttime = $unixstarttime
                runtime = $runtime
            }
            
            $currentobj = New-Object PSObject -Property $current
            [array]$songs += $currentobj
            Write-Host "Current:" $currentobj -BackgroundColor DarkGreen | Format-Table 
            #Write-Host "Songs:  " $songs -BackgroundColor DarkGreen | Format-Table
            Write-Host
        }

        # Show what we got in array
        Write-Host "We have @songs:"
        @($songs) | Format-Table

        # Trimming songs array to current and two next-up elements
        if ($songs.Count -ge 3) {
            $songs = $songs #| Sort-Object -Unique starttime
            $songs = $songs[0,1,2]
        }
        Write-Host "Trimming songs array to current and two next-up Song elements:"
        @($songs) | Format-Table

        # File $sOutFile is json for current script;
        # File $oOutFile if json of last successfull script
        $sOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".json"

        $oOutFile = $currentdir + "\jsons\" + $cfg + ".json"
        if ((Test-Path $oOutFile) -eq $false) {
            Write-Log -message "[-] : $scriptstart No stream JSON found. Creating blank file"
            New-Item -ItemType File -Path $oOutFile
            Add-Content -Path $oOutFile -Value " blank file"
        }

        # Adding table @($songs) to array $stream
        $stream.Add("songs",@(@($songs)))

        # Converting table @($songs) to json and saving to file
        Write-Host Songs: $songs
        
        $json = ConvertTo-Json -InputObject ($stream)
        $json | Out-File -FilePath $sOutFile
        Write-Log -message "    : $scriptstart JSON saved to $sOutFile."

        # Compare current .json and last .json
        if ( `
            ((Compare-Object $(Get-Content $sOutFile) $(Get-Content $oOutFile) ) -eq $null) `
            -and ($force -ne $true) `
        ) {
            Write-Host "Previous and current JSONs are same" -ForegroundColor Yellow
            Write-Log -message "[x] : $scriptstart $forced Previous and current JSONs are same" -color Red
            Remove-Item -Path $dest
            Remove-Item -Path $sOutFile
            Write-Log -message "[x] : $scriptstart $forced Script breaks" -color Red
            Break
        } else {
            Copy-Item -Path $sOutFile -Destination $oOutFile -Force -Recurse
        }

        # Pushing json to hosting
        Write-Host
        Write-Host "Ready to send $feature :" -ForegroundColor DarkGreen
        Write-Host $json

        # Converting to UTF-8
        $json = [System.Text.Encoding]::UTF8.GetBytes($json)

        $jsonserver = $settings.jsoncustom.jsonserver
        $Error.Clear()
        try { 
    #            Invoke-Command -ScriptBlock {Invoke-WebRequest -Uri $jsonserver -Method POST -Body $json -ContentType "application/json"} -AsJob
            Invoke-WebRequest -Uri $jsonserver -Method POST -Body $json -ContentType "application/json"
            Write-Host "JSONCUSTOM push engaged. AT: $artist $title Element:"$type", Status:"$status
            Write-Log -message "[+] : $scriptstart $feature $index $forced push engaged. AT: $artist $title Element: $type, Status: $status)" -color Green
        } catch { 
            Write-Host "Webrequest errorcode:" $Error -BackgroundColor Red -ForegroundColor White
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Log -message "[-] : $scriptstart $feature $index $forced push error: $Error" -color Red
        }
        # Leave temp files if debug
        if (!$test) { Remove-Item -Path $sOutFile }
    } 
}

##############################
# PROSTREAM
##############################

# Restoring AT
$artist = $cArtist
$title = $cTitle

# Sending current song to PROSTEAM
if ( `
    ( ($settings.ProStream.Length -gt 0) `
	-and ($status -eq "playing") `
    -or ($forced -eq "FORCED") )`
) {
    foreach ( $post in $settings.ProStream ) {
        $feature = "PROSTREAM"
        $index = [array]::IndexOf($settings.ProStream, $post)+1
        Write-Host
        Write-Host "---- Running $feature $index ----" -BackgroundColor DarkGreen -ForegroundColor Black

        $remoteHost = $post.server
        $port = $post.port
        # Is it jingle or commercial?
        if ($samenowplaying -eq $true) {
            Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
            Write-Log -message "[x] : $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing." -color Yellow
            # Deleting current NOWPLAYING
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
        } else {
            Write-Host
            Write-Host "---- Ready to send $feature :" -ForegroundColor DarkGreen
            Write-Host
            if ($altat -eq "ALT") { # кириллица в пользовательских полях карточки
    #                $artist = $altartist
    #                $title = $alttitle
            }
            if ($type -eq "3") {
                $artist = Convert2Latin($artist)
                $title = Convert2Latin($title)
                $message = "t=" + $artist + " - " + $title + "`n" ;
                $samenowplaying = $false;
            } else {
                $message = "t=`n"
            }
            Write-Log -message "    : $scriptstart ProStream Now Playing: $type/ $artist - $title" -color Yellow
        
            Write-Host "$feature $index Message:" $message -BackgroundColor Yellow -ForegroundColor Black
            New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            #Remove-Item -Path $csOutFile.FullName
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
        }
    }
}



##############################
# RDS
##############################

# Restoring AT
$artist = $cArtist
$title = $cTitle

# Sending current song to RDS
if ( `
    ( ($settings.RDS.Length -gt 0) `
	-and ($status -eq "playing") `
    -or ($forced -eq "FORCED") )`
) {
    foreach ( $post in $settings.RDS ) {
        $index = [array]::IndexOf($settings.RDS, $post)+1
        $feature = "RDS"
        Write-Host
        Write-Host "---- Running $feature $index ----" -BackgroundColor DarkGreen -ForegroundColor Black
        Write-Host
        
        # Saving NOWPLAYING to file
        $csOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".rds-current.txt"
        $coOutFile = $currentdir + "\jsons\" + $cfg + ".rds-current.txt"
        if ((Test-Path $coOutFile) -eq $false) {
            Write-Log -message "[-] : $scriptstart No NOWPLAYING file found. Creating file"
            $type | Out-File -FilePath $coOutFile
        }

        # Reading RDS config
        $port = $post.port
        $remoteHost = $post.address
        $rdsporttype = $post.porttype
        $rdssite = $post.site
        $rdscommercial = $post.commercialText
        $rdsnonmusic = $post.NonMusic
        if ( ($post.device -eq "8700i") -or `
            ($post.device -eq "SmartGen") -or `
            ($post.device -eq "LinkShare") ) {
            $rdsdevice = $post.device
        }

        $artist = Convert2Latin($artist)
        $title = Convert2Latin($title)
        Write-Log -message "    : $scriptstart Transliterated artist $artist and title $title"

        $type | Out-File -FilePath $csOutFile
        Write-Log -message "    : $scriptstart RDS Now Playing: $type/ $artist - $title" -color Yellow
        Write-Log -message "    : $scriptstart Temp NOWPLAYING file: $csOutFile "

        # Compiling RT/RT+ strings for different element types
        if ($type -eq '1') {
        # COMMERCIAL
            if ($rdsdevice -eq "SmartGen") {
                [string]$message = 'TEXT='+$rdscommercial +' ** '+$rdssite
                [string]$rtplus = "RT+TAG=04,00,00,01,00,00,0,0"
                # RT+ last 0,0: ItemRunning 0, Timeout 0min
            }
            if ($rdsdevice -eq "8700i") {
                [string]$message = 'RT='+$rdscommercial +' ** '+$rdssite
                [string]$rtplus = ""
            }
            if ($rdsdevice -eq "LinkShare") {
                [string]$message = 'LOGIN admin,admin^RDS.RT='+$rdscommercial +' ** '+$rdssite+"^LOGOUT^"
                [string]$rtplus = ""
            }
            
            
            # Сompare current NOWPLAYING TYPE and last NOWPLAYING TYPE
            Write-Host "Previous Now Playing Type:"
            Get-Content $coOutFile
            $samenowplaying = ( (Get-FileHash $csOutFile).hash -eq (Get-FileHash $coOutFile).hash )
        } elseif ($type -eq '3') {
        # MUSIC
            [int]$alenght = $artist.Length
            [int]$tlenght = $title.Length
            [int]$tstart = $alenght+3           # 3 is because of ' - ' between artist and title in $message RT string
            if ($rdsdevice -eq "SmartGen") {
                [string]$message = 'TEXT='+$artist+' - '+$title+' ** '+$rdssite 
                [string]$rtplus = "RT+TAG=04,00,"+$alenght.ToString("00")+",01,"+$tstart.ToString("00")+","+$tlenght.ToString("00")+",1,1"
                # RT+ last 1,1: ItemRunning 1, Timeout 1min
            }
            if ($rdsdevice -eq "8700i") {
                [string]$message = 'RT='+$artist+' - '+$title+' ** '+$rdssite
                [string]$rtplus = ""
            }
            if ($rdsdevice -eq "LinkShare") {
                [string]$message = 'LOGIN admin,admin^RDS.RT='+$artist+' - '+$title+' ** '+$rdssite+"^LOGOUT^"
                [string]$rtplus = ""
            }
            
            $samenowplaying = $false
            # Because same song is processed earlier
        } else {
        # JINGLE or PROGRAM or NEWS
            if ($rdsdevice -eq "SmartGen") {
                [string]$message = 'TEXT='+$rdsnonmusic+' ** '+$rdssite
                [string]$rtplus = "RT+TAG=04,00,00,01,00,00,0,0"
                # RT+ last 0,0: ItemRunning 0, Timeout 0min
            }
            if ($rdsdevice -eq "8700i") {
                [string]$message = 'RT='+$rdsnonmusic+' ** '+$rdssite
                [string]$rtplus = ""
            }
            if ($rdsdevice -eq "LinkShare") {
                [string]$message = 'LOGIN admin,admin^RDS.RT='+$rdsnonmusic+' ** '+$rdssite+"^LOGOUT^"
                [string]$rtplus = ""
            }
            
            # Compare current NOWPLAYING TYPE and last NOWPLAYING TYPE
            Write-Host "Previous Now Playing Type:"
            Get-Content $coOutFile
            $samenowplaying = ( (Get-FileHash $csOutFile).hash -eq (Get-FileHash $coOutFile).hash )
        }
        Write-Host "$feature RT  Message:" $message -BackgroundColor Yellow -ForegroundColor Black
        Write-Host "$feature RT+ Message:" $rtplus -BackgroundColor Yellow -ForegroundColor Black
        if ($rdsdevice -eq "SmartGen") { $messagejoint = $message + "`n" + $rtplus + "`n" }
        if ($rdsdevice -eq "8700i") { $messagejoint = $message + "`n" }
        if ($rdsdevice -eq "LinkShare") { $messagejoint = $message + "`n" }

        # Is NOWPLAYING TYPE different?
        if ( ($samenowplaying -eq $true) -and ($force -eq $false) ) {
            # No, NOWPLAYING TYPE is the same, don't update RT
            Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
            Write-Log -message "[x] : $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing." -color Yellow
            Write-Log -message "[*] : $scriptstart $forced Script breaks" -color Red
            # Deleting current NOWPLAYING
            #if (Test-Path $dest) { Remove-Item -Path $dest.FullName }
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
            #Break
        } else {
        # NOWPLAYING TYPE is different
            Write-Host
            Write-Host "---- Ready to send $feature :" -ForegroundColor DarkGreen
            Write-Host
            if ($rdsporttype -eq "UDP") {
                # Sending RT/RT+
                New-UDPSend -feature $feature -remoteHost $remoteHost -port $port -message $messagejoint
            } else {
                # Sending RT/RT+
                New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $messagejoint
                # Sending forced PS if detected
            }

            # Updating original $coOutFile
            Copy-Item -Path $csOutFile -Destination $coOutFile -Force -Recurse
            #Remove-Item -Path $dest.FullName
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile }
        }
        if ($test -ne $true ) {
            if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile }
        }
    }
}




##############################
# FTP
##############################
#        -and (($type -eq "3") -or ($type -eq "1") -or ($retransmission -eq "1")) `
# Uploading XML to first FTP server
if ( `
    ( ($settings.FTP.Length -gt 0) `
	-and ($status -eq "playing") `
    -or ($forced -eq "FORCED") )`
) {
    #Import-Module WinSCP
    foreach ( $post in $settings.FTP ) {
        $index = [array]::IndexOf($settings.FTP, $post)+1
        $feature = "FTP"
        Write-Host
        Write-Host "---- Running $feature $index ----" -BackgroundColor DarkGreen -ForegroundColor Black
        Write-Host
        
        $ftp = $post.server
        $user = [System.Uri]::EscapeDataString($post.user)
        $pass = [System.Uri]::EscapeDataString($post.pass)
        $remotepath = $post.path
        $xmlf = Get-ChildItem -Path $settings.XMLF

        $localfile = $xmlf.FullName
        $remotefile = "ftp://"+$post.server+$post.path+$xmlf.Name

        Write-Host "---- Ready to send $feature local file $localfile" -ForegroundColor DarkGreen
        Write-Host "---- to $remotefile" -ForegroundColor DarkGreen

        $Error.Clear()
        try { 
            Write-Log -message "[+] : $scriptstart $forced FTP upload started to $ftp" -color Green

            $request = [Net.WebRequest]::Create($remotefile)
            $request.KeepAlive = $false
            $request.Credentials = New-Object System.Net.NetworkCredential($post.user,$post.pass)
            $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile 
            
            $fileStream = [System.IO.File]::OpenRead($xmlf.FullName)
            $ftpStream = $request.GetRequestStream()
            $fileStream.CopyTo($ftpStream)
            
            $ftpStream.Dispose()
            $fileStream.Dispose()

            # $webclient =  New-Object System.Net.WebClient
            # $uri =  New-Object System.Uri($remotefile)
            # #Error was happening because the method call was attempting to use the HttpProxy on the Server machine. 
            # #If the proxy is not set to null explicitly in your code, then you will get error - "An exception occurred during a webclient request"
            # $webclient.Proxy = $NULL 
            # $webclient.Credentials = New-Object System.Net.NetworkCredential($post.user,$post.pass)
            # $webclient.UploadFile($uri, $xmlf.FullName)
            # $webclient.Dispose()
        } catch { 
            Write-Host "Webclient errorcode:" $Error -BackgroundColor Red -ForegroundColor White
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Log -message "[-] : $scriptstart $forced FTP upload to $ftp error: $Error" -color Red
        }
        Write-Log -message "    : $scriptstart $feature $index operation done."
    }
}



##############################
# PURGE
##############################


# Cleaning up
# Don't delete temp files if debug
if ($test -ne $true ) {
    if (Test-Path $dest) { Remove-Item -Path $dest }
    if (Test-Path $sOutFile) { Remove-Item -Path $sOutFile }
}

Write-Log -message "[*] : $scriptstart $forced Script finished normally"
Write-Host `n
Start-Sleep -Seconds 1
