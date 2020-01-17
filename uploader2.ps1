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
    https://github.com/ykmn/uploader/blob/master/readme.md

.EXAMPLE
    uploader2.ps1 config.cfg -force

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
rartistid=7
rtitleid=17

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

#>

# Handling command-line parameters
param (
    #[string]$cfg = "d:\temp\uploader\test-rr.cfg"
    [Parameter(Mandatory=$true)][string]$cfg,
    [Parameter(Mandatory=$false)][switch]$force
)
# If $force set to $true then we didn't compare jsons and forcing push to webserver and RDS

#####################################################################################
Write-Host "Uploader 2.07.015 <r.ermakov@emg.fm> 2019-04-18 https://github.com/ykmn/uploader"
Write-Host "Now on Microsoft Powershell. Making metadata great again."
Write-Host

# If $debug set to $true then temporary xmls and jsons will not be removed
$debug = $false

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "`n`nThis script wowks with PowerShell 5.0 or newer.`nPlease upgrade!`n"
    Break
}

#Clear-Host
#[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
#[Console]::OutputEncoding = [System.Text.Encoding]::Default
#[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Set-Location -Path "C:\Program Files (x86)\Digispot II\Uploader\"
[string]$currentdir = Get-Location


function New-FTPUpload2  {
param ($ftp, $user, $pass, $xmlf, $remotepath, $feature)
    Write-Host
    Write-Host "---- Running" $feature "----" -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host
    Write-Host "FTP settings:" -BackgroundColor DarkCyan
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
                Add-Content -Path $log -Value "$now : [+] $feature upload of $($transfer.FileName) to $ftp OK" -PassThru
            }
        } finally {
            # Disconnect, clean up
            $session.Dispose()
        }
    } catch [Exception] {
        Add-Content -Path $log -Value "$now : [-] $feature error uploading to to $ftp : $($_.Exception.Message)" -PassThru
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
        Add-Content -Path $log -Value "$now : [+] $feature string $message sent to $remotehost : $port" -PassThru
    } catch {
        "oops"
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage "///" $FailedItem
        Write-Host "TCP-Client errorcode:" $Error -BackgroundColor Red -ForegroundColor White
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [-] $feature error tcp-sending to $remotehost : $port result: $Error" -PassThru
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
        Add-Content -Path $log -Value "$now : [+] $feature string $message sent ( $Sent bytes) to $remotehost : $port" -PassThru
} catch {
        "oops"
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage "///" $FailedItem
        Write-Host "TCP-Client errorcode:" $Error -BackgroundColor Red -ForegroundColor White
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [-] $feature error udp-sending to $remotehost : $port result: $Error" -PassThru
    }
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

Write-Host "Current folder:" $currentdir
Write-Host "Using configuration from $cfg"
Write-Host

# if ((Test-Path ".\curl.exe") -eq $false) {
#     Write-Host "CURL.EXE is not found in current folder.`nIf you need to use FTP upload please download CURL.EXE at http://curl.haxx.se/download.html `n" -ForegroundColor Red
# }

# Setup log files
$today = Get-Date -Format yyyy-MM-dd
if (!(Test-Path $currentdir"\log")) {
    New-Item -Path $currentdir"\log" -Force -ItemType Directory | Out-Null
}
if (!(Test-Path $currentdir"\tmp")) {
    New-Item -Path $currentdir"\tmp" -Force -ItemType Directory | Out-Null
}
if (!(Test-Path $currentdir"\jsons")) {
    New-Item -Path $currentdir"\jsons" -Force -ItemType Directory | Out-Null
}
$log = $currentdir + "\Log\" + $today + "-" + $cfg + ".log"
$scriptstart = Get-Date -Format yyyyMMdd-HHmmss-fff
$now = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $log -Value "$now : ** Script $scriptstart Started"


