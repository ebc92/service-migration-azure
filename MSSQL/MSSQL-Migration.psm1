Function Start-MSSQLInstallConfig{
  Param(
    [string]$PackagePath,
    [PSCredential]$Credential
  )
  
  Process {
    Try{

      Log-Write -LogPath $sLogFile -LineValue "Building the MSSQL deployment configuration.."

      Import-Module -Name Sqlps

      Log-Write -LogPath $sLogFile -LineValue "Looking for existing SQL ConfigurationFile."
      $ConfigPath = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Filter 'ConfigurationFile.ini' -Recurse -ErrorAction Stop

      $Options = (Get-IniContent -filePath $ConfigPath.FullName).OPTIONS
      $Options.Set_Item('QUIET','"TRUE"')
      $Options.Set_Item('SUPPRESSPRIVACYSTATEMENTNOTICE','"TRUE"')
      $Options.Set_Item('IACCEPTSQLSERVERLICENSETERMS','"TRUE"')
      $Options.Remove("UIMODE")

      $ini= @{"OPTIONS" = $Options}
      $OriginPath = Split-Path -Path $ConfigPath.FullName
      Out-IniFile -InputObject $ini -Filepath "$OriginPath\DeploymentConfig.ini"
      Log-Write -LogPath $sLogFile -LineValue "Unattended config was written to $OriginPath\DeploymentConfig.ini"

      Try {
        New-PSDrive -PSProvider FileSystem -Name "pkg" -Root $PackagePath -Credential $Credential -ErrorAction Stop 
      } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "Could not mount the specified file share."
      }

      Copy-Item -Path "$OriginPath\DeploymentConfig.ini" -Destination 'pkg:\' -ErrorAction Stop
 
    }  Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
      Log-Write -Logpath $sLogFile -LineValue "No existing configuration file was found, please provide it and rerun."
    }
  }
  
    End{
        If(Test-Path "$PackagePath\DeploymentConfig.ini"){
        Log-Write -LogPath $sLogFile -LineValue "Unattended configurationfile was successfully transferred to $PackagePath."
        }
    }
}

Function Start-MSSQLMigration {
  Param(
    [String]$Source,
    [String]$Destination,
    [String]$InstanceName,
    [PSCredential]$Credential,
    [PSCredential]$SqlCredential,
    [String]$Share
  )

    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL migration process.."
    Try {
        Log-Write -LogPath $sLogFile -LineValue "Installing dbatools.."
        $DbaTools = Resolve-Path (Join-Path -Path "C:\service-migration-azure-develop\" -ChildPath "Libraries\Install-DBATools.ps1")
        & $DbaTools

    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "dbatools installation failed.."
    }

    Try{
        $ConnectionTest = Test-SqlConnection -SqlServer "$Destination\$InstanceName" -SqlCredential $SqlCredential -ErrorAction Stop
        If (!$ConnectionTest.ConnectSuccess){
            Log-Write -Logpath $sLogFile -LineValue "Could not establish connection to the destination server."
        } else {
            Start-SqlMigration -Source localhost\$InstanceName -Destination $Destination\$InstanceName -SourceSqlCredential $SqlCredential -DestinationSqlCredential $SqlCredential -NetworkShare $Share -BackupRestore     
        }
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }

 }
