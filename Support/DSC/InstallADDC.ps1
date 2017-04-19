Configuration InstallADDC {

    Param (
        [Parameter(Mandatory)]
        [String]$DNS,
        [Parameter(Mandatory)]
        [String]$ComputerName,
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $DomainCredentials,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $SafeModeCredentials
    )


    <# TODO:
        * Enable remoting from push server using e.g. template.
        * Config must work on all nodes.
        * Reboots must be run.
        * Fix postdeployment configuration.
    #>

    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xPendingReboot, xComputerManagement

    Node "192.168.59.113" {

        LocalConfigurationManager {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        xDNSServerAddress DnsServerAddress {
            Address        = $DNS
            InterfaceAlias = "Ethernet"
            AddressFamily  = 'IPv4'
        }

        xComputer JoinDomain {
            Name = $ComputerName
            DomainName = $DomainName 
            Credential = $DomainCredentials  # Credential to join to domain
            DependsOn = '[xDNSServerAddress]DnsServerAddress'
        }

        WindowsFeature DNS {
            Ensure = "Present"
            Name = "DNS"
	        DependsOn = '[xComputer]JoinDomain'
        }

        WindowsFeature ADDSInstall {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            IncludeAllSubFeature = $true
            DependsOn = '[WindowsFeature]DNS'
        }

        WindowsFeature RSATTools { 
            DependsOn= '[WindowsFeature]ADDSInstall'
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
        }  

        xADDomainController DomainController {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCredentials
            SafemodeAdministratorPassword = $SafeModeCredentials
            DatabasePath = "C:\NTDS"
            LogPath = "C:\NTDS"
            SysvolPath = "C:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        Script PostDeployment {

            GetScript = {
                Return @{            
                    Result = [string]$(get-windowsfeature -name "ad-domain-services")            
                }  
            }

            SetScript = {

                <# TODO: 
                $FSMO = netdom query fsmo
                $Master = $FSMO[0] | % { $_.Split(" ")} | select -last 1 | % {$_.Split(".")}
                $Root = [ADSI]"LDAP://RootDSE"
                $DomainDN = $Root.Get("rootDomainNamingContext")

                repadmin /replicate $env:COMPUTERNAME $Master[0] $DomainDN /full #>

                new-item -path C:\ -itemtype file -name somefile

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