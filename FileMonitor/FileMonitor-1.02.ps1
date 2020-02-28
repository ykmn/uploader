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
    Use $ConfigTable array to set dependencies between XML filename and .cfg for uploader3.ps1

.LINK
    https://github.com/ykmn/uploader/blob/master/FileMonitor.ps1

.EXAMPLE
    FIleMonitor.ps1 [-force]

.PARAMETER force
    Force initial uploads before monitoring starts.

#>
<#
.VERSIONS
    FileMonitor.ps1

v1.02 2020-02-18 fixed XML-$cfg filtering
v1.01 2020-02-03 added DJin.exe watchdog
v1.00 2020-01-17 initial version
#>
# Handling command-line parameters
param (
    [Parameter(Mandatory=$false)][switch]$forced
)

# check filesystem changes every $timeout milliseconds
$timeout = 25
# make sure you adjust this to point to the folder you want to monitor

# make sure you adjust this to point to the folder you want to monitor. Don't forget trailing slash!
#$PathToMonitor = "\\TECH-INFOSERV1\XML\"
#$DJinPath = "C:\Program Files (x86)\Digispot II\217\Djin ALL\"
$PathToMonitor = "C:\XML\"
$DJinPath = "C:\Program Files (x86)\Digispot II\DJin_ValueServerCombo\DJin\"

$ConfigTable = @{
    'EP-MSK2.xml'       = 'ep.cfg';
    'RR-MSK.xml'        = 'rr.cfg';
    'R7-FM.xml'         = 'r7-fm.cfg';
    'EP-LIGHT.xml'      = 'ep-light.cfg';
    'EP-NEW.xml'        = 'ep-new.cfg';
    'EP-RESIDANCE.xml'  = 'ep-residance.cfg';
    'EP-TOP.xml'        = 'ep-top.cfg';
    'EP-Urban.xml'      = 'ep-urban.cfg';
    'R7-MSK.xml'        = 'r7-online.cfg';
    'RR-INTERNET_1.xml' = 'rr-70.cfg';
    'RR-INTERNET_2.xml' = 'rr-80.cfg';
    'RR-INTERNET_3.xml' = 'rr-90.cfg';
    'DR-MSK.xml'        = 'dr-msk.cfg';
};
    
if ($PSVersionTable.PSVersion.Major -lt 5)
{
    Write-Host "`n`nThis script wowks with PowerShell 5.0 or newer.`nPlease upgrade!`n"
    Break
}
[string]$currentdir = Get-Location
###############################################################
# setup log files

$today = Get-Date -Format yyyy-MM-dd
if (!(Test-Path $currentdir"\log"))
{
    New-Item -Path $currentdir"\log" -Force -ItemType Directory | Out-Null
}
$logFM = $currentdir + "\Log\" + $today + "-Watcher.log"
$scriptstartFM = Get-Date -Format yyyyMMdd-HHmmss-fff
$nowFM = Get-Date -Format HH:mm:ss.fff
Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM ** Script started"

###############################################################
# FILE MONITOR

$FileSystemWatcher = New-Object System.IO.FileSystemWatcher $PathToMonitor
$FileSystemWatcher.IncludeSubdirectories = $false
$FileSystemWatcher.Filter = "*.xml"

Write-Host "`nFileMonitor.ps1   v1.02 2020-02-18"
Write-Host "Monitoring content of $PathToMonitor for changes every $timeout ms`n"

# If $force = $true then we process all XML/cfg before folder monitoring starts
if ($forced)
{
    Write-Host "First run of: " -NoNewline
    ForEach ($i in $ConfigTable.Keys)
    {
         $cfgFM = $ConfigTable[$i]
         $p = Start-Process ".\runps.bat" -ArgumentList $cfgFM -WindowStyle Maximized
         $p.ExitCode
         Write-Host $cfgFM", " -NoNewline
         $nowFM = Get-Date -Format HH:mm:ss.fff
         Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM ** First-run for $cfg"
         Start-Sleep -Milliseconds 1500
    }
}

# Monitoring folder
Write-Host "`n"
try
{
    do
    {
        # In case of we find changed XML not described in $ConfigTable:
        $cfgFM = $null
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
            $nowFM = Get-Date -Format HH:mm:ss.fff
            Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM File $p was changed"
            
            ForEach ($i in $ConfigTable.Keys)
            {
                if ($i -eq $pn)
                {
                    #Write-Host $i
                    $cfgFM = $ConfigTable[$i]
                }
            }   
            Write-Host " corresponds to " -NoNewline
            Write-Host $cfgFM -BackgroundColor DarkGreen -NoNewline
            Write-Host ". " -NoNewline

            
            # Did we found $cfgFM for changed XML file in $ConfigTable?
            if ($null -ne $cfgFM) {
                # windowstyle = maximized, minimized or hidden
                $p = Start-Process ".\runps.bat" -ArgumentList $cfgFM -WindowStyle Hidden
                $p.ExitCode

                # inline start process: it also works
                #Invoke-Command -ScriptBlock { & '.\runps.bat' $args[0] } -ArgumentList $cfgFM

                # Start-Job is kinda ok but not really
                # $parameters = @{
                #     ScriptBlock = { Start-Process -WindowStyle Minimized $using:currentdir"\runps.bat" $args[0] }
                #     ArgumentList = $cfgFM
                #     Name = $cfgFM
                # }
                #Start-Job @parameters | Receive-Job -Wait -AutoRemoveJob
          
                $nowFM = Get-Date -Format HH:mm:ss.fff
                # Add-Content -Path $logFM -Value "$nowFM : Job $cfgFM started"
                # Write-Host "Job" $cfgFM "started at $nowFM."
                Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM Started Uploader for $cfgFM"
                Write-Host "Process for" $cfgFM "started at $nowFM."
            }
            
            Write-Host "Press ESC to stop."
            $count = 0
        } else {
            if ($count -eq 9)
            {
                $count = 0
                Write-Host "." -NoNewline -ForegroundColor Red
                if (!(Get-Process | where {$PSItem.ProcessName -eq 'DJin'}))
                {
                    # DJin is not running
		            $nowFM = Get-Date -Format HH:mm:ss.fff
        		    Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM [-] DJin is not running. Starting..."
                    Write-Host "`nDJin is not running. Starting DJin.exe...`n" -ForegroundColor Yellow -BackgroundColor Red
                    & $DJinPath'\DJin.exe'
                    Start-Sleep -Seconds 10
                }
            } else {
                $count = $count +1
                Write-Host ">" -NoNewline
            }
        }
    } until ([System.Console]::KeyAvailable)
}
finally {
    Write-Host "`nQuitting`n`n`n"
    # Get-Job | Stop-Job
    # Get-Job
    # Get-Job -State Completed | Remove-Job
    $nowFM = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM [+] Script finished normally."
}

#break