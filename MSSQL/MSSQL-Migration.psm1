Function Start-MSSQLInstallConfig{
  Param(
    [string]$PackagePath,
    [PSCredential]$Credential
  )
  
  Begin{
    Write-Output $sLogFile
    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL deployment process.."
    if (Get-Module -ListAvailable -Name Sqlps){
        Log-write -LogPath $sLogFile -LineValue "SQLPS module is already imported, doing nothing."
    } else {
        Log-write -LogPath $sLogFile -LineValue "Importing SQLPS module.."
        Import-Module -Name Sqlps
    }
  }
  
  Process{
    Try{
      Log-Write -LogPath $sLogFile -LineValue "Looking for existing SQL ConfigurationFile."
      $ConfigPath = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Filter 'ConfigurationFile.ini' -Recurse

      $iniUpdate = Join-Path -Path $PSScriptRoot -ChildPath '\..\Support\Update-IniFile.ps1'
      . $iniUpdate

      $Options = (Get-IniContent -filePath $ConfigPath.FullName).OPTIONS
      $Options.Set_Item('QUIET','"TRUE"')
      $Options.Set_Item('SUPPRESSPRIVACYSTATEMENTNOTICE','"TRUE"')
      $Options.Set_Item('IACCEPTSQLSERVERLICENSETERMS','"TRUE"')
      $Options.Remove("UIMODE")

      $ini= @{"OPTIONS" = $Options}
      $OriginPath = Split-Path -Path $ConfigPath.FullName
      Out-IniFile -InputObject $ini -Filepath "$OriginPath\DeploymentConfig.ini"
      Log-Write -LogPath $sLogFile -LineValue "Unattended config was written to $OriginPath\DeploymentConfig.ini"

      New-PSDrive -PSProvider FileSystem -Name "pkg" -Root $PackagePath -Credential $Credential -ErrorAction Stop
      Copy-Item -Path "$OriginPath\DeploymentConfig.ini" -Destination 'pkg:\'
 
      }  Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
      Log-Write -Logpath $sLogFile -LineValue "No existing configuration file was found, please provide it and rerun."
      Break
    }
  }
  
    End{
        If(Test-Path "$PackagePath\DeploymentConfig.ini"){
        Log-Write -LogPath $sLogFile -LineValue "Unattended configurationfile was successfully transferred to $PackagePath."
        }
    }
}

Function Start-MSSQLDeployment{
    Param(
    [string]$PackagePath,
    [string]$InstanceName,
    [string]$ComputerName,
    [PSCredential]$Credential)

    Begin {}
    Process {
        Try {
            Log-Write -LogPath $sLogFile -LineValue "Sourcing DSC script for SQL install."
            $DesiredState = Join-Path -Path $PSScriptRoot -ChildPath '\..\Support\DSC\InstallSQL.ps1'
            . $DesiredState

            Log-Write -LogPath $sLogFile -LineValue "Generating MOF-file from DSC script."

            $configData = @{
                AllNodes = @(
                    @{
                        NodeName = "*"
                        PSDscAllowPlainTextPassword = $true
                    }, @{
                        NodeName = $ComputerName
                        Role = "SqlServer"
                    }
                );
            }

            SQLInstall -ConfigurationData $configData -PackagePath $PackagePath -WinSources "$PackagePath\sxs" -Credential $Credential

            Log-Write -LogPath $sLogFile -LineValue "Starting DSC configuration."
            Start-DscConfiguration -ComputerName $ComputerName -Path .\SQLInstall -Verbose -Wait -Force -Credential $Credential -ErrorAction Stop
            Log-Write -LogPath $sLogFile -LineValue "DSC configuration was succcessfully executed"

        } Catch {
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
            Break
        }
    }
    End {
                
        $EnableRemoting = {
            Param(
                $InstanceName
            )

            Invoke-Sqlcmd -ServerInstance localhost\$InstanceName -Query "EXEC sp_configure 'remote access', 1;"
            Invoke-Sqlcmd -ServerInstance localhost\$InstanceName -Query "RECONFIGURE;"

            [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
            [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

            $Mc = New-Object ('Microsoft.SQLServer.Management.SMO.WMI.ManagedComputer')"localhost"

            Write-Output "Enabling Named Pipes for the SQL Service Instance"
            # Enable the named pipes protocol for the default instance.
            $uri = "ManagedComputer[@Name='localhost']/ ServerInstance[@Name='$InstanceName']/ServerProtocol[@Name='Np']"
            $Np = $Mc.GetSmoObject($uri)
            $Np.IsEnabled = $true
            $Np.Alter()
            $Np

            Restart-Service -name "SQLAgent`$$InstanceName"                   
        }
        
        Try {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock $EnableRemoting -Credential $Credential
        } Catch {
            Log-Write -LogPath $sLogFile -LineValue "Failed to enable remoting on the destination server."
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
            Break
        }
    }
}

Function Start-MSSQLMigration{
  Param(
    [String]$Source,
    [String]$Destination,
    [String]$InstanceName,
    [PSCredential]$Credential,
    [PSCredential]$SqlCredential,
    [String]$Share
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL migration process.."
    Try {
        Log-Write -LogPath $sLogFile -LineValue "Installing dbatools.."
        . $PSScriptRoot\..\Libraries\Install-DBATools.ps1
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "dbatools installation failed.."
    }
  }
  
  Process{
   <# Try{
        $ConnectionTest = Test-SqlConnection -SqlServer $Destination\$InstanceName -SqlCredential $SqlCredential
        If (!ConnectionTest.ConnectSuccess){
        Log-Write -Logpath $sLogFile -LineValue "Could not establish connection to the destination server."
        Break
        }
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "Could not run the connection test."
        Break
    } #>
    
    Try {
        Start-SqlMigration -Source $Source\$InstanceName -Destination $Destination\$InstanceName -SourceSqlCredential $Credential -DestinationSqlCredential $SqlCredential -NetworkShare $Share -BackupRestore
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "Could not run the migration."
        Break
    }
  }
  
    End{
    
    }
}