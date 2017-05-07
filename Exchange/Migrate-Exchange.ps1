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
Install-Prerequisite -baseDir $baseDir -ComputerName $ComputerName -DomainCredential $DomainCredential

#Gets the Exchange Certificate and exports it
Export-ExchCert -SourceComputer $SourceComputer -fqdn $fqdn -Password $Password -DomainCredential $DomainCredential

#Configures all Exchange settings
Configure-Exchange -ComputerName $ComputerName -SourceComputer $SourceComputer -newfqdn $newfqdn -Password $Password -DomainCredential $DomainCredential -hostname $www