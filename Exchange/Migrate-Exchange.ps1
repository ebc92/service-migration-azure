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

Log-Start -LogPath $xLogPath -LogName $xLogName -ScriptVersion "1.0"

#Downloads all required files
Get-Prerequisite -fileShare $fileshare -ComputerName $ComputerName -DomainCredential $DomainCredential

#Mount fileshare on source VM
Mount-FileShare $fileshare -DomainCredential $DomainCredential -ComputerName $ComputerName -baseDir $baseDir

#Mount fileshare on target VM
Mount-FileShare -DomainCredential $DomainCredential -ComputerName $ComputerName -baseDir $baseDir

#Mounts the Exchange ISO
Mount-Exchange -FileShare $fileshare -ComputerName $ComputerName -baseDir $baseDir -DomainCredential $DomainCredential

#Creates a new certificate to encrypt .mof DSC files
New-DSCCertificate -ComputerName $ComputerName -DomainCredential $DomainCredential

#Compiles .mof files, installs UCMA and starts DSC
Install-Prerequisite -baseDir $baseDir -ComputerName $ComputerName -DomainCredential $DomainCredential -CertPW $Password

#Gets the Exchange Certificate and exports it
Export-ExchCert -SourceComputer $SourceComputer -fqdn $fqdn -Password $Password -DomainCredential $DomainCredential

#Configures all Exchange settings
Configure-Exchange -ComputerName $ComputerName -SourceComputer $SourceComputer -newfqdn $newfqdn -Password $Password -DomainCredential $DomainCredential -hostname $www

Log-Finish -LogPath $xLogFile -NoExit $true