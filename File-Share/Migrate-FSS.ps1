Param(
  [pscredential]$DomainCredential
)

#Sets data to all parameters from configuration.ini
$ComputerName = $SMAConfig.FSS.ComputerName
$SourceComputer = $SMAConfig.FSS.SourceComputer
$SourcePath = $SMAConfig.FSS.SourcePath
$DestPath = $SMAConfig.FSS.DestPath

#Runs the Move-File module
Move-File -DomainCredential $DomainCredential -ComputerName $ComputerName -SourceComputer $SourceComputer -SourcePath $SourcePath -DestPath $DestPath