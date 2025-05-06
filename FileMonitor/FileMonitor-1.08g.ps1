<#
.NOTES
    Copyright (c) Roman Ermakov <r.ermakov@emg.fm>
    Use of this sample source code is subject to the terms of the
    GNU General Public License under which you licensed this sample source code.
    If you did not accept the terms of the license agreement, you are not
    authorized to use this sample source code.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    THIS CODE IS PROVIDED "AS IS" WITH NO WARRANTIES.
    
.SYNOPSIS
    This script monitors changes of *.XML in specified folder $PathToMonitor and, when changed, executes runps.bat ?.cfg
    
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
    v1.08 2025-04-04 switched to polling instead of FileSystemWatcher due to event issues
    v1.07 2025-04-03 switched to async event-based monitoring, increased buffer size, added error handling
    v1.06 2020-02-10 removed DJin.ValueServer watchdog; 
    v1.05 2020-02-27 cyrillic files are renaming from $ConfigTable.Xml to $ConfigTable.Dst
    v1.04 2025-02-25 improved logging
    v1.03 2020-02-20 added configuration array for link XML with .cfg and executable/batch
    v1.02 2020-02-18 fixed XML-$cfg filtering
    v1.01 2020-02-03 added DJin.exe watchdog
    v1.00 2020-01-17 initial version
#>

param (
    [Parameter(Mandatory=$false)][switch]$forced
)

$encoding = [Console]::OutputEncoding

# Folder polling time, msec
$delay = 250

# Folder to monitor (adjust as needed)
$PathToMonitor = "C:\XML\"
#$PathToMonitor = "\\server\XML\"
Write-Host "`nFileMonitor.ps1                                              v1.08g 2025-04-04"
Write-Host "Monitoring content of $PathToMonitor for changes: $delay msec polling method)`n"

$ConfigTable = @(
    [PSCustomObject]@{ Xml = 'ЕВРОПА-МОСКВА.xml';    Cfg = 'ep.cfg';           Dst = 'EP-MSK2v3.xml';       Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-SAT_0.xml';     Cfg = 'ep0.cfg';          Dst = 'EP-0v3.xml';          Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'ЕВРОПА-NEW.xml';       Cfg = 'ep-new.cfg';       Dst = 'EP-NEWv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-RESIDANCE.xml'; Cfg = 'ep-residance.cfg'; Dst = 'EP-RESIDANCEv3.xml';  Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-TOP.xml';       Cfg = 'ep-top.cfg';       Dst = 'EP-TOPv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-Urban.xml';     Cfg = 'ep-urban.cfg';     Dst = 'EP-URBANv3.xml';      Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'ЕВРОПА-LIGHT.xml';     Cfg = 'ep-light.cfg';     Dst = 'EP-LIGHTv3.xml';      Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'DR-SAT.xml';           Cfg = 'dr-sat.cfg';       Dst = 'DR-SATv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'DR-MOSCOW.xml';        Cfg = 'dr-msk.cfg';       Dst = 'DR-MSKv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'WEB-ONLINE.xml';       Cfg = 'dr-web.cfg';       Dst = 'DR-WEBv3.xml';        Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'РЕТРО-МОСКВА.xml';     Cfg = 'rr.cfg';           Dst = 'RR-MSKv3.xml';        Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'РЕТРО-SAT_0.xml';      Cfg = 'rr0.cfg';          Dst = 'RR-0v3.xml';          Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'РЕТРО_FM-70.xml';      Cfg = 'rr-70.cfg';        Dst = 'RR-INTERNET_1v3.xml'; Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'РЕТРО_FM-80.xml';      Cfg = 'rr-80.cfg';        Dst = 'RR-INTERNET_2v3.xml'; Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'РЕТРО_FM-90.xml';      Cfg = 'rr-90.cfg';        Dst = 'RR-INTERNET_3v3.xml'; Exe = '.\runps3.bat' },

    [PSCustomObject]@{ Xml = 'Radio7_MOS.xml';       Cfg = 'r7-fm.cfg';        Dst = 'R7-FMv3.xml';         Exe = '.\runps3.bat' },
    [PSCustomObject]@{ Xml = 'Radio7_REG.xml';       Cfg = 'r7-online.cfg';    Dst = 'R7-ONLINEv3.xml';     Exe = '.\runps3.bat' }
)

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "`n`nThis script works with PowerShell 5.0 or newer.`nPlease upgrade!`n"
    exit
}

# Setup log files
[string]$currentdir = Get-Location
$PSscript = Get-Item $MyInvocation.InvocationName
if (!(Test-Path "$currentdir\log")) {
    New-Item -Path "$currentdir\log" -Force -ItemType Directory | Out-Null
    Write-Log -message "[DEBUG] Created log directory: $currentdir\log" -color Cyan
}

function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$false)][string]$color
    )
    $logfile = "$currentdir\log\$(Get-Date -Format yyyy-MM-dd)-$($PSscript.BaseName).log"
    $now = Get-Date -Format HH:mm:ss.fff
    $message = "$(Get-Date -Format HH:mm:ss.fff) : $message"
    if ($color) {
        Write-Host $message -ForegroundColor $color
    } else {
        Write-Host $message
    }
    $message | Out-File $logfile -Append -Encoding "UTF8"
}

Write-Log -message "******* Script started"
Write-Log -message "[DEBUG] Current directory: $currentdir" -color Cyan
Write-Log -message "[DEBUG] Monitoring path: $PathToMonitor" -color Cyan

# Check for availability and list files
if (!(Test-Path $PathToMonitor)) {
    Write-Log -message "[ERROR] Path $PathToMonitor is not available" -color Red
    exit
}
Write-Log -message "[DEBUG] Path $PathToMonitor is accessible" -color Cyan
$files = Get-ChildItem -Path $PathToMonitor -Filter "*.xml"
if ($files.Count -eq 0) {
    Write-Log -message "[WARN] No .XML files found in $PathToMonitor" -color Yellow
} else {
    Write-Log -message "[DEBUG] Found $($files.Count) .XML files in $PathToMonitor :" -color Cyan
    foreach ($file in $files) {
        Write-Log -message "[DEBUG] - $($file.Name)" -color Cyan
    }
}

# Skip copying XML to subfolder
# if (!(Test-Path "$PathToMonitor\UPLOAD\")) {
#     New-Item -Path "$PathToMonitor\UPLOAD\" -Force -ItemType Directory | Out-Null
#     Write-Log -message "[INFO] Path $PathToMonitor\UPLOAD\ is not available, creating."
#     Write-Log -message "[DEBUG] Created UPLOAD directory: $PathToMonitor\UPLOAD\" -color Cyan
# }

# Verify executable exists
#$exePath = "$currentdir\runps3.bat"

#if (!(Test-Path $exePath)) {
#    Write-Log -message "[ERROR] Executable $exePath not found" -color Red
#} else {
#    Write-Log -message "[DEBUG] Executable found: $exePath" -color Cyan
#}

# Force initial uploads if -force is specified
if ($forced) {
    Write-Host "First run: "
    Write-Log -message "[WARN] Starting forced initial run" -color Yellow
    foreach ($config in $ConfigTable) {
        $cfgFM = $config.Cfg
        $execute = $config.Exe
        $fullExePath = Join-Path $currentdir $execute
        if (Test-Path $fullExePath) {
            Write-Log -message "[DEBUG] Executing $fullExePath with $cfgFM" -color Cyan
            Start-Process -FilePath $fullExePath -ArgumentList $cfgFM -Wait
            Write-Log -message "[INFO] First-run $execute $cfgFM" -color Green
        } else {
            Write-Log -message "[ERROR] Executable $fullExePath not found during first run" -color Red
            break
        }
    }
}

# Initialize file tracking
$fileTimestamps = @{}
foreach ($file in (Get-ChildItem -Path $PathToMonitor -Filter "*.xml")) {
    $fileTimestamps[$file.Name] = $file.LastWriteTime
}
Write-Log -message "[DEBUG] Initialized file timestamps for monitoring" -color Cyan

# Polling loop
Write-Host "Monitoring started (polling every" $delay "seconds). Press Ctrl+C to stop." -BackgroundColor Green -ForegroundColor Black
Write-Log -message "[DEBUG] Starting polling loop with $delay ms interval" -color Cyan
try {
    do {
        $currentFiles = Get-ChildItem -Path $PathToMonitor -Filter "*.xml"
        foreach ($file in $currentFiles) {
            $fileName = $file.Name
            $lastWriteTime = $file.LastWriteTime

            if (-not $fileTimestamps.ContainsKey($fileName)) {
                # New file detected
                Write-Log -message "[DEBUG] New file detected: $fileName, last write: $lastWriteTime" -color Cyan
                $fileTimestamps[$fileName] = $lastWriteTime
            } elseif ($fileTimestamps[$fileName] -ne $lastWriteTime) {
                # File changed
                Write-Log -message "[DEBUG] File changed: $fileName, last write: $lastWriteTime" -color Cyan
                $fileTimestamps[$fileName] = $lastWriteTime

                foreach ($config in $ConfigTable) {
                    if ($config.Xml -eq $fileName) {
                        Write-Log -message "[DEBUG] Matched $fileName in ConfigTable" -color Cyan
                        $cfgFM = $config.Cfg
                        $execute = $config.Exe

# Skip copying XML to subfolder
#                        $dst = "$PathToMonitor\UPLOAD\$($config.Dst)"
#                        if ([string]::IsNullOrEmpty($config.Dst)) {
#                            Write-Log -message "[INFO] No .Dst defined, skipping XML copy" -color Yellow
#                        } else {
#                            Write-Log -message "[DEBUG] Attempting to copy $fileName to $dst" -color Cyan
#                            try {
#                                Copy-Item -Path $file.FullName -Destination $dst -Force -ErrorAction Stop
#                                Write-Log -message "[INFO] Copied $fileName to $dst"
#                            } catch {
#                                Write-Log -message "[ERROR] Failed to copy $fileName to $dst, error: $_" -color Red
#                            }
#                        }

                        if ($cfgFM) {
                            $fullExePath = Join-Path $currentdir $execute
                            Write-Log -message "[DEBUG] Config found: $cfgFM, executable: $fullExePath" -color Cyan
                            if (Test-Path $fullExePath) {
                                Write-Log -message "[DEBUG] Starting $fullExePath with $cfgFM" -color Cyan
                                Start-Process -FilePath $fullExePath -ArgumentList $cfgFM -WindowStyle Hidden
                                Write-Log -message "[INFO] Started $execute $cfgFM" -color Green
                            } else {
                                Write-Log -message "[ERROR] Executable $fullExePath not found" -color Red
                            }
                        }
                        break
                    }
                }
            }
        }
        Start-Sleep -Milliseconds $delay  # Poll every 0.5 seconds
    } while ($true)
} finally {
    Write-Log -message "[DEBUG] Stopping polling loop" -color Cyan
    Write-Log -message "[INFO] Script finished normally." -color Green
    Write-Log -message "********************************"
    [Console]::OutputEncoding = $encoding
}
