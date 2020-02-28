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
    This script copies one .xml file to several hosts into \XML share
    
.DESCRIPTION
    Use $servers array to set hosts to copy to.
    Assuming \\host\XML share was created.
    Put this script and runps.bat in the same folder with your .xml

.LINK
    https://github.com/ykmn/uploader/FileMonitor/blob/master/FileMonitor.ps1

.EXAMPLE
    CopyXML.ps1 filename

.PARAMETER filename
    Name of the file to copy

#>
<#
.VERSIONS
    CopyXML.ps1

v1.00 2020-02-26 initial version
#>

# Handling command-line parameters
param (
    [Parameter(Mandatory=$false)][string]$filename
)
if ($filename -eq $null) {
    Write-Host No input file. Use: CopyXML.ps1 filename.xml -ForegroundColor Red
    break
}

$PSscript = Get-Item $MyInvocation.InvocationName
#$PSscript.FullName
#$PSscript.Name
#$PSscript.BaseName
#$PSscript.Extension
#$PSscript.DirectoryName

# please make share \\TECH-INFOSERV1\XML etc.
$servers = "TECH-INFOSERV1", "TECH-INFOSERV2"
$share = "XML"
###############################################################
# setup log files
[string]$currentdir = Get-Location
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

# file available?
if (Test-Path $($currentdir+"\"+$filename))
{
    foreach ($s in $servers)
    {
        # host available?
        if (Test-Connection -ComputerName $s -BufferSize 16 -Count 1 -ErrorAction 0 -Quiet)
        {
            Write-Log -message "[+] $s is available."
            # share available?
            if(Test-Path -Path $("\\"+$s+"\"+$share) ) {
                Copy-Item -Path $filename -Destination $("\\"+$s+"\"+$share)
                if ($Error[0].CategoryInfo.Activity -eq 'Copy-Item')
                {
                    Write-Log -message "[-] $filename was not copied to \\$s\$share, error: $Error[0]" -color Red
                } else {
                    Write-Log -message "[+] $filename successfully copied to \\$s\$share" -color Green
                }
            } else {
                Write-Log -message "[-] Share \\$s\$share is not available" -color Red
            }
        } else {
            Write-Log -message "[-] Host \\$s is not available" -color Red
        }
    }
} else {
    Write-Log -message "[-] $filename not found." -color Red
}
Write-Log -message "** Script finished"