# Creating copy of XML file for processing
$xmlfile = $h.Get_Item("XMLF")
$xmlf = Get-ChildItem -Path $xmlfile
$dest = $currentdir + "\tmp\" + $xmlf.Name + "." + $scriptstart
if (!(Test-Path $xmlfile)) {
    Write-Host "No XML file found."
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : [-] No XML file found."
    Break
}
Write-Host "Copying $xmlf"
Write-Host "to $dest..."
Write-Host
Copy-Item -Path $xmlf -Destination $dest -Force -Recurse
Copy-Item -Path $xmlf -Destination $xmlf".bak" -Force -Recurse
# Parsing songs and saving to json
$dest = Get-ChildItem -Path $dest
Write-Host "Searching for songs in XML:" $dest.FullName
Write-Host

# Reading XML
[xml]$xmlfile = Get-Content $dest

# Here goes replacement table
$ReplacementTable = @{
';' = '/';
'Pi ' = '';
'Pi_' = '';
'New_' = '';
'Md_' = '';
'Edit_' = '';
'_' = ' ';
'Dj ' = 'DJ ';
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


# Creating songs array
$stream = @{stream = $cfg}
[array]$songs = @();

<# Required json format:
{ "stream":  "myradio.cfg",
  "songs":  [
	{ "artist":  "Arilena Ara", "runtime":  149, "dbID":  "151597", "ELEM":  0, "title":  "Nentori (Beverly Pills Remix)", "starttime":  1500984064 },
	{ "artist":  "Nickelback", "runtime":  197, "dbID":  "1274", "ELEM":  2, "title":  "If Everyone Cared", "starttime":  1500984223 },
	{ "artist":  "Charlie Puth", "runtime":  203, "dbID":  "152322", "ELEM":  5, "title":  "Attention", "starttime":  1500984426 }
  ]
}    #>

# Filling the array of next-up songs (Type=3)
ForEach ( $elem in $xmlfile.root.ChildNodes | Where-Object {$_.Elem.FONO_INFO.Type.'#text' -eq '3'} ) {

    $type = $elem.Elem.FONO_INFO.Type.'#text'
    $dbid = $elem.Elem.FONO_INFO.dbID.'#text'
    # splitting ELEM_0 into ELEM and 0
    $a,$b = $elem.LocalName.split('_')
    # converting 0 from string to integer for latest sorting
    [int]$el = [convert]::ToInt32($b, 10)

    $artist = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Artist

    # if ; in Artist then artist should be inside name
<#
    if (Select-String -pattern ";" -InputObject $artist) {
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : Artist $artist contains ';' - artist will be disabled."
        Write-Host "Artist $artist contains ';' - artist will be disabled." -ForegroundColor Yellow
        $artist=""
    }
#>

    $title = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Name
    # Searching for Russian Artist/Title
    # !!! CHECK FOR CORRECT ID IN UserAttribs SECTION IN XML
    # AND SET THESE VALUES IN .cfg
    # <UserAttribs>
    #    <ELEM><ID dt="i4">7</ID>
    #          <Name>Русский исполнитель</Name><Value>Алла Пугачева</Value></ELEM>
    #    <ELEM><ID dt="i4">17</ID>
    #          <Name>Русское название композиции</Name><Value>Прости, поверь</Value></ELEM>
    # </UserAttribs>
    ForEach ($userattr in $elem.Elem.UserAttribs.ChildNodes) {
        Write-Host $userattr.Name -BackgroundColor Red
        Write-Host $userattr.ID.'#text' -BackgroundColor DarkCyan
        # get UserAttribs Russian Artist and Title IDs from config
        $rartistid = $h.Get_Item("RARTISTID")
        $rtitleid = $h.Get_Item("RTITLEID")
        # 
        if ($userattr.ID.'#text' -eq $rartistid) {
            # Russian artist
            $rartist = $userattr.Value
            Write-Host $rartist -BackgroundColor DarkCyan
            $artist = $rartist
        }
        if ($userattr.ID.'#text' -eq $rtitleid) {
            # Russian title
            $rtitle = $userattr.Value
            Write-Host $rtitle -BackgroundColor DarkCyan
            $title = $rtitle
        }
    }
    # Culture and replacements for A/T
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
    # $ustarttime = value in seconds from 1.01.1970 0:00
    # -10800 = corrects UTC +3 in seconds
    [int]$starttime = $elem.Elem.StartTime.'#text'
    [int]$runtime = [math]::Floor([decimal]$elem.Elem.Runtime.'#text' / 1000)
    $utoday = Get-Date -Format dd/MM/yyyy | Get-Date -UFormat %s
    [int]$ustarttime = [int][double]$utoday + [int](([int][double]$starttime) / 1000) -10800

    Write-Host "Element" $el ":" $artist "-" $title

    Write-Host "Convert to:" $type"/"$dbid"/"$artist"/"$title"["$ustarttime"]"$runtime
    Write-Host

    $current = @{
        dbID = $dbid
        artist = $artist
        title = $title
        starttime = $ustarttime
        runtime = $runtime
        ELEM = $el
    }
    $currentobj = New-Object PSObject -Property $current
    [array]$songs += $currentobj
}

# Show what we got in array
@($songs) | Sort-Object -Unique ELEM | Format-Table

# Trimming songs array to current and two next-up elements
if ($songs.Count -ge 3) {
    $songs = $songs | Sort-Object -Unique ELEM
    $songs = $songs[0,1,2]
}
Write-Host "Trimming songs array to current and two next-up elements:"
@($songs) | Sort-Object -Unique ELEM | Format-Table

# File $sOutFile is json for current script;
# File $oOutFile if json of last successfull script
$sOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".json"
$oOutFile = $currentdir + "\jsons\" + $cfg + ".json"
if ((Test-Path $oOutFile) -eq $false) {
    Write-Host "No stream JSON found. Creating blank file"
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : [-] No stream JSON found. Creating blank file"
    New-Item -ItemType File -Path $oOutFile
    Add-Content -Path $oOutFile -Value " blank file"
}
# Adding table @($songs) to array $stream
$stream.Add("songs",@(@($songs) | Sort-Object -Unique ELEM))


##############################
# CURRENT
##############################

# Getting current A/T
$type = $xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text'
$artist = $xmlfile.root.ELEM_0.Elem.FONO_INFO.FONO_STRING_INFO.Artist
# If ; in Artist then artist should be inside name
<#
if (Select-String -pattern ";" -InputObject $artist) {
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : Artist $artist contains ';' - artist will be disabled."
    Write-Host "Artist $artist contains ';' - artist will be disabled." -ForegroundColor Yellow
    $artist=""
}
#>
$title = $xmlfile.root.ELEM_0.Elem.FONO_INFO.FONO_STRING_INFO.Name

# Culture and replacements for A/T
if ($artist -ne $null) {
    $artist = (Get-Culture).TextInfo.ToTitleCase($artist.ToLower())
    $artist = $artist.Trim()
} else { $artist = "" }
if ($title -ne $null) { 
    $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())
    $title = $title.Trim()
} else { $title = "" }

