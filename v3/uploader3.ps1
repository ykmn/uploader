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
    Sends DJin.ValueServer metadata to some destinations
    
.DESCRIPTION
    Upload DJin.ValueServer XML to FTP-server
    Push DJin.ValueServer metadata to HTTP server
    Push DJin.ValueServer Artist-Title to RDS encoder as RaioText and RadioText+
    Push DJin.ValueServer Artist-Title to Omnia ProStream X/2

.LINK
    https://github.com/ykmn/uploader/v3/blob/master/readme.md

.EXAMPLE
    uploader3.ps1 config.cfg -force

.PARAMETER force
    Force upload operations even if the data is the same.

.PARAMETER cfg
    Configuration file name.
    config.cfg example:

[Actions]
JSON=TRUE
FTP1=TRUE
FTP2=FALSE
RDS=TRUE
PROSTREAM1=TRUE
PROSTREAM2=TRUE

[XML]
# Using XML from Digispot II Value.Server with XML.Writer module
XMLF=\\server\share\EP-MSK.xml
#XMLF=C:\XML\uploader\EP-MSK2.xml

[RDS]
# Set RDS Device type: 8700i or SmartGen
RDSDEVICE=8700i
RDSIP=127.0.0.1
RDSPORT=5001
# Set RDS Connection port type: TCP or UDP
RDSPORTTYPE=UDP
RDSSITE=www.europaplus.ru
RDSCOMMERCIAL=+7(495)6204664
RDSNONMUSIC=Europa Plus 106.2 FM

[JSON]
JSONSERVER=http://127.0.0.1/post.php

[ID]
ALTARTISTID=8
ALTTITLEID=19
ALTAT=TRUE
# если FALSE, то основных атрибутах находятся русские AT.
# если TRUE, то в основных атрибутах находится транслит, а в пользовательских - русские AT.


[FTP1]
FTPSERVER1=127.0.0.1:30021
FTPUSER1=user1
FTPPASS1=pass1
FTPPATH1=/pub/uploads/Radio1/

[FTP2]
FTPSERVER2=127.0.0.1:21
FTPUSER2=user2
FTPPASS2=pass2
FTPPATH2=/

[PROSTREAM]
# Using Omnia ProStream "Character Parser Sample" filter
ZIPSERVER1=prostream-server1
ZIPPORT1=6001
ZIPSERVER2=prostream-server2
ZIPPORT2=6001

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
#>

# Handling command-line parameters
param (
    #[Parameter(Mandatory=$true)][string]$cfg = "test-ext.cfg",
    [Parameter(Mandatory=$true)][string]$cfg,
    [Parameter(Mandatory=$false)][switch]$force,
    [Parameter(Mandatory=$false)][switch]$test
)
# If $force set to $true then we didn't compare jsons and forcing push to webserver and RDS

#####################################################################################
Clear-Host
Write-Host "`nUploader 3.01.003 <r.ermakov@emg.fm> 2020-08-25 https://github.com/ykmn/uploader"
Write-Host "This script uses Extended cur_playing.XML from DJin X-Player.`n"

# If $test set to $true then temporary xmls and jsons will not be removed
if ($force -eq $true) { $forced = "FORCED" } else {$forced = "" }


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

#Set-Location -Path "C:\Program Files (x86)\Digispot II\Uploader\"
#Set-Location -Path "C:\Users\r.ermakov\Documents\GitHub\uploader\"


