Configuration DesiredStateSQL {
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackagePath,
 
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $WinSources,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$Credential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
 
    Node $AllNodes.where{ $_.Role.Contains("SqlServer") }.NodeName {
        Log ParamLog {
            Message = "Running SQLInstall. PackagePath = $PackagePath"
        }
 
        WindowsFeature NetFramework35Core {
            Name = "NET-Framework-Core"
            Ensure = "Present"
            Source = $WinSources
        }
 
        WindowsFeature NetFramework45Core {
            Name = "NET-Framework-45-Core"
            Ensure = "Present"
            Source = $WinSources
        }
 
        # copy the sqlserver iso
        File SQLServerIso {
            Credential = $Credential
            SourcePath = "$PackagePath\en_sql_server_2016_enterprise_with_service_pack_1_x64_dvd_9542382.iso"
            DestinationPath = "c:\temp\SQLServer.iso"
            Type = "File"
            Ensure = "Present"
        }
 
        # copy the ini file to the temp folder
        File SQLServerIniFile {
            Credential = $Credential
            SourcePath = "$PackagePath\DeploymentConfig.ini"
            DestinationPath = "c:\temp"
            Force = $True
            Type = "File"
            Ensure = "Present"
            DependsOn = "[File]SQLServerIso"
        }
 
        #
        # Install SqlServer using ini file
        #
        Script InstallSQLServer {

            GetScript = {

                $sqlInstances = gwmi win32_service -computerName localhost | ? { $_.Name -match "mssql*" -and $_.PathName -match "sqlservr.exe" } | % { $_.Caption }
                $res = $sqlInstances -ne $null -and $sqlInstances -gt 0
                $vals = @{
                    Installed = $res;
                    InstanceCount = $sqlInstances.count
                }
                $vals
            }
            SetScript = {

                # mount the iso
                $setupDriveLetter = (Mount-DiskImage -ImagePath c:\temp\SQLServer.iso -PassThru | Get-Volume).DriveLetter + ":"
                if ($setupDriveLetter -eq $null) {
                    throw "Could not mount SQL install iso"
                }
                Write-Verbose "Drive letter for iso is: $setupDriveLetter"
                 
                # run the installer using the ini file
                $cmd = "$setupDriveLetter\Setup.exe /ConfigurationFile=c:\temp\DeploymentConfig.ini /SQLSVCPASSWORD=P2ssw0rd /AGTSVCPASSWORD=P2ssw0rd /SAPWD=P2ssw0rd"
                Write-Verbose "Running SQL Install - check %programfiles%\Microsoft SQL Server\130\Setup Bootstrap\Log\ for logs..."
                Invoke-Expression $cmd | Write-Verbose
            }

            TestScript = {

                $sqlInstances = gwmi win32_service -computerName localhost | ? { $_.Name -match "mssql*" -and $_.PathName -match "sqlservr.exe" } | % { $_.Caption }
                $res = $sqlInstances -ne $null -and $sqlInstances -gt 0
                if ($res) {
                    Write-Verbose "SQL Server is already installed"
                } else {
                    Write-Verbose "SQL Server is not installed"
                }
                $res
            }
        }

        Script PostDeploymentConfiguration {

            GetScript = {
                <# TODO: 
                Get current state of PostDeploymentConfiguration #>
            }

            SetScript = {
                Import-Module -Name Sqlps

                <# TODO: 
                Get instancename from .ini-file #>
                $InstanceName = "AMSTELSQL"

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

                # Configuring static TCP port
                $uri = "ManagedComputer[@Name='localhost']/ ServerInstance[@Name='$InstanceName']/ ServerProtocol[@Name='Tcp']"
                $Tcp = $Mc.GetSmoObject($uri)
                $Tcp.IPAddresses | % { 
                    if($_.Name -eq "IPAll"){
                        $_.IpAddressProperties[4].Value = "1433"
                        $Tcp.Alter()
                        $Tcp
                    }
                }

                Restart-Service -name "SQLAgent`$$InstanceName"    

            }

            TestScript = {
                <# TODO:
                Check desired state against current state.
                For now, run regardless. #>
                return $false
            }
            
        }
    }

}