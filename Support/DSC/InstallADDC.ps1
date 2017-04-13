Configuration InstallADDC {

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

    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xPendingReboot, xDSCDomainjoin

    Node "192.168.58.114" {
        LocalConfigurationManager {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        xDNSServerAddress DnsServerAddress {
            Address        = $DNS
            InterfaceAlias = 'Ethernet0'
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
            SafemodeAdministratorPassword = $SafeModeCredentials
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

        Script createfile {

            GetScript = {
                <# TODO: 
                Get current state #>
            }

            SetScript = {
                new-item -name somefile -itemtype file
            }

            TestScript = {
                <# TODO:
                Check desired state against current state.
                For now, run regardless. #>
                $res = $false
            }
        }
        }
    }