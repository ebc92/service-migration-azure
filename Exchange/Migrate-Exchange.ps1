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




Get-Prerequisite -fileShare $fileshare -ComputerName -DomainCredential 

#Mount fileshare on source VM
Mount-FileShare -DomainCredential -ComputerName -baseDir

#Mount fileshare on target VM
Mount-FileShare -DomainCredential -ComputerName -baseDir

Mount-Exchange -FileShare -ComputerName -baseDir -DomainCredential

New-DSCCertificate -ComputerName -DomainCredential

Install-Prerequisite -baseDir -ComputerName -DomainCredential

Export-ExchCert -SourceComputer -fqdn -Password -DomainCredential

Configure-Exchange -ComputerName -SourceComputer -newfqdn -Password -DomainCredential -hostname