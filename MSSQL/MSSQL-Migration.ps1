Param($ComputerName, $Source, $PackagePath, $InstanceName, $Credential)

$ComputerName = "158.38.43.114"
$Source = "158.38.43.113"
$PackagePath = "\\158.38.43.116\share\MSSQL"
$InstanceName = "AMSTELSQL"
$Credential = (Get-Credential)
$SqlCredential = (Get-Credential)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Stop
$ErrorActionPreference = "Stop"

#Dot Source required Function Libraries
. "C:\service-migration-azure\Libraries\Log-Functions.ps1"

#----------------------------------------------------------[Log File Info]----------------------------------------------------------

$sScriptVersion = "0.1"
$sLogPath = "C:\Logs\service-migration-azure"
$sLogName = "MSSQL-Migration.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Import-Module $PSScriptRoot\MSSQL-Migration.psm1 -Force

$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\Support\Install-SMModule.ps1"

Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#Install modules on remote computer.
Invoke-Command -ComputerName $ComputerName -FilePath $ModulePath -Credential $Credential 

Start-MSSQLInstallConfig -PackagePath $PackagePath -Credential $Credential

Start-MSSQLDeployment -ComputerName $ComputerName -PackagePath $PackagePath -InstanceName $InstanceName -Credential $Credential

Log-Write -LogPath $sLogFile -LineValue "SQL Server 2016 was successfully deployed on $ComputerName."

Log-Write -LogPath $sLogFile -LineValue "Starting SQL Instance migration from $Source\$InstanceName to $ComputerName\$InstanceName."
Start-MSSQLMigration -Source $Source -Destination $ComputerName -InstanceName $InstanceName -Share $PackagePath -SqlCredential $SqlCredential -Credentials $Credential
Log-Finish -LogPath $sLogFile -NoExit $True