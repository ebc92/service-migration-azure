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

    Node "192.168.59.112" {

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

        xDSCDomainjoin JoinDomain {
            Domain = $DomainName 
            Credential = $DomainCredentials  # Credential to join to domain
        }

        xPendingReboot Reboot1 { 
            Name = "DomainjoinReboot"
            DependsOn = "[xDSCDomainjoin]JoinDomain"
        }
 
        WindowsFeature DNS {
            Ensure = "Present"
            Name = "DNS"
        }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
        WindowsFeature ADDSInstall {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            IncludeAllSubFeature = $true
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

        xWaitForADDomain DscForestWait {
            DomainName = $DomainName
            DomainUserCredential = $DomainCredentials
            RetryCount = 20
            RetryIntervalSec = 30
            DependsOn = "[xADDomainController]DomainController"
        }

        xPendingReboot Reboot2 { 
            Name = "DomainReboot"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        Script PostDeployment {

            GetScript = {
                <# TODO: 
                Get current state #>
            }

            SetScript = {
                $FSMO = netdom query fsmo
                $Master = $FSMO[0] | % { $_.Split(" ")} | select -last 1 | % {$_.Split(".")}
                $Root = [ADSI]"LDAP://RootDSE"
                $DomainDN = $Root.Get("rootDomainNamingContext")

                repadmin /replicate $env:COMPUTERNAME $Master[0] $DomainDN /full
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