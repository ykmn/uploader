# make sure you adjust this to point to the folder you want to monitor
$PathToMonitor = "\\TECH-INFOSERV1\C$\XML\"
#$PathToMonitor = "C:\XML\"
$ConfigTable = @{
    'EP-MSK2.xml' = 'ep.cfg';
    'EP-LIGHT.xml' = 'ep-light.cfg';
    'EP-NEW.xml' = 'ep-new.cfg';
    'EP-RESIDANCE.xml' = 'ep-residance.cfg';
    'EP-TOP.xml' = 'ep-top.cfg';
    'EP-Urban.xml' = 'ep-urban.cfg';
    'R7-FM.xml' = 'r7-fm.cfg';
    'R7-MSK.xml' = 'r7-online.cfg';
    'RR-MSK.xml' = 'rr.cfg';
    'RR-INTERNET_1.xml' = 'rr-70.cfg';
    'RR-INTERNET_2.xml' = 'rr-80.cfg';
    'RR-INTERNET_3.xml' = 'rr-90.cfg';
    'DR-MSK.xml' = 'dr-msk.cfg';
    };
    

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "`n`nThis script wowks with PowerShell 5.0 or newer.`nPlease upgrade!`n"
    Break
}
[string]$currentdir = Get-Location
###############################################################
# setup log files
$today = Get-Date -Format yyyy-MM-dd
if (!(Test-Path $currentdir"\log")) {
    New-Item -Path $currentdir"\log" -Force -ItemType Directory | Out-Null
}
$log = $currentdir + "\Log\" + $today + "-Watcher.log"
$scriptstart = Get-Date -Format yyyyMMdd-HHmmss-fff
$now = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $log -Value "$now : ** Script $scriptstart Started"

###############################################################
# FILE MONITOR

# check filesystem changes every $timeout milliseconds
$timeout = 5000
$FileSystemWatcher = New-Object System.IO.FileSystemWatcher $PathToMonitor
$FileSystemWatcher.IncludeSubdirectories = $false
$FileSystemWatcher.Filter = "*.xml"

Write-Host "`nMonitoring content of $PathToMonitor`n"
try
{
    do
    {
        $change = $FileSystemWatcher.WaitForChanged('Changed', $timeout)
        if ($change.TimedOut -eq $false)
        {
            # get information about the changes detected
            Write-Host "`n`nChange in file detected: " -NoNewline
            Write-Host $change.Name -BackgroundColor DarkRed
            # filename.ext
            $pn = $change.Name
            # \\fullpath\filenameonly
            $p = (Get-ChildItem -Path ($PathToMonitor + $change.Name)).BaseName
            $now = Get-Date -Format HH:mm:ss.fff
            Add-Content -Path $log -Value "$now : $p changed"
            
            ForEach ($i in $ConfigTable.Keys) {
                if ($i -eq $pn) {
                    #Write-Host $i
                    $cfg = $ConfigTable[$i]
                }
            }   
            Write-Host $pn -BackgroundColor DarkRed -NoNewline
            Write-Host " corresponds to " -NoNewline
            Write-Host $cfg -BackgroundColor DarkGreen

            # inline start process: it also works
            #Invoke-Command -ScriptBlock { & '.\runps.bat' $args[0] } -ArgumentList $cfg


            $parameters = @{
                ScriptBlock = { Start-Process -WindowStyle Minimized $using:currentdir"\runps.bat" $args[0] }
                ArgumentList = $cfg
                Name = $cfg
            }
            Start-Job @parameters | Receive-Job -Wait -AutoRemoveJob
            $now = Get-Date -Format HH:mm:ss.fff
            Add-Content -Path $log -Value "$now : Job $cfg started"
            Write-Host "Job " -NoNewline
            Write-Host $cfg -BackgroundColor DarkGreen -NoNewline
            Write-Host " started at $now."
            Write-Host "Press ESC to stop all jobs and quit.`n"

        } else {
            if ($count -eq 5)
            {
                $count = 0
                Write-Host "." -NoNewline -ForegroundColor Red
            } else {
                $count = $count +1
                Write-Host ">" -NoNewline
            }
        }
    } until ([System.Console]::KeyAvailable)
}
finally {
    Write-Host "`nQuitting`n"
    #Get-Job | Stop-Job
    Get-Job
    Get-Job -State Completed | Remove-Job
    $now = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $log -Value "$now : [+] Script $scriptstart finished normally."
}









break
<#
###############################################################
# FILE MONITOR
$FileSystemWatcher = New-Object System.IO.FileSystemWatcher
$FileSystemWatcher.Path  = $PathToMonitor
$FileSystemWatcher.IncludeSubdirectories = $true

# make sure the watcher emits events
$FileSystemWatcher.EnableRaisingEvents = $true

# define the code that should execute when a file change is detected
$Action = {
    $details = $event.SourceEventArgs
    $Timestamp = $event.TimeGenerated
    $Name = $details.Name
    $FullPath = $details.FullPath
    $OldName = $details.OldName
    $ChangeType = $details.ChangeType
    $text = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
    Write-Host ""
    Write-Host $text -ForegroundColor Green
    
    # you can also execute code based on change type here
    switch ($ChangeType)
    {
        'Changed' { "CHANGE" }
        'Created' { "CREATED"}
        'Deleted' { "DELETED"
            # uncomment the below to mimick a time intensive handler
            Write-Host "Deletion Handler Start" -ForegroundColor Gray
            Start-Sleep -Seconds 4    
            Write-Host "Deletion Handler End" -ForegroundColor Gray
            
        }
        'Renamed' { 
            # this executes only when a file was renamed
            $text = "File {0} was renamed to {1}" -f $OldName, $Name
            Write-Host $text -ForegroundColor Yellow
        }
        default { Write-Host $_ -ForegroundColor Red -BackgroundColor White }
    }
}

# add event handlers
$handlers = . {
    Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Changed -Action $Action -SourceIdentifier FSChange
    Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Created -Action $Action -SourceIdentifier FSCreate
    Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Deleted -Action $Action -SourceIdentifier FSDelete
    Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Renamed -Action $Action -SourceIdentifier FSRename
}

Write-Host "Watching for changes to $PathToMonitor"

try
{
    do
    {
        Wait-Event -Timeout 1
        if ($count -eq 9)
        {
            $count = 0
            Write-Host $count -NoNewline -ForegroundColor Blue
        } else {
            $count = $count +1
            Write-Host $count -NoNewline
        }
    } until ([System.Console]::KeyAvailable)
}
finally
{
    # this gets executed when user presses CTRL+C
    # remove the event handlers
    Unregister-Event -SourceIdentifier FSChange
    Unregister-Event -SourceIdentifier FSCreate
    Unregister-Event -SourceIdentifier FSDelete
    Unregister-Event -SourceIdentifier FSRename
    # remove background jobs
    $handlers | Remove-Job
    # remove filesystemwatcher
    $FileSystemWatcher.EnableRaisingEvents = $false
    $FileSystemWatcher.Dispose()
    Write-Host "`nEvent Handler disabled."
}
#>