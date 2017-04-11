Configuration ADDSInstall {

    Param (
        [Parameter(Mandatory)]
        [String]$DNS,
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $DomainCredentials,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $SafeModeCredentials
    )

    Install-Module -Name xActiveDirectory, xNetworking, xPendingReboot
    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xPendingReboot
 
    Node localhost {

        LocalConfigurationManager {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        xDnsServerAddress DnsServerAddress {
            Address        = $DNS
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
        }

        xDSCDomainjoin JoinDomain {
            Domain = $DomainName 
            Credential = $DomainCredentials  # Credential to join to domain
        }
 
        WindowsFeature DNS {
            Ensure = "Present"
            Name = "DNS"
        }
        
        WindowsFeature ADDSInstall {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        WindowsFeature RSAT {
            Ensure = "Present"
            Name = "RSAT"
        }

        xADDomain DomainController {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCredentials
            SafemodeAdministratorPassword = $SafeModeAdminCreds
            DatabasePath = "C:\NTDS"
            LogPath = "C:\NTDS"
            SysvolPath = "C:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        xWaitForADDomain DscForestWait {
            DomainName = $DomainName
            DomainUserCredential = $DomainCredentials
            RetryCount = 20
            RetryIntervalSec = 30
            DependsOn = "[xADDomain]DomainController"
        }

        xPendingReboot Reboot1 { 
            Name = "RebootServer"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

    }


}