ForEach ($i in $ReplacementTable.Keys) {
    # If variable defined
        if ($artist) { $artist = $artist -replace $i, $ReplacementTable[$i] }
        if ($title) { $title = $title -replace $i, $ReplacementTable[$i] }
}


# Now we have $artist $title $type of "now playing" ELEM_0
Write-Host "Now"$xmlfile.root.ELEM_0.Status":" -BackgroundColor DarkCyan
Write-Host $type"/ "$artist "-" $title
$now = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $log -Value "$now : Now Playing: $type/ $artist - $title"


# Reading RDS section from current element
if ($xmlfile.root.ELEM_0.Elem.Rds -ne $null) {
    $rdspsforced = $xmlfile.root.ELEM_0.Elem.Rds.split("|")
    Write-Host "Found Elem/RDS:   " $rdspsforced
    $rdspsforced | ForEach-Object -begin { $j=@{} } -process {
        $m = [regex]::split($_,'=');
        if ($m[0].CompareTo("") -ne 0) {
            $j.Add($m[0], $m[1])
        }
    }
    $rdspsforced = $j.Get_Item("PT")
    Write-Host "Forced PS string found: " $rdspsforced
    Add-Content -Path $log -Value "$now : Forced PS string: $rdspsforced"
} else {
    Write-Host "Forced RDS string is not found."
    $rdspsforced = $null
}


