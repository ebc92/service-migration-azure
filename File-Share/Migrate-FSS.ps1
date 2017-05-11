Param(
  [pscredential]$DomainCredential
)

$ComputerName = $SMAConfig.FSS.ComputerName
$SourceComputer = $SMAConfig.FSS.SourceComputer
$DestPath = $SMAConfig.FSS.DestPath
$SourcePath = $SMAConfig.FSS.SourcePath

Move-File -SourceComputer $SourceComputer -ComputerName $ComputerName -DomainCredential $DomainCredential -SourcePath $SourcePath -DestPath $DestPath