function New-FTPUpload2  {
param ($ftp, $user, $pass, $xmlf, $remotepath, $feature)
    Write-Host
    Write-Host "---- Running" $feature "----" -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host
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


if (!(Test-Path $currentdir"\"$cfg)) {
    Write-Host "No config file found."
    Break
}

# Reading settings
Get-Content $cfg | ForEach-Object -begin { $h=@{} } -process {
    $k = [regex]::split($_,'=');
    if (($k[0].CompareTo("") -ne 0) `
      -and ($k[0].StartsWith("[") -ne $True) `
      -and ($k[0].StartsWith("#") -ne $True) )
    {
        $h.Add($k[0], $k[1])
    }
}

Write-Host "Using configuration from $cfg"
Write-Host

# if ((Test-Path ".\curl.exe") -eq $false) {
#     Write-Host "CURL.EXE is not found in current folder.`nIf you need to use FTP upload please download CURL.EXE at http://curl.haxx.se/download.html `n" -ForegroundColor Red
# }


# Setup folders structure
if (!(Test-Path $currentdir"\log")) {
    New-Item -Path $currentdir"\log" -Force -ItemType Directory | Out-Null
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
$xmlfile = $h.Get_Item("XMLF")
$xmlf = Get-ChildItem -Path $xmlfile
$dest = $currentdir + "\tmp\" + $xmlf.Name + "." + $scriptstart
if (!(Test-Path $xmlfile)) {
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

#    '&Apos;' = "'";

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

# Creating songs array
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
    $altat = $h.Get_Item("ALTAT")
    $altartistid = $h.Get_Item("ALTARTISTID")
    $alttitleid = $h.Get_Item("ALTTITLEID")

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
Write-Host "Trimming songs array to current and two next-up elements:"
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

# get UserAttribs Russian Artist and Title IDs from config
if ($altat -eq "TRUE") { # кириллица в пользовательских полях карточки
    ForEach ($userattr in $elem.Elem.UserAttribs.ChildNodes) {
    Write-Host $userattr.Name  -BackgroundColor Red
    Write-Host $userattr.ID.'#text' " : " $altartistid -BackgroundColor Blue
    # get UserAttribs Russian Artist and Title IDs from config
        if ($userattr.ID.'#text' -eq $altartistid) {
            # Get cyrillic artist from UserAttribs
            $altartist = $userattr.Value
            Write-Host $altartist -BackgroundColor DarkGreen
            if ($altartist) { $artist = $altartist }
        }
        if ($userattr.ID.'#text' -eq $alttitleid) {
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
Write-Host STORING NOW PLAYING SONG: -BackgroundColor Yellow -ForegroundColor Black
Write-Host Type:$type / Artist:$artist / Title:$title / DBid:$dbid -BackgroundColor Yellow -ForegroundColor Black
# Storing current AT for ProStream and RDS
$cArtist = $artist
$cTitle = $title

# Reading RDS section from current element
if ($xmlfile.ELEM_LIST.ChildNodes[0].Elem.Rds -ne $null) {
    $rdspsforced = $xmlfile.ELEM_LIST.ChildNodes[0].Elem.Rds.split("|")
    Write-Host "Found Elem/RDS:   " $rdspsforced
    $rdspsforced | ForEach-Object -begin { $j=@{} } -process {
        $m = [regex]::split($_,'=');
        if ($m[0].CompareTo("") -ne 0) {
            $j.Add($m[0], $m[1])
        }
    }
    $rdspsforced = $j.Get_Item("PT")
    Write-Log -message "    : $scriptstart RDS Forced PS string found: $rdspsforced" -color Yellow
} else {
    Write-Log -message "    : $scriptstart Forced RDS string is not found."
    $rdspsforced = $null
}



##############################
# JSON
##############################

# If current element is a song and playing and dbid is not null
# then do json stuff - convert, save and upload.
# RDS and FTP goes independently.
if ( ($type -eq "3") `
	-and ($status -eq "playing") `
	-and ($dbid -ne $null) ) {
    # Converting table @($songs) to json and saving to file
    Write-Host Songs: $songs
    
    $json = ConvertTo-Json -InputObject ($stream)
    $json | Out-File -FilePath $sOutFile
    Write-Log -message "    : $scriptstart JSON saved to $sOutFile."

    # Compare current .json and last .json
    if ( ((Compare-Object $(Get-Content $sOutFile) $(Get-Content $oOutFile) ) -eq $null) -and ($force -ne $true) ) {
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
    if ($h.Get_Item("JSON") -eq "TRUE") {
        Write-Host
        Write-Host "---- Running JSON ----" -BackgroundColor DarkGreen -ForegroundColor White
        $jsonserver = $h.Get_Item("JSONSERVER")
        $json
        # Converting to UTF-8
        $json = [System.Text.Encoding]::UTF8.GetBytes($json)

        $Error.Clear()
        try { 
#            Invoke-Command -ScriptBlock {Invoke-WebRequest -Uri $jsonserver -Method POST -Body $json -ContentType "application/json"} -AsJob
            Invoke-WebRequest -Uri $jsonserver -Method POST -Body $json -ContentType "application/json"
            Write-Host "JSON push engaged. AT: $artist $title Element:"$type", Status:"$status
            Write-Log -message "[+] : $scriptstart JSON $forced push engaged. AT: $artist $title Element: $type, Status: $status), JSON=$($h.Get_Item('JSON'))" -color Green
        } catch { 
            Write-Host "Webrequest errorcode:" $Error -BackgroundColor Red -ForegroundColor White
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host $ErrorMessage "///" $FailedItem
            Write-Log -message "[-] : $scriptstart JSON $forced push error: $Error" -color Red
        }
    } else {
        Write-Log -message "    : $scriptstart JSON $forced push didn't engaged. AT: $artist $title Element: $type, Status: $status), JSON=$($h.Get_Item('JSON'))" -color Red
    }
    # Leave temp files if debug
    if (!$test) { Remove-Item -Path $sOutFile }
}



##############################
# PROSTREAM
##############################

# Restoring AT
$artist = $cArtist
$title = $cTitle
# Sending current song to PROSTEAM
if ($status -eq "Playing") {
    if ($h.Get_Item("PROSTREAM1") -eq "TRUE") {
        $remoteHost = $h.Get_Item("ZIPSERVER1")
        $port = $h.Get_Item("ZIPPORT1")
        $feature = "PROSTREAM1"
        # Is it jingle or commercial?
        if ($samenowplaying -eq $true) {
            Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
            Write-Log -message "[x] : $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing." -color Yellow
            # Deleting current NOWPLAYING
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
        } else {
            Write-Host
            Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
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
     
            Write-Host "$feature Message:" $message -BackgroundColor Yellow -ForegroundColor Black
            New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            if ($h.Get_Item("PROSTREAM2") -eq "TRUE") {
                $remoteHost = $h.Get_Item("ZIPSERVER2")
                $port = $h.Get_Item("ZIPPORT2")
                $feature = "PROSTREAM2"
                Write-Host
                Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
                Write-Host
                Write-Host "$feature Message:" -BackgroundColor Yellow -ForegroundColor Black
                New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            }
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
if (($status -eq "Playing") -and ($h.Get_Item("RDS") -eq "TRUE")) {
    Write-Host
    Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host
    
    # Saving NOWPLAYING to file
    $csOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".rds-current.txt"
    $coOutFile = $currentdir + "\jsons\" + $cfg + ".rds-current.txt"
    if ((Test-Path $coOutFile) -eq $false) {
        Write-Log -message "[-] : $scriptstart No NOWPLAYING file found. Creating file"
        $type | Out-File -FilePath $coOutFile
    }

    # Reading RDS config
    $port = $h.Get_Item("RDSPORT")
    $remoteHost = $h.Get_Item("RDSIP")
    $rdsporttype = $h.Get_Item("RDSPORTTYPE")
    $rdssite = $h.Get_Item("RDSSITE")
    $rdscommercial = $h.Get_Item("RDSCOMMERCIAL")
    $rdsnonmusic = $h.Get_Item("RDSNONMUSIC")
    if ( ($h.Get_Item("RDSDEVICE") -eq "8700i") -or ($h.Get_Item("RDSDEVICE") -eq "SmartGen") ) {
        $rdsdevice = $h.Get_Item("RDSDEVICE")
    }
    $feature = "RDS"
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
            $message = 'TEXT='+$rdscommercial +' ** '+$rdssite
            [string]$rtplus = "RT+TAG=04,00,00,01,00,00,1,1"
        }
        if ($rdsdevice -eq "8700i") {
            $message = 'RT='+$rdscommercial +' ** '+$rdssite
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
        [int]$tstart = $alenght+3           # 3 is because ' - ' between artist and title in $message RT string
        if ($rdsdevice -eq "SmartGen") {
            $message = 'TEXT='+$artist+' - '+$title+' ** '+$rdssite 
            [string]$rtplus = "RT+TAG=04,00,"+$alenght.ToString("00")+",01,"+$tstart.ToString("00")+","+$tlenght.ToString("00")+",1,1"
        }
        if ($rdsdevice -eq "8700i") {
            $message = 'RT='+$artist+' - '+$title+' ** '+$rdssite
            [string]$rtplus = ""
        }
        
        $samenowplaying = $false
        # Because same song is processed earlier
    } else {
    # JINGLE or PROGRAM or NEWS
        if ($rdsdevice -eq "SmartGen") {
            $message = 'TEXT='+$rdsnonmusic+' ** '+$rdssite
            [string]$rtplus = "RT+TAG=04,00,00,01,00,00,1,1"
        }
        if ($rdsdevice -eq "8700i") {
            $message = 'RT='+$rdsnonmusic+' ** '+$rdssite
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

    # Updating PS
    # Sending forced PS if detected if DEVA SmartGen
    if ($rdspsforced -ne $null)  {
        Write-Host
        Write-Log -message "    : $scriptstart Detected forced RDS PS: $rdspsforced" -color Yellow
        $rdsfile = $rdsdevice + "_" + $cfg + "-" + $rdspsforced + ".txt"
        Write-Log -message "    : $scriptstart Looking for $rdsfile"
        Write-Log -message "    : $scriptstart $forced $feature Sending RDS $rdspsforced PS string: $messagejoint"
        if (Test-Path $rdsfile) {
            Write-Log -message "    : $scriptstart Sending $rdsfile to $remotehost :$port"                
            if ($rdsdevice -eq "8700i") { $messagejoint = (Get-Content -Path $rdsfile -Raw).Replace("`r`n","`n") }
            if ($rdsdevice -eq "SmartGen") { $messagejoint = Get-Content -Path $rdsfile }
            New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $messagejoint
        } else {
            Write-Log -message "    : $scriptstart Forced RDS PS $rdspsforced detected but $rdsfile not found." -color Red
        }
    }
    
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



##############################
# FTP
##############################

# Uploading XML to first FTP server
if ( `
        ($h.Get_Item("FTP1") -eq "TRUE") `
        -and (Get-Module -ListAvailable -Name WinSCP) `
        -and (($type -eq "3") -or ($type -eq "1")) `
        -and ($status -eq "playing") `
) {
    Import-Module WinSCP
    $ftp = $h.Get_Item("FTPSERVER1")
    $user = $h.Get_Item("FTPUSER1")
    $pass = $h.Get_Item("FTPPASS1")
    $remotepath = $h.Get_Item("FTPPATH1")
    $feature = "FTP1"
    $xmlf = Get-ChildItem -Path $h.Get_Item("XMLF")
    $remotefile = $ftp+"/"+$xmlf.Name
    New-FTPUpload2 -ftp $ftp -user $user -pass $pass -xmlf $xmlf -remotepath $remotepath -feature $feature
}

# Uploading XML to second FTP server
if ( `
        ($h.Get_Item("FTP2") -eq "TRUE") `
        -and (Get-Module -ListAvailable -Name WinSCP) `
        -and (($type -eq "3") -or ($type -eq "1")) `
        -and ($status -eq "playing") `
) {
    Import-Module WinSCP
    $ftp = $h.Get_Item("FTPSERVER2")
    $user = $h.Get_Item("FTPUSER2")
    $pass = $h.Get_Item("FTPPASS2")
    $remotepath = $h.Get_Item("FTPPATH2")
    $feature = "FTP2"
    $xmlf = Get-ChildItem -Path $h.Get_Item("XMLF")
    $remotefile = $ftp+"/"+$xmlf.Name
    New-FTPUpload2 -ftp $ftp -user $user -pass $pass -xmlf $xmlf -remotepath $remotepath -feature $feature
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
Start-Sleep -Seconds 3
