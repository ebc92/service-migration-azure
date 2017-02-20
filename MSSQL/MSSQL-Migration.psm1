
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Stop
$ErrorActionPreference = "Stop"

#Dot Source required Function Libraries
. "C:\service-migration-azure\Libraries\Log-Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "0.1"

#Log File Info
$sLogPath = "C:\service-migration-azure"
$sLogName = "MSSQL-Migration.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Start-MSSQLMigrationProcess{
  Param()

  $succeeded
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL migration process.."
  }
  
  Process{
    Try{
      
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
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