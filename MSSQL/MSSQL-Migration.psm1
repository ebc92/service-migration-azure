
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
  Param()
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL migration process.."
    Import-Module -Name Sqlps
  }
  
  Process{
    Try{
      $ConfigPath = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Filter 'ConfigurationFile.ini' -Recurse
      New-PSDrive -PSProvider FileSystem -Name "share" -Root \\158.38.43.115\C$\Share -Credential $Credential -ErrorAction Stop
      Copy-Item -Path $ConfigPath.FullName -Destination 'share:\'
      
      <# Migration by backup
      cd SQLServer:\SQL\$env:COMPUTERNAME  
      $instances = Get-childitem   
        # loop through each instances and backup up all the  databases -filter out tempdb and model databases  
  
        foreach ($instance in $instances)  {  
            $path = "sqlserver:\sql\$($instance.name)\databases"  
            $alldatabases = get-childitem -Force -path $path |Where-object {$_.name -ne "tempdb" -and $_.name -ne "model"}   
  
            $alldatabases | Backup-SqlDatabase -BackupContainer "C:\Program Files\Microsoft SQL Server\MSSQL13.AMSTELSQL\MSSQL\Backup" -Compression On 
        } #>  
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

Function Start-MSSQLDeployment{
    Param(
    [string]$Password, 
    [string]$ConfigPath)
    #Mount-DiskImage -ImagePath \\158.38.43.115\share\en_sql_server_2016_enterprise_x64_dvd_8701793.iso
    $ConfigFile = 'C:\Users\Administrator.AMSTEL\Desktop\ConfigurationFile.ini'
    $Drive = Get-WMIObject Win32_Volume -Filter "Label='SQL2016_x64_ENU'"
    $InstallConfig = @("/ConfigurationFile=$ConfigPath", "/SAPWD=$Password")
    $InstallSQL = "$($Drive.Caption)setup.exe" 
    & $InstallSQL $InstallConfig

}
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
Start-MSSQLMigrationProcess -InstanceName "AMSTELSQL"
Log-Finish -LogPath $sLogFile -NoExit $True