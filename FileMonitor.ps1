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
    This script monitors changes of *.XML in specified folder $PathToMonitor and executes runps.bat ?.cfg
    
.DESCRIPTION
    Use $ConfigTable array to set dependencies between XML filename and .cfg for uploader2.ps1

.LINK
    https://github.com/ykmn/uploader/blob/master/FileMonitor.ps1

.EXAMPLE
    .\FileMonitor.ps1
#>
<#
.VERSIONS
    FileMonitor.ps1

v1.00 2010-01-17 initial version
#>


# make sure you adjust this to point to the folder you want to monitor
$PathToMonitor = "\\TECH-INFOSERV1\C$\XML\"
#$PathToMonitor = "C:\XML\"
$ConfigTable = @{
    'EP-MSK2.xml'       = 'ep.cfg';
    'EP-LIGHT.xml'      = 'ep-light.cfg';
    'EP-NEW.xml'        = 'ep-new.cfg';
    'EP-RESIDANCE.xml'  = 'ep-residance.cfg';
    'EP-TOP.xml'        = 'ep-top.cfg';
    'EP-Urban.xml'      = 'ep-urban.cfg';
    'R7-FM.xml'         = 'r7-fm.cfg';
    'R7-MSK.xml'        = 'r7-online.cfg';
    'RR-MSK.xml'        = 'rr.cfg';
    'RR-INTERNET_1.xml' = 'rr-70.cfg';
    'RR-INTERNET_2.xml' = 'rr-80.cfg';
    'RR-INTERNET_3.xml' = 'rr-90.cfg';
    'DR-MSK.xml'        = 'dr-msk.cfg';
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
            Write-Host "`nFile change detected: " -NoNewline
            Write-Host $change.Name -BackgroundColor DarkRed -NoNewline
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
            Write-Host " corresponds to " -NoNewline
            Write-Host $cfg -BackgroundColor DarkGreen -NoNewline
            Write-Host ". " -NoNewline

            # windowstyle = maximized, minimized or hidden
            $p = Start-Process ".\runps.bat" -ArgumentList $cfg -WindowStyle Maximized
            $p.ExitCode



            # inline start process: it works
            #Invoke-Command -ScriptBlock { & '.\runps.bat' $args[0] } -ArgumentList $cfg

            # start job is ok but not really
            # $parameters = @{
            #     ScriptBlock = { Start-Process -WindowStyle Minimized $using:currentdir"\runps.bat" $args[0] }
            #     ArgumentList = $cfg
            #     Name = $cfg
            # }
            #Start-Job @parameters | Receive-Job -Wait -AutoRemoveJob

          
            $now = Get-Date -Format HH:mm:ss.fff
            # Add-Content -Path $log -Value "$now : Job $cfg started"
            # Write-Host "Job" $cfg "started at $now."
            Add-Content -Path $log -Value "$now : $cfg started"
            Write-Host "Process for" $cfg "started at $now."
            
            
            
            Write-Host "Press ESC and wait up to 5 seconds for stop all jobs and quit."
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

#break