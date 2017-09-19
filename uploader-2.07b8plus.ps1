# Handling command-line parameters
 param (
    #[string]$cfg = "d:\temp\uploader\test-rr.cfg"
    [Parameter(Mandatory=$true)][string]$cfg 
 )

# if $debug set to $true then temporary xmls and jsons will not be removed
$debug = $false

Clear-Host
[string]$currentdir = Get-Location

Write-Host "Uploader 2.07beta8 <r.ermakov@emg.fm> 2017-09-19"
Write-Host "Now on Microsoft Powershell. Making metadata great again."
Write-Host

function New-FTPUpload2  {
param ($ftp, $user, $pass, $xmlf, $remotepath, $feature)
    Write-Host
    Write-Host "---- Running" $feature "----" -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host
    Write-Host "FTP settings:" -BackgroundColor DarkYellow -ForegroundColor Blue
    Write-Host "original file for upload -" $xmlf.FullName
    Write-Host "local copy of a file for upload -" $dest.Fullname
    # make sure you have "/" in FTPPATH1 on your config flie
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
# sending to ip-port
    $socket = new-object System.Net.Sockets.TcpClient($remoteHost, $port)
    $data1 = [System.Text.Encoding]::ASCII.GetBytes($message)
    $Error.Clear()
    try { 
        $stream = $socket.GetStream()
        $stream.Write($data1, 0, $data1.Length)
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [+] $feature string $message sent to $remotehost : $port" -PassThru
    } catch {
        "oops"
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage "///" $FailedItem
        Write-Host "TCP-Client errorcode:" $Error -BackgroundColor Red -ForegroundColor White
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [-] $feature error sending to $remotehost : $port result: $Error" -PassThru
    }
}

# Reading settings
Get-Content $cfg | foreach-object -begin {$h=@{}} -process {
    $k = [regex]::split($_,'=');
    if(($k[0].CompareTo("") -ne 0) `
                -and ($k[0].StartsWith("[") -ne $True) `
                -and ($k[0].StartsWith("#") -ne $True))
    {
        $h.Add($k[0], $k[1])
    }
}

Write-Host "Current folder:" $currentdir
Write-Host "Using configuration from $cfg"
Write-Host

if ((Test-Path ".\curl.exe") -eq $false) {
    Write-Host "CURL.EXE is not found in current folder. If you need to use FTP upload, please download CURL.EXE at http://curl.haxx.se/download.html" -ForegroundColor Red
}

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
Write-Host "Copying $xmlf"
Write-Host "to $dest..."
Write-Host
Copy-Item -Path $xmlf -Destination $dest -Force -Recurse
Copy-Item -Path $xmlf -Destination $xmlf".bak" -Force -Recurse
# Parsing songs and saving to json
$dest = Get-ChildItem -Path $dest
Write-Host "Searching for songs in XML:" $dest.FullName
Write-Host

# reading XML
[xml]$xmlfile = Get-Content $dest

# Here goes replacement table
$ReplacementTable = @{
"pi_" = ""
"pi " = ""
"_id_ep live" = ""
"new_" = ""
"md_" = ""
"edit_" = ""
"_" = " "
"dj " = "DJ "
"ft." = "feat."
"feat." = "feat."
"ajr" = "AJR"
"lp" = "LP"
"abba" = "ABBA"
"modjo" = "Modjo"
"  " = " "
};

# creating array
$stream = @{stream = $cfg}
[array]$songs = @();

<# required json format:
{
"stream"": "main",
"songs": [ 
    {
    "dbID": "63695",
    "artist": "Alla Pugachiova",
    "runtime": "225550",
    "type": "3",
    "ELEM": 0,
    "title": "Prosti,Pover\u0027",
    "starttime": "1499879633"
    },
 ]
}    #>

