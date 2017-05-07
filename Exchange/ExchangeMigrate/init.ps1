
# use this file to define global variables on module scope
# or perform other initialization procedures.
# this file will not be touched when new functions are exported to
# this module.

$baseDir = $SMAConfig.Exchange.basedir

$LogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString() 
$sLogPath = "$baseDir\log\"
$sLogName = "Migrate-Exchange-$logDate.log"
$global:xLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName