
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
    [string]$PackagePath,
    [PSCredential]$Credential
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Starting the MSSQL migration process.."
    Import-Module -Name Sqlps
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
    [string]$ComputerName,
    [string]$PackagePath,
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
        #TODO: Enable remoting sp_configure remote access 1
        
        $EnableNP = {
            Param(
                $Instance
            )

            $Instance = AMSTELSQL
            [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
            [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

            $Mc = New-Object ('Microsoft.SQLServer.Management.SMO.WMI.ManagedComputer')"localhost"

            Write-Output "Enabling Named Pipes for the SQL Service Instance"
            # Enable the named pipes protocol for the default instance.
            $uri = "ManagedComputer[@Name='localhost']/ ServerInstance[@Name='$Instance']/ServerProtocol[@Name='Np']"
            $Np = $Mc.GetSmoObject($uri)
            $Np.IsEnabled = $true
            $Np.Alter()
            $Np

            Restart-Service -name "SQLAgent`$$Instance"                   
        }
        
        Try {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock $EnableNP -ArgumentList $Instance -Credential $Credential
        } Catch {
            Log-Write -LogPath $sLogFile -LineValue "Failed to enable named pipes protocol."
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
            Break
        }
    }
}


#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Start-MSSQLMigrationProcess -InstanceName "AMSTELSQL"
Log-Finish -LogPath $sLogFile -NoExit $True