# filling the array of next-up songs
ForEach ($elem in $xmlfile.root.ChildNodes | Where-Object {$_.Elem.FONO_INFO.Type.'#text' -eq '3'} ) {

    $type = $elem.Elem.FONO_INFO.Type.'#text'
    $dbid = $elem.Elem.FONO_INFO.dbID.'#text'
    # splitting ELEM_0 into ELEM and 0
    # converting 0 from string to integer for latest sorting
    $a,$b = $elem.LocalName.split('_')
    [int]$el = [convert]::ToInt32($b, 10)
    
    $artist = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Artist
    # if ; in Artist then artist should be inside name
    if (Select-String -pattern ";" -InputObject $artist) {
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : Artist $artist contains ';' - artist will be disabled."
        Write-Host "Artist $artist contains ';' - artist will be disabled." -ForegroundColor Yellow
        $artist=""
    }
    $title = $elem.Elem.FONO_INFO.FONO_STRING_INFO.Name
    [int]$starttime = $elem.Elem.StartTime.'#text'
    [int]$runtime = [math]::Floor([decimal]$elem.Elem.Runtime.'#text' / 1000)
    Write-Host "Element" $el ":" $artist "-" $title
    if ($artist) { $artist = (Get-Culture).TextInfo.ToTitleCase($artist.ToLower()) }
    if ($title) { $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower()) }

    foreach ($i in $ReplacementTable.Keys) {
    # if variable defined
        if ($artist) { $artist = $artist -replace $i, $ReplacementTable[$i] }
        if ($title) { $title = $title -replace $i, $ReplacementTable[$i] }
    }
    if ($artist) { $artist = $artist.Trim() } else { $artist = "" }
    if ($title) { $title = $title.Trim() } else { $title = ""}


    $utoday = Get-Date -Format dd/MM/yyyy | Get-Date -UFormat %s
    [int]$ustarttime = [int][double]$utoday + [int](([int][double]$starttime) / 1000) -10800
    # starttime = value in milliseconds from 0:00 today
    # $ustarttime = value in seconds from 1.01.1970 0:00
    # -10800 = corrects UTC +3 in seconds
    
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
   
# show what we got in array
@($songs) | Sort-Object -Unique ELEM | Format-Table

# file $sOutFile is json for current script;
# file $oOutFile if json of last successfull script
$sOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".json"
$oOutFile = $currentdir + "\jsons\" + $cfg + ".json"
if ((Test-Path $oOutFile) -eq $false) {
    Write-Host "No stream JSON found. Creating blank file"
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : [-] No stream JSON found. Creating blank file"
    New-Item -ItemType File -Path $oOutFile
    Add-Content -Path $oOutFile -Value " blank file"
}
# adding table @($songs) to array $stream
$stream.Add("songs",@(@($songs) | Sort-Object -Unique ELEM))


# getting current A/T
$type = $xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text'
$artist = $xmlfile.root.ELEM_0.Elem.FONO_INFO.FONO_STRING_INFO.Artist
# if ; in Artist then artist should be inside name
if (Select-String -pattern ";" -InputObject $artist) {
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : Artist $artist contains ';' - artist will be disabled."
    Write-Host "Artist $artist contains ';' - artist will be disabled." -ForegroundColor Yellow
    $artist=""
}
$title = $xmlfile.root.ELEM_0.Elem.FONO_INFO.FONO_STRING_INFO.Name
foreach ($i in $ReplacementTable.Keys) {
    # if variable defined
    if ($artist) { $artist = $artist -replace $i, $ReplacementTable[$i] }
    if ($title) { $title = $title -replace $i, $ReplacementTable[$i] }
}
if ($artist -ne $null) { $artist = (Get-Culture).TextInfo.ToTitleCase($artist.ToLower()) ; $artist = $artist.Trim() } else { $artist = "" }
if ($title -ne $null) { 
    $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())
    $title = $title.Trim()
} else { $title = "" }

    
# now we have $artist $title $type of "now playing" ELEM_0
Write-Host "Now"$xmlfile.root.ELEM_0.Status":" -BackgroundColor DarkYellow -ForegroundColor Blue
Write-Host $type"/ "$artist "-" $title
$now = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $log -Value "$now : Now playing: $type/ $artist - $title"







