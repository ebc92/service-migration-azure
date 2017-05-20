<# The module originally contained a series of function used to handle
SQL migration. However, following implementation of DSC and third 
party solutions, it has become largely deprecated. #>

<# This function is used to generate a SQL Server configuration file using the
pre-existing configration file of the source SQL Server. #>
Function Start-MSSQLInstallConfig{
  Param(
    [string]$PackagePath,
    [PSCredential]$Credential
  )

    Try{
      Log-Write -LogPath $sLogFile -LineValue "Building the MSSQL deployment configuration.."

      # Import the SQL Server PowerShell module.
      Import-Module -Name Sqlps

      # Find the pre-existing SQL Serve Configuration File.
      Log-Write -LogPath $sLogFile -LineValue "Looking for existing SQL ConfigurationFile."
      $ConfigPath = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Filter 'ConfigurationFile.ini' -Recurse -ErrorAction Stop

      # Modify the configuration file to enable a scripted, unattended installation.
      $Options = (Get-IniContent -filePath $ConfigPath.FullName).OPTIONS
      $Options.Set_Item('QUIET','"TRUE"')
      $Options.Set_Item('SUPPRESSPRIVACYSTATEMENTNOTICE','"TRUE"')
      $Options.Set_Item('IACCEPTSQLSERVERLICENSETERMS','"TRUE"')
      $Options.Remove("UIMODE")

      # Export the unattended configuration file to a .ini file.
      $ini= @{"OPTIONS" = $Options}
      $OriginPath = Split-Path -Path $ConfigPath.FullName
      Out-IniFile -InputObject $ini -Filepath "$OriginPath\DeploymentConfig.ini"
      Log-Write -LogPath $sLogFile -LineValue "Unattended config was written to $OriginPath\DeploymentConfig.ini"

      # Mount the specified domain file share as a PSDrive.
      Try {
        New-PSDrive -PSProvider FileSystem -Name "pkg" -Root $PackagePath -Credential $Credential -ErrorAction Stop 
      } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "Could not mount the specified file share."
      }

      # Copy unattended configuration file to the file share.
      Copy-Item -Path "$OriginPath\DeploymentConfig.ini" -Destination 'pkg:\' -ErrorAction Stop
 
    } Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
      Log-Write -Logpath $sLogFile -LineValue "No existing configuration file was found, please provide it and rerun."
    }

    # Run a test to verify that the unattended configuration file was successfully created and moved to the file share.
    If(Test-Path "$PackagePath\DeploymentConfig.ini"){
        Log-Write -LogPath $sLogFile -LineValue "Unattended configurationfile was successfully transferred to $PackagePath."
    }
}

<# This function is extracted to a stand-alone script, 
see /service-migration-azure/MSSQL/Start-MSSQLMigration.ps1 #>
Function Start-MSSQLMigration {
  Param(
    [String]$Source,
    [String]$Destination,
    [String]$InstanceName,
    [PSCredential]$Credential,
    [PSCredential]$SqlCredential,
    [String]$Share
  )
    Try{
        Log-Write -Logpath $sLogFile -LineValue "Starting connectiontest on $($Destination)\$($InstanceName) using the share $($Share)."
        $ConnectionTest = Test-SqlConnection -SqlServer "$($Destination)\$($InstanceName),1433" -SqlCredential $SqlCredential
        If (!$ConnectionTest.ConnectSuccess){
            Log-Write -Logpath $sLogFile -LineValue "Could not establish connection to the destination server."
        } else {
            Log-Write -Logpath $sLogFile -LineValue "Connectiontest was successful!"
            Start-SqlMigration -Source "$($Source)\$($InstanceName),1433" -Destination "$($Destination)\$($InstanceName),1433" -SourceSqlCredential $SqlCredential -DestinationSqlCredential $SqlCredential -NetworkShare $Share -BackupRestore     
        }
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
 }
