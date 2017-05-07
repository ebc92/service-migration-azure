
# use this file to define global variables on module scope
# or perform other initialization procedures.
# this file will not be touched when new functions are exported to
# this module.

$global:baseDir = '\\testsrv-share\TempExchange'
$global:fileShare = (Join-Path -Path $baseDir -ChildPath executables)
$global:logDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString() 
$global:sLogPath = "$baseDir\log\"
$global:sLogName = "Migrate-Exchange-$logDate.log"
$global:sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