# if current element is a song and playing and dbid is not null
# then do json stuff - convert, save and upload.
# RDS and FTP goes independently.
if ( ($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "3") `
	-and ($xmlfile.root.ELEM_0.Status -eq "Playing") `
	-and ($xmlfile.root.ELEM_0.Elem.FONO_INFO.dbID.'#text' -ne $null) ) {
    # converting table @($songs) to json and saving to file
    $json = ConvertTo-Json -InputObject ( @($stream) | Sort-Object -Unique ELEM )
    $json | Out-File -FilePath $sOutFile
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : JSON saved to $sOutFile."

    
    # compare current .json and last .json
    if ( (Compare-Object $(Get-Content $sOutFile) $(Get-Content $oOutFile) ) -eq $null) {
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
        # leave temp files if debug
        if (!$debug) { Remove-Item -Path $sOutFile }
    }



    #pushing json to hosting
    if ($h.Get_Item("JSON") -eq "TRUE") {
        Write-Host
        Write-Host "---- Running JSON ----" -BackgroundColor DarkGreen -ForegroundColor White
        $jsonserver = $h.Get_Item("JSONSERVER")
        $json
        
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

# Sending current song to RDS
if (($xmlfile.root.ELEM_0.Status -eq "Playing") -and ($h.Get_Item("RDS") -eq "TRUE")) {

    # saving NOWPLAYING to file
    $csOutFile = $currentdir + "\jsons\" + $cfg + "." + $scriptstart + ".rds-current.txt"
    $coOutFile = $currentdir + "\jsons\" + $cfg + ".rds-current.txt"
    if ((Test-Path $coOutFile) -eq $false) {
        Write-Host "No NOWPLAYING found. Creating blank file"
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [-] No NOWPLAYING found. Creating file"
        $type | Out-File -FilePath $coOutFile
    }
    $type | Out-File -FilePath $csOutFile
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : NOWPLAYING: $type/ $artist - $title"
    Add-Content -Path $log -Value "$now : Temp NOWPLAYING file: $csOutFile "

    # reading RDS config
    $port = $h.Get_Item("RDSPORT")
    $remoteHost = $h.Get_Item("RDSIP")
    $rdssite = $h.Get_Item("RDSSITE")
    $rdshone = $h.Get_Item("RDSPHONE")
    $feature = "RDS"
    Write-Host
    Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host
    if ($type -eq '1') {
        $message = 'TEXT=www.emg.fm ** Commercial: '+$rdshone
        [string]$rtplus = "RT+TAG=04,00,00,01,00,00,1,1"
        # compare current NOWPLAYING TYPE and last NOWPLAYING TYPE
        Write-Host "Previous Now Playing Type:"
        Get-Content $coOutFile
        $samenowplaying = ( (Get-FileHash $csOutFile).hash -eq (Get-FileHash $coOutFile).hash )
    }
    if ($type -eq '2') {
        $message = 'TEXT='+$rdssite
        [string]$rtplus = "RT+TAG=04,00,00,01,00,00,1,1"
        # compare current NOWPLAYING TYPE and last NOWPLAYING TYPE
        Write-Host "Previous Now Playing Type:"
        Get-Content $coOutFile
        $samenowplaying = ( (Get-FileHash $csOutFile).hash -eq (Get-FileHash $coOutFile).hash )
    }
    if ($type -eq '3') { 
        $message = 'TEXT='+$artist+' - '+$title+' ** '+$rdssite 
        [int]$alenght = $artist.Length
        [int]$tlenght = $title.Length
        [int]$tstart = $alenght+3
        # 3 is because ' - ' between artist and title in $message RT string
        [string]$rtplus = "RT+TAG=04,00,"+$alenght.ToString("00")+",01,"+$tstart.ToString("00")+","+$tlenght.ToString("00")+",1,1"
        $samenowplaying = $false
        # because same song is processed earlier
    }
    Write-Host "$feature Message:" $message -BackgroundColor DarkYellow -ForegroundColor Blue
    Write-Host "$feature RT+ Message:" $rtplus -BackgroundColor DarkYellow -ForegroundColor Blue
    $messagejoint = $message + "`n" + $rtplus + "`n"
    
    # is NOWPLAYING TYPE different?
    if ($samenowplaying -eq $true) {
        Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [x] Script $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing."
        #$dest.FullName
        $now = Get-Date -Format HH:mm:ss.fff
        Add-Content -Path $log -Value "$now : [*] Script $scriptstart breaks"
        # deleting current NOWPLAYING
        #if (Test-Path $dest) { Remove-Item -Path $dest.FullName }
        #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
        #Break
    } else {
        # NOWPLAYING TYPE is different
        New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $messagejoint
        # updating original $coOutFile
        Copy-Item -Path $csOutFile -Destination $coOutFile -Force -Recurse
        #Remove-Item -Path $dest.FullName
        #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile }
    }
}



# Sending current song to PROSTEAM
if ($xmlfile.root.ELEM_0.Status -eq "Playing") {
    if ($type -eq "3") { $message = "t=" + $artist + " - " + $title + "`n" ; $samenowplaying = $false; } else { $message = "t=`n" }
    if ($h.Get_Item("PROSTREAM1") -eq "TRUE") {
        $remoteHost = $h.Get_Item("ZIPSERVER1")
        $port = $h.Get_Item("ZIPPORT1")
        $feature = "PROSTREAM1"
        # is it again jingle or commercial?
        if ($samenowplaying -eq $true) {
            Write-Host "Previous and current NOWPLAYING types are same" -ForegroundColor Yellow
            $now = Get-Date -Format HH:mm:ss.fff
            Add-Content -Path $log -Value "$now : [x] Script $scriptstart Previous and current NOWPLAYING types are same ($type). Skipping $feature processing."
            Add-Content -Path $log -Value "$now : [*] Script $scriptstart breaks"
            # deleting current NOWPLAYING
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
            #Break
        } else {
            Write-Host
            Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
            Write-Host
            Write-Host "$feature Message:" -BackgroundColor DarkYellow -ForegroundColor Blue
            New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            if ($h.Get_Item("PROSTREAM2") -eq "TRUE") {
                $remoteHost = $h.Get_Item("ZIPSERVER2")
                $port = $h.Get_Item("ZIPPORT2")
                $feature = "PROSTREAM2"
                Write-Host
                Write-Host "---- Running $feature ----" -BackgroundColor DarkGreen -ForegroundColor White
                Write-Host
                Write-Host "$feature Message:" -BackgroundColor DarkYellow -ForegroundColor Blue
                New-TCPSend -feature $feature -remoteHost $remoteHost -port $port -message $message
            }
            #Remove-Item -Path $csOutFile.FullName
            #if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile.FullName }
        }
    }
}


# Uploading XML to first FTP server
if ( `
        ($h.Get_Item("FTP1") -eq "TRUE") `
        -and (Get-Module -ListAvailable -Name WinSCP) `
        -and ($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "3") `
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

# Uploading XML to sedond FTP server
if ( `
        ($h.Get_Item("FTP2") -eq "TRUE") `
        -and (Get-Module -ListAvailable -Name WinSCP) `
        -and ($xmlfile.root.ELEM_0.Elem.FONO_INFO.Type.'#text' -eq "3") `
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




# cleaning up
# leave temp files if debug
if ($debug -ne $true ) {
    if (Test-Path $dest) { Remove-Item -Path $dest }
    if (Test-Path $sOutFile) { Remove-Item -Path $sOutFile }
    if (Test-Path $csOutFile) { Remove-Item -Path $csOutFile }
}

$now = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $log -Value "$now : [*] Script $scriptstart finished normally"
Write-Host

<#
v1.00 2015-10-09 sending xml to remote FTP sites.
v1.01 2015-10-30 logging send results.
v2.00 2016-01-14 implemented xml parsing.
v2.01 2016-11-17 implemented evaluation element type (music/jingle/commercial); added sending to DEVA RDS-coder.
v2.02 2016-11-18 Capitalizing Artist And Title; implemented RT+ field; added some checkups.
v2.03 2017-03-24 changing host probe from ping to Microsoft PortQuery
v2.04 2017-03-29 more cleanup for Camel Case; settings are now in external config file!
v2.05 2017-05-25 extracting A/T and other values to .json; pushing JSON to HTTP and uploading to FTP only if current type is music;
v2.06 2017-06-06 checking for another instance of script, added "fun with flags".
v2.07 2017-07-26 script remixed for Windows Powershell: changed everything - see README.txt

Usage: uploader.ps1 config.cfg

Config file example:

[Actions]
JSON=TRUE
FTP1=TRUE
FTP2=FALSE
RDS=TRUE
PROSTREAM1=TRUE
PROSTREAM2=TRUE

[XML]
XMLF=\\server\share\EP-MSK.xml
# Using XML from Digispot II Value.Server with XML.Writer module

[RDS]
RDSIP=127.0.0.1
RDSPORT=1024
RDSSITE=www.europaplus.ru
RDSPHONE=+7(495)6204664

[JSON]
JSONSERVER=http://127.0.0.1/post.php

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
ZIPSERVER1=prostream-server1
ZIPPORT1=6001
ZIPSERVER2=prostream-server2
ZIPPORT2=6001

#>
