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

v1.05 2020-02-27 cyrillic files are renaming from $ConfigTable.Xml to $ConfigTable.Dst
v1.04 2020-02-25 improved logging
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
#[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("UTF8")
#[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("oem")

# check filesystem changes every $timeout milliseconds
$timeout = 10
# make sure you adjust this to point to the folder you want to monitor

# make sure you adjust this to point to the folder you want to monitor. Don't forget trailing slash!
$PathToMonitor = "C:\XML\"
#$PathToMonitor = "\\TECH-INFOSERV1\XML\"
$DJinPath = "C:\Program Files (x86)\Digispot II\DJin_ValueServerCombo\DJin\"
Write-Host "`nFileMonitor.ps1   v1.06 2020-03-10"
Write-Host "Monitoring content of $PathToMonitor for changes every $timeout ms`n"

<#
    [PSCustomObject]@{        Xml = 'EP-MSK2.xml';          Cfg = 'ep.cfg';              Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'EP-LIGHT.xml';         Cfg = 'ep-light.cfg';        Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'EP-NEW.xml';           Cfg = 'ep-new.cfg';          Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'EP-RESIDANCE.xml';     Cfg = 'ep-residance.cfg';    Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'EP-TOP.xml';           Cfg = 'ep-top.cfg';          Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'EP-Urban.xml';         Cfg = 'ep-urban.cfg';        Dst = '';           Exe = '.\runps.bat' },

    [PSCustomObject]@{        Xml = 'RR-MSK.xml';           Cfg = 'rr.cfg';              Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'RR-INTERNET_1.xml';    Cfg = 'rr-70.cfg';           Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'RR-INTERNET_2.xml';    Cfg = 'rr-80.cfg';           Dst = '';           Exe = '.\runps.bat' },
    [PSCustomObject]@{        Xml = 'RR-INTERNET_3.xml';    Cfg = 'rr-90.cfg';           Dst = '';           Exe = '.\runps.bat' },
#>
$ConfigTable = @(
    [PSCustomObject]@{ Xml = 'R7-FM.xml';            Cfg = 'r7-fm.cfg';           Dst = '';         Exe = '.\runps.bat' },
    [PSCustomObject]@{ Xml = 'R7-MSK.xml';           Cfg = 'r7-online.cfg';       Dst = '';     Exe = '.\runps.bat' },
    [PSCustomObject]@{ Xml = 'DR-MSK.xml';           Cfg = 'dr-msk.cfg';          Dst = '';        Exe = '.\runps.bat' },

    [PSCustomObject]@{ Xml = 'РЕТРО-МОСКВА.xml';     Cfg = 'rr.cfg';              Dst = 'RR-MSKv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'РЕТРО_FM-70.xml';      Cfg = 'rr-70.cfg';           Dst = 'RR-INTERNET_1v3.xml'; Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'РЕТРО_FM-80.xml';      Cfg = 'rr-80.cfg';           Dst = 'RR-INTERNET_2v3.xml'; Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'РЕТРО_FM-90.xml';      Cfg = 'rr-90.cfg';           Dst = 'RR-INTERNET_3v3.xml'; Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'ЕВРОПА-МОСКВА.xml';    Cfg = 'ep.cfg';              Dst = 'EP-MSK2v3.xml';       Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-NEW.xml';       Cfg = 'ep-new.cfg';          Dst = 'EP-NEWv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-RESIDANCE.xml'; Cfg = 'ep-residance.cfg';    Dst = 'EP-RESIDANCEv3.xml';  Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-TOP.xml';       Cfg = 'ep-top.cfg';          Dst = 'EP-TOPv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-Urban.xml';     Cfg = 'ep-urban.cfg';        Dst = 'EP-URBANv3.xml';      Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-LIGHT.xml';     Cfg = 'ep-light.cfg';        Dst = 'EP-LIGHTv3.xml';      Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'Radio7_MOS.xml';       Cfg = 'r7-fm-v3.cfg';        Dst = 'R7-FMv3.xml';         Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'Radio7_REG.xml';       Cfg = 'r7-online-v3.cfg';    Dst = 'R7-ONLINEv3.xml';     Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'DR-MOSCOW.xml';        Cfg = 'dr-msk-v3.cfg';       Dst = 'DR-MSKv3.xml';        Exe = '.\runps3.bat' }

    

);
    