##############################
# JSON
##############################


# If current element is a song and playing and dbid is not null
# then do json stuff - convert, save and upload.
# RDS and FTP goes independently.
if ( ($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "3") `
	-and ($xmlfile.root.ELEM_0.Status -eq "Playing") `
	-and ($xmlfile.root.ELEM_0.Elem.FONO_INFO.dbID.'#text' -ne $null) ) {
    # Converting table @($songs) to json and saving to file
    $json = ConvertTo-Json -InputObject ( @($stream) | Sort-Object -Unique ELEM )
    $json | Out-File -FilePath $sOutFile
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : JSON saved to $sOutFile."

    # Compare current .json and last .json
    if ( ((Compare-Object $(Get-Content $sOutFile) $(Get-Content $oOutFile) ) -eq $null) -and ($force -ne $true) ) {
        Write-Host "Previous and current JSONs are same" -ForegroundColor Yellow
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [x] Script $scriptstart Previous and current JSONs are same"
        Remove-Item -Path $dest
        Remove-Item -Path $sOutFile
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [*] Script $scriptstart breaks"
        Break
    } else {
        Copy-Item -Path $sOutFile -Destination $oOutFile -Force -Recurse
        # Leave temp files if debug
        if (!$debug) { Remove-Item -Path $sOutFile }
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
            Write-Host "JSON push engaged. Element:"$xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text'", Status:"$xmlfile.root.ELEM_0.Status
            $now = Get-Date -Format HH:mm:ss.fff
            Add-Content $log "$now : [+] $scriptstart JSON push engaged. Element: $($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text'), Status: $($xmlfile.root.ELEM_0.Status), JSON=$($h.Get_Item('JSON'))"
        } catch { 
            Write-Host "Webrequest errorcode:" $Error -BackgroundColor Red -ForegroundColor White
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Host $ErrorMessage "///" $FailedItem
            $now = Get-Date -Format HH:mm:ss.fff
            Add-Content -Path $log -Value "$now : [-] JSON push error: $Error"
        }
    } else {
        Write-Host "JSON push didn't engaged. Element:"$xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text'", Status:"$xmlfile.root.ELEM_0.Status ", JSON ="$h.Get_Item('JSON') -ForegroundColor Yellow
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : JSON push didn't engaged. Element: $($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text'), Status: $($xmlfile.root.ELEM_0.Status), JSON=$($h.Get_Item('JSON'))"
    }
}


##############################
# RDS
##############################


# Sending current song to RDS
if (($xmlfile.root.ELEM_0.Status -eq "Playing") -and ($h.Get_Item("RDS") -eq "TRUE")) {

    # Saving NOWPLAYING to file
    $csOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".rds-current.txt"
    $coOutFile = $currentdir + "\jsons\" + $cfg + ".rds-current.txt"
    if ((Test-Path $coOutFile) -eq $false) {
        Write-Host "No NOWPLAYING file found. Creating blank file"
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [-] No NOWPLAYING file found. Creating file"
        $type | Out-File -FilePath $coOutFile
    }
    $type | Out-File -FilePath $csOutFile
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : RDS Now Playing: $type/ $artist - $title"
    Add-Content -Path $log -Value "$now : Temp NOWPLAYING file: $csOutFile "

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


    Write-Host
    Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host
    
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
    Write-Host "$feature RT  Message:" $message -BackgroundColor DarkCyan
    Write-Host "$feature RT+ Message:" $rtplus -BackgroundColor DarkCyan
    if ($rdsdevice -eq "SmartGen") { $messagejoint = $message + "`n" + $rtplus + "`n" }
    if ($rdsdevice -eq "8700i") { $messagejoint = $message + "`n" }

    # Updating PS
    # Sending forced PS if detected if DEVA SmartGen
    if ($rdspsforced -ne $null)  {
        Write-Host
        Write-Host "Detected forced RDS PS: $rdspsforced" -BackgroundColor DarkYellow -ForegroundColor Red
        Add-Content -Path $log -Value "$now : Detected forced RDS PS: $rdspsforced"
        $rdsfile = $rdsdevice + "_" + $cfg + "-" + $rdspsforced + ".txt"
        Write-Host "Looking for $rdsfile"
        Add-Content -Path $log -Value "$now : Looking for $rdsfile"
        if (Test-Path $rdsfile) {
            Write-Host "Sending $rdsfile to $remotehost :$port"
            Add-Content -Path $log -Value "$now : Sending $rdsfile to $remotehost :$port"                
            if ($rdsdevice -eq "8700i") { $messagejoint = (Get-Content -Path $rdsfile -Raw).Replace("`r`n","`n") }
            if ($rdsdevice -eq "SmartGen") { $messagejoint = Get-Content -Path $rdsfile }
            Write-Host " [+] Sending RDS PS String: $messagejoint"
            Add-Content -Path $log -Value "$now : [+] Sending RDS PS string: $messagejoint"
            New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $messagejoint
        } else {
            Write-Host "Forced RDS PS $rdspsforced detected but $rdsfile not found."
            Add-Content -Path $log -Value "$now : Forced RDS PS $rdspsforced detected but $rdsfile not found."
        }
    }
    
    # Is NOWPLAYING TYPE different?
    if ( ($samenowplaying -eq $true) -and ($force -eq $false) ) {
        # No, NOWPLAYING TYPE is the same, don't update RT
        Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [x] Script $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing."
        Add-Content -Path $log -Value "$now : [*] Script $scriptstart breaks"
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
    if ($debug -ne $true ) {
        if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile }
    }
}


##############################
# PROSTREAM
##############################


# Sending current song to PROSTEAM
if ($xmlfile.root.ELEM_0.Status -eq "Playing") {
    if ($type -eq "3") { $message = "t=" + $artist + " - " + $title + "`n" ; $samenowplaying = $false; } else { $message = "t=`n" }
    if ($h.Get_Item("PROSTREAM1") -eq "TRUE") {
        $remoteHost = $h.Get_Item("ZIPSERVER1")
        $port = $h.Get_Item("ZIPPORT1")
        $feature = "PROSTREAM1"
        # Is it jingle or commercial?
        if ($samenowplaying -eq $true) {
            Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
            $now = Get-Date -Format HH:mm:ss.fff
            Add-Content -Path $log -Value "$now : [x] Script $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing."
            Add-Content -Path $log -Value "$now : [*] Script $scriptstart breaks"
            # Deleting current NOWPLAYING
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
            #Break
        } else {
            Write-Host
            Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
            Write-Host
            Write-Host "$feature Message:" -BackgroundColor DarkCyan
            New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            if ($h.Get_Item("PROSTREAM2") -eq "TRUE") {
                $remoteHost = $h.Get_Item("ZIPSERVER2")
                $port = $h.Get_Item("ZIPPORT2")
                $feature = "PROSTREAM2"
                Write-Host
                Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
                Write-Host
                Write-Host "$feature Message:" -BackgroundColor DarkCyan
                New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            }
            #Remove-Item -Path $csOutFile.FullName
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
        }
    }
}


##############################
# FTP
##############################


# Uploading XML to first FTP server
if ( `
        ($h.Get_Item("FTP1") -eq "TRUE") `
        -and (Get-Module -ListAvailable -Name WinSCP) `
        -and (($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "3") -or ($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "1")) `
        -and ($xmlfile.root.ELEM_0.Status -eq "Playing") `
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
        -and (($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "3") -or ($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "1")) `
        -and ($xmlfile.root.ELEM_0.Status -eq "Playing") `
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
if ($debug -ne $true ) {
    if (Test-Path $dest) { Remove-Item -Path $dest }
    if (Test-Path $sOutFile) { Remove-Item -Path $sOutFile }
}

$now = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $log -Value "$now : [*] Script $scriptstart finished normally"
Write-Host Script finished.`n
Start-Sleep -Seconds 3