
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Stop
$ErrorActionPreference = "Stop"

#Dot Source required Function Libraries
. "C:\service-migration-azure\Libraries\Log-Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "0.1"

#Log File Info
$sLogPath = "C:\Logs\service-migration-azure"
$sLogName = "MSSQL-Migration.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Start-MSSQLMigrationProcess{
  Param(
    $InstanceName
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL migration process.."
    Import-Module -Name Sqlps
  }
  
  Process{
    Try{
      $ConfigPath = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Filter 'ConfigurationFile.ini' -Recurse

      Backup-SqlDatabase -ServerInstance "$env:COMPUTERNAME\$InstanceName"
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
      Break
    }
  }
  
  End{
    If($succeeded){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
Start-MSSQLMigrationProcess
Log-Finish -LogPath $sLogFile -NoExit $True