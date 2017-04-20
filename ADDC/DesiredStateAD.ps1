Configuration DesiredStateAD {

    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$VMName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$DNS,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ComputerName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $DomainCredentials,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()] 
        [PSCredential]
        $SafeModeCredentials
    )

    <# TODO:
        * Enable remoting from push server using e.g. template.
        * Config must work on all nodes.
        * Fix postdeployment configuration.
    #>

    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xComputerManagement

    Node $ComputerName {

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
            Name = $VMName
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

        Script ReplicateDomain {

            DependsOn = "[xADDomainController]DomainController"

            GetScript = { Return Get-ADDomain }  

            SetScript = {

                $FSMO = netdom query fsmo
                $Master = $FSMO[0] | % { $_.Split(" ")} | select -last 1 | % {$_.Split(".")}
                $Root = [ADSI]"LDAP://RootDSE"
                $DomainDN = $Root.Get("rootDomainNamingContext")

                repadmin /replicate $env:COMPUTERNAME $Master[0] $DomainDN /full

                new-item -path C:\ -itemtype file -name somefile

            }

            TestScript = { return $false }
        }
        
        }
    }