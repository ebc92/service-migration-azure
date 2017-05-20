########################\###/#########################
#########################\O/##########################
##   ______          _                              ##
##  |  ____|        | |                             ##
##  | |__  __  _____| |__   __ _ _ __   __ _  ___   ##
##  |  __| \ \/ / __| '_ \ / _` | '_ \ / _` |/ _ \  ##
##  | |____ >  < (__| | | | (_| | | | | (_| |  __/  ##
##  |______/_/\_\___|_| |_|\__,_|_| |_|\__, |\___|  ##
##                                      __/ |       ##
##                                     |___/        ##
######################################################
######################################################

Param(
  [pscredential]$DomainCredential
)

#Sets data to all parameters from configuration.ini
$fileshare = $SMAConfig.Exchange.fileshare
$baseDir = $SMAConfig.Exchange.basedir
$ComputerName = $SMAConfig.Exchange.destination
$SourceComputer = $SMAConfig.Exchange.source
$fqdn = $SMAConfig.Exchange.fqdn
$newfqdn = $SMAConfig.Exchange.newfqdn
$www = $SMAConfig.Exchange.www
$Password = (ConvertTo-SecureString $SMAConfig.Exchange.password -AsPlainText -Force)

#Specifies log details
$global:xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString() 
$global:xLogPath = "$baseDir\log\"
$xLogName = "SMA-Exchange-$xLogDate.log"
$global:xLogFile = Join-Path -Path $xLogPath -ChildPath $xLogName

$global:InstallSession = New-PSSession -ComputerName $ComputerName -Credential $DomainCredential
$global:SourceInstall = New-PSSession -ComputerName $SourceComputer -Credential $DomainCredential

Log-Start -LogPath $xLogPath -LogName $xLogName -ScriptVersion "1.0"

#Downloads all required files
Log-Write -LogPath $xLogPath -LineValue "Starting Get-Prerequisite"
#Get-Prerequisite -fileShare $fileshare -ComputerName $ComputerName -DomainCredential $DomainCredential -Verbose

#Mount fileshare on source VM
Log-Write -LogPath $xLogPath -LineValue "Starting Mount-FileShare on $SourceComputer"
#Mount-FileShare -DomainCredential $DomainCredential -ComputerName $SourceComputer -baseDir $baseDir -Verbose

#Mount fileshare on target VM
Log-Write -LogPath $xLogPath -LineValue "Starting Mount-FileShare on $ComputerName"
#Mount-FileShare -DomainCredential $DomainCredential -ComputerName $ComputerName -baseDir $baseDir -Verbose

#Mounts the Exchange ISO
Log-Write -LogPath $xLogPath -LineValue "Starting Mount-Exchange"
#Mount-Exchange -FileShare $fileshare -ComputerName $ComputerName -baseDir $baseDir -DomainCredential $DomainCredential -Verbose

#Creates a new certificate to encrypt .mof DSC files
Log-Write -LogPath $xLogPath -LineValue "Starting New-DSCCertificate"
#New-DSCCertificate -ComputerName $ComputerName -DomainCredential $DomainCredential -Verbose

#Compiles .mof files, installs UCMA and starts DSC
Log-Write -LogPath $xLogPath -LineValue "Starting Install-Prerequisite"
#Install-Prerequisite -baseDir $baseDir -ComputerName $ComputerName -DomainCredential $DomainCredential -CertPW $Password -Verbose


#Check if target server needs a reboot before continuing
& Join-Path -Path $PSScriptRoot -ChildPath ..\Support\Start-RebootCheck.ps1" $ComputerName $DomainCredential"

#Starts a 30 minute sleep to give the server time for the end of install configuration, before moving on
Log-Write -LogPath $xLogPath -LineValue "Sleeping for 30 minutes to give the Exchange server time to finish configuration"
Start-Sleep -Seconds 1800

<#      
Do {
  Write-Verbose -Message "Sleeping for 1 minute, then checking if LCM is done configuring"
  Start-Sleep -Seconds 60
  $DSCDone = Invoke-Command -Session $InstallSession -ScriptBlock {
    Get-DscLocalConfigurationManager
  }
} while ($DSCDone.LCMState -ne "Idle") #>

#Gets the Exchange Certificate and exports it
Log-Write -LogPath $xLogPath -LineValue "Exporting Exchange Certificate"
Export-ExchCert -SourceComputer $SourceComputer -fqdn $fqdn -Password $Password -DomainCredential $DomainCredential -BaseDir $baseDir -Verbose

#Configures all Exchange settings
Log-Write -LogPath $xLogPath -LineValue "Starting Exchange Configuration"
Configure-Exchange -ComputerName $ComputerName -SourceComputer $SourceComputer -newfqdn $newfqdn -Password $Password -DomainCredential $DomainCredential -hostname $www -BaseDir $baseDir -Verbose

$SourceInstall | Remove-PSSession
$InstallSession | Remove-PSSession

Log-Finish -LogPath $xLogFile -NoExit $true