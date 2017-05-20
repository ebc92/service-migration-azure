<# Original DSC configuration by
    Colin Alm / www.colinalmscorner.com
    http://www.colinsalmcorner.com/post/install-and-configure-sql-server-using-powershell-dsc #>

Configuration DesiredStateSQL {
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackagePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$DomainCredential
    )

    # Custom DSC resources used for for both deployment and configuration. 
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xNetworking, xComputerManagement
 
    # The node is defined to ensure that the DSC only runs a host that has the SQL Server role.
    Node $AllNodes.where{ $_.Role.Contains("SqlServer") }.NodeName {
        
        <# The LCM behavoir is specified. It wil reboot when necessary, but configuration
        will resume on boot. The LCM will only apply the configuration, it will not
        continue to monitor the host state after the deployment. #>
        LocalConfigurationManager {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
 
        #Install .Net Framework versions 3.5 and 4.5
        WindowsFeature NetFramework35Core {
            Name = "NET-Framework-Core"
            Ensure = "Present"
            Source = Join-Path -Path $PackagePath -ChildPath "sxs"
        }
 
        WindowsFeature NetFramework45Core {
            Name = "NET-Framework-45-Core"
            Ensure = "Present"
            Source = $WinSources
        }
 
        # copy the sqlserver iso
        File SQLServerIso {
            Credential = $DomainCredential
            SourcePath = "$PackagePath\en_sql_server_2016_enterprise_with_service_pack_1_x64_dvd_9542382.iso"
            DestinationPath = "c:\temp\SQLServer.iso"
            Type = "File"
            Ensure = "Present"
        }
 
        # copy the ini file to the temp folder
        File SQLServerIniFile {
            Credential = $DomainCredential
            SourcePath = "$PackagePath\DeploymentConfig.ini"
            DestinationPath = "c:\temp"
            Force = $True
            Type = "File"
            Ensure = "Present"
            DependsOn = "[File]SQLServerIso"
        }
 
        # Install SqlServer using ini file
        Script InstallSQLServer {

            DependsOn = "[File]SQLServerIniFile"

            <# Executed when Get-DscConfiguration cmdlet is run. 
            It is used to discover current host state. #>
            GetScript = {

                $sqlInstances = gwmi win32_service -computerName localhost | ? { $_.Name -match "mssql*" -and $_.PathName -match "sqlservr.exe" } | % { $_.Caption }
                $res = $sqlInstances -ne $null -and $sqlInstances -gt 0
                $vals = @{
                    Installed = $res;
                    InstanceCount = $sqlInstances.count
                }
                $vals
            }

            <# Executed when Start-DscConfiguration cmdlet is run. 
            Our migration solution only implements this script block. #>
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

            <# Executed when Start- or Test-DscConfiguration cmdlet is run.
            If it returns false, it wil use SetScript block to set the host
            to the desired state. This configuration will never be used on
            a host with the desired state so it will always return false. #>
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

        <# To prepare for the migration, the new SQL Server must accept remote requests 
        on TCP port 1433. To support the DBATools migration, it must also enable the 
        Named Pipes protocol. This is achieved by using WMI Objects to manipulate the 
        instance configuration. After configuration all SQL services must be restarted. #>
        Script PostDeploymentConfiguration {
            DependsOn = "[Script]InstallSQLServer"

            <# Executed when Get-DscConfiguration cmdlet is run. 
            It is used to discover current host state. #>
            GetScript = { Get-Service *SQL* }

            <# Executed when Start-DscConfiguration cmdlet is run. 
            Our migration solution only implements this script block. #>
            SetScript = {

                # Import the SQL PowerShell Module.
                Try {
                    Import-Module -Name Sqlps -ErrorAction Stop
                } Catch {
                    # If it is not found, the SQL Tools PowerShell folder must be added to the environment PSModulePath.
                    $env:PSModulePath = $env:PSModulePath + ";C|<:\Program Files (x86)\Microsoft SQL Server\130\Tools\PowerShell\Modules"
                    Import-Module -Name Sqlps
                }
                

                # TODO: Get instancename from .ini-file.
                $InstanceName = "AMSTELSQL"

                # T-SQL Query to enable remote access to the instance."
                Invoke-Sqlcmd -ServerInstance localhost\$InstanceName -Query "EXEC sp_configure 'remote access', 1; RECONFIGURE;"

                # Import SQL Server Management Objects.
                [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
                [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

                # Create a new SQL Server Management Object.
                $Mc = New-Object ('Microsoft.SQLServer.Management.SMO.WMI.ManagedComputer')"localhost"

                Write-Output "Enabling Named Pipes for the SQL Service Instance"
                # Enable the named pipes protocol for the default instance.
                $uri = "ManagedComputer[@Name='localhost']/ ServerInstance[@Name='$InstanceName']/ServerProtocol[@Name='Np']"
                $Np = $Mc.GetSmoObject($uri)
                $Np.IsEnabled = $true
                $Np.Alter()
                $Np

                # Configure static TCP port.
                $uri = "ManagedComputer[@Name='localhost']/ ServerInstance[@Name='$InstanceName']/ ServerProtocol[@Name='Tcp']"
                $Tcp = $Mc.GetSmoObject($uri)
                $Tcp.IPAddresses | % { 
                    if($_.Name -eq "IPAll"){
                        $_.IpAddressProperties[1].Value = "1433"
                        $Tcp.Alter()
                        $Tcp
                    }
                }

                # Restart all SQL Services.
                Get-Service *SQL* | Restart-Service -Force 

            }

            <# Executed when Start- or Test-DscConfiguration cmdlet is run.
            If it returns false, it wil use SetScript block to set the host
            to the desired state. This configuration will never be used on
            a host with the desired state so it will always return false. #>
            TestScript = { return $false }  
        }

        # Finally open the firewall for incoming remote SQL Server requests.
        xFirewall AllowSQL {
            DependsOn = "[Script]PostDeploymentConfiguration"
            Name                  = 'SQLServer'
            DisplayName           = 'SQL Server 1433-1434'
            Ensure                = 'Present'
            Enabled               = 'True'
            Profile               = ('Domain', 'Private')
            Direction             = 'Inbound'
            LocalPort             = ('1433', '1434')
            Protocol              = 'TCP'
            Description           = 'Firewall Rule for SQL Server'
        }
    }

}