if ($PSVersionTable.PSVersion.Major -lt 5)
{
    Write-Host "`n`nThis script works with PowerShell 5.0 or newer.`nPlease upgrade!`n"
    Break
}

###############################################################
# setup log files
[string]$currentdir = Get-Location
$PSscript = Get-Item $MyInvocation.InvocationName
#Write-Host $PSscript.FullName $PSscript.Name $PSscript.BaseName $PSscript.Extension $PSscript.DirectoryName 
if (!(Test-Path $currentdir"\log"))
{
    New-Item -Path $currentdir"\log" -Force -ItemType Directory | Out-Null
}
function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$false)][string]$color
    )
    #$logfile = $currentdir + "\log\" + $(Get-Date -Format yyyy-MM-dd) + "-" + $MyInvocation.MyCommand.Name + ".log"
    $logfile = $currentdir + "\log\" + $(Get-Date -Format yyyy-MM-dd) + "-" + $PSscript.BaseName + ".log"
    $now = Get-Date -Format HH:mm:ss.fff
    $message = "$now : " + $message
    if (!($color)) {
        Write-Host $message    
    } else {
        Write-Host $message -ForegroundColor $color
    }
    $message | Out-File $logfile -Append -Encoding "UTF8"
    
}
Write-Log -message "** Script started"


###############################################################
# FILE MONITOR

$FileSystemWatcher = New-Object System.IO.FileSystemWatcher $PathToMonitor
$FileSystemWatcher.IncludeSubdirectories = $false
$FileSystemWatcher.Filter = "*.xml"

# Check for availability
if (!(Test-Path $PathToMonitor))
{
    Write-Log -message "[-] Path $PathToMonitor is not available"
    break
}
if (!(Test-Path $PathToMonitor"UPLOAD\"))
{
    New-Item -Path $PathToMonitor"UPLOAD\" -Force -ItemType Directory | Out-Null
    Write-Log -message "[*] Path $PathToMonitor UPLOAD\ is not available, creating."
}

# If $force = $true then we process all XML/cfg before folder monitoring starts
if ($forced)
{
    Write-Host "First run: "

    for ($n=0; $n -lt $ConfigTable.count; $n++)
    {
        $cfgFM = $ConfigTable[$n].Cfg
        $execute = $ConfigTable[$n].Exe
        $p = Start-Process $execute -ArgumentList $cfgFM -WindowStyle Maximized
        $p.ExitCode
        Write-Log -message "[*] First-run $execute $cfgFM"
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
            # filename.ext
            $pn = $change.Name
            # \\fullpath\filenameonly
            $p = (Get-ChildItem -Path ($PathToMonitor + $change.Name)).BaseName
            Write-Log -message "File $p was changed" -color Green
            # Search $ConfigTable for parameters corresponding filename
            for ($n=0; $n -lt $ConfigTable.count; $n++)
            {
                if ($ConfigTable[$n].Xml -like $pn)
                {
                    # get array values
                    $cfgFM = $ConfigTable[$n].Cfg
                    $execute = $ConfigTable[$n].Exe
                    $dst = $PathToMonitor + "UPLOAD\" +$ConfigTable[$n].Dst
                    Write-Log -message "$p corresponds to $cfgFM and to uploader $execute" -color Green
                    if ($ConfigTable[$n].Dst -eq '') {
                        Write-Log "[*] no .Dst defined, skip XML copy" -color Yellow
                    } else {
                        # $ConfigTable[$n].Dst is defined
                        $Error.Clear()
                        try {
                            Copy-Item -Path $($PathToMonitor+$pn) -Destination $dst -Force -ErrorAction 0    
                        }
                        catch {
                            Write-Log "[-] File $PathToMonitor$pn was not copied to $dst, error: $($Error[0])" -color Red
                        }
                    }
                }
            }
        
            # Did we found $cfgFM for changed XML file in $ConfigTable?
            if ($null -ne $cfgFM)
            {
                # windowstyle = maximized, minimized or hidden
                $p = Start-Process $execute -ArgumentList $cfgFM -WindowStyle Hidden
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
          
                Write-Log -message "Started $execute $cfgFM"
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
                    Write-Log -message "[-] DJin is not running. Starting..." -color Red

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
    Write-Log -message "** Script finished normally."
}
[Console]::OutputEncoding = $encoding
