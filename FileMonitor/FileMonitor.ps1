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
    https://github.com/ykmn/uploader/FileMonitor/blob/master/FileMonitor.ps1

.EXAMPLE
    FIleMonitor.ps1 [-force]

.PARAMETER force
    Force initial uploads before monitoring starts.

#>
<#
.VERSIONS
    FileMonitor.ps1

v1.03 2020-02-20 added configuration array for link XML with .cfg and executable/batch
v1.02 2020-02-18 fixed XML-$cfg filtering
v1.01 2020-02-03 added DJin.exe watchdog
v1.00 2020-01-17 initial version
#>
# Handling command-line parameters
param (
    [Parameter(Mandatory=$false)][switch]$forced
)

$encoding = [Console]::OutputEncoding
#[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
#[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("oem")

# check filesystem changes every $timeout milliseconds
$timeout = 20
# make sure you adjust this to point to the folder you want to monitor

# make sure you adjust this to point to the folder you want to monitor. Don't forget trailing slash!
$PathToMonitor = "C:\XML\"
$DJinPath = "C:\Program Files (x86)\Digispot II\DJin_ValueServerCombo\DJin\"

$ConfigTable = @(
    [PSCustomObject]@{
        Xml = 'EP-MSK2.xml'
        Cfg = 'ep.cfg'
        Exe = '.\runps.bat' },
    [PSCustomObject]@{
        Xml = 'RR-MSK.xml'
        Cfg = 'rr.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'R7-FM.xml'
        Cfg = 'r7-fm.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'R7-MSK.xml'
        Cfg = 'r7-online.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'EP-LIGHT.xml'
        Cfg = 'ep-light.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'EP-NEW.xml'
        Cfg = 'ep-new.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'EP-RESIDANCE.xml'
        Cfg = 'ep-residance.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'EP-TOP.xml'
        Cfg = 'ep-top.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'EP-Urban.xml'
        Cfg = 'ep-urban.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'RR-INTERNET_1.xml'
        Cfg = 'rr-70.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'RR-INTERNET_2.xml'
        Cfg = 'rr-80.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'RR-INTERNET_3.xml'
        Cfg = 'rr-90.cfg'
        Exe = '..\v2\runps.bat' },
    [PSCustomObject]@{
        Xml = 'DR-MSK.xml'
        Cfg = 'dr-msk.cfg'
        Exe = '..\v2\runps.bat' },

    [PSCustomObject]@{
        Xml = 'перпн-лняйбю.xml'
        Cfg = 'rr-v3.cfg'
        Exe = '.\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'перпн_FM-70.xml'
        Cfg = 'rr-70-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'перпн_FM-80.xml'
        Cfg = 'rr-80-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'перпн_FM-90.xml'
        Cfg = 'rr-90-v3.cfg'
        Exe = '..\v3\runps3.bat' },

    [PSCustomObject]@{
        Xml = 'Radio7_MOS.xml'
        Cfg = 'r7-fm-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'Radio7_REG.xml'
        Cfg = 'r7-online-v3.cfg'
        Exe = '..\v3\runps3.bat' },

    [PSCustomObject]@{
        Xml = 'ебпною-лняйбю.xml'
        Cfg = 'ep-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'ебпною-NEW.xml'
        Cfg = 'ep-new-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'ебпною-RESIDANCE.xml'
        Cfg = 'ep-residance-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'ебпною-TOP.xml'
        Cfg = 'ep-top-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'ебпною-Urban.xml'
        Cfg = 'ep-urban-v3.cfg'
        Exe = '..\v3\runps3.bat' },
    [PSCustomObject]@{
        Xml = 'ебпною-LIGHT.xml'
        Cfg = 'ep-light-v3.cfg'
        Exe = '..\v3\runps3.bat' },

    [PSCustomObject]@{
        Xml = 'DR-MOSCOW.xml'
        Cfg = 'dr-msk-v3.cfg'
        Exe = '..\v3\runps3.bat' }

    

);
    
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

Write-Host "`nFileMonitor.ps1   v1.03 2020-02-25"
Write-Host "Monitoring content of $PathToMonitor for changes every $timeout ms`n"

# If $force = $true then we process all XML/cfg before folder monitoring starts
if ($forced)
{
    Write-Host "First run of: " -NoNewline

    for ($n=0; $n -lt $ConfigTable.count; $n++)
    {
        $cfgFM = $ConfigTable[$n].Cfg
        $execute = $ConfigTable[$n].Exe
        $p = Start-Process $execute -ArgumentList $cfgFM -WindowStyle Maximized
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
            
            # Search $ConfigTable for parameters corresponding filename
            for ($n=0; $n -lt $ConfigTable.count; $n++)
            {
                if ($ConfigTable[$n].Xml -like $pn)
                {
                    $cfgFM = $ConfigTable[$n].Cfg
                    $execute = $ConfigTable[$n].Exe
                }
            }
        
            Write-Host " corresponds to " -NoNewline
            Write-Host $cfgFM -BackgroundColor DarkGreen -NoNewline
            Write-Host ". " -NoNewline
            
            # Did we found $cfgFM for changed XML file in $ConfigTable?
            if ($null -ne $cfgFM)
            {
                # windowstyle = maximized, minimized or hidden
                $p = Start-Process $execute -ArgumentList $cfgFM -WindowStyle Hidden
                $p.ExitCode

                # inline start process: it also works
                #Invoke-Command -ScriptBlock { & '..\v2\runps.bat' $args[0] } -ArgumentList $cfgFM

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
                Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM Started $execute Uploader for $cfgFM"
                Write-Host "Process $execute for $cfgFM started at $nowFM."
            }
            
            Write-Host "Press ESC to stop."
            $count = 0
        } else {
            if ($count -eq 9)
            {
                $count = 0
                Write-Host "." -NoNewline -ForegroundColor Red
                if (!(Get-Process | Where-Object {$PSItem.ProcessName -eq 'DJin'}))
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
finally
{
    Write-Host "`nQuitting`n`n`n"
    # Get-Job | Stop-Job
    # Get-Job
    # Get-Job -State Completed | Remove-Job
    $nowFM = Get-Date -Format HH:mm:ss.fff
    Add-Content -Path $logFM -Value "$nowFM : $scriptstartFM [+] Script finished normally."
}
[Console]::OutputEncoding = $encoding
