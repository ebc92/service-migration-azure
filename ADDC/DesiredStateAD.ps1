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
        [String]$InterfaceAlias,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $DomainCredentials,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()] 
        [PSCredential]
        $SafeModeCredentials
    )

    # Custom DSC resources used for for both deployment and configuration.
    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xComputerManagement

    # The node is defined to ensure that the DSC only runs on the intended host.
    Node $ComputerName {
        
        <# The LCM behavoir is specified. It wil reboot when necessary, but configuration
        will resume on boot. The LCM will only apply the configuration, it will not
        continue to monitor the host state after the deployment. #>
        LocalConfigurationManager {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        # Set the hosts DNS.
        xDNSServerAddress DnsServerAddress {
            Address        = $DNS
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
        }

        # Join the domain. This will trigger a reboot.
        xComputer JoinDomain {
            Name = $VMName
            DomainName = $DomainName 
            Credential = $DomainCredentials  # Credential to join to domain
            DependsOn = '[xDNSServerAddress]DnsServerAddress'
        }

        # Install the Windows Server DNS feature.
        WindowsFeature DNS {
            Ensure = "Present"
            Name = "DNS"
	        DependsOn = '[xComputer]JoinDomain'
        }

        # Install Active Directory Domain Services with subfeatures.
        WindowsFeature ADDSInstall {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            IncludeAllSubFeature = $true
            DependsOn = '[WindowsFeature]DNS'
        }

        # Install remote administration tools with subfeatures.
        WindowsFeature RSATTools { 
            DependsOn= '[WindowsFeature]ADDSInstall'
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
        }  

        <# If previous configurations are successfull, install and deploy
         the domain controller. This will trigger a reboot. #>
        xADDomainController DomainController {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCredentials
            SafemodeAdministratorPassword = $SafeModeCredentials
            DatabasePath = "C:\NTDS"
            LogPath = "C:\NTDS"
            SysvolPath = "C:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        <# After DC deployment the DC must replicate the pre-existing
         Primary Domain Controller. Instead of specifying the PDC in a parameter,
         it is programatically discovered using the "netdom" command to query the
         domain for the current flexible single operation master (PDC).
         When it is discovered, the repadmin command will force the replication. #>
        Script ReplicateDomain {

            DependsOn = "[xADDomainController]DomainController"

            <# Executed when Get-DscConfiguration cmdlet is run. 
            It is used to discover current host state. #>
            GetScript = { Return Get-ADDomain }  

            <# Executed when Start-DscConfiguration cmdlet is run. 
            Our migration solution only implements this script block. #>
            SetScript = {

                $FSMO = netdom query fsmo
                $Master = $FSMO[0] | % { $_.Split(" ")} | select -last 1 | % {$_.Split(".")}
                $Root = [ADSI]"LDAP://RootDSE"
                $DomainDN = $Root.Get("rootDomainNamingContext")

                repadmin /replicate $env:COMPUTERNAME $Master[0] $DomainDN /full
            }

            <# Executed when Start- or Test-DscConfiguration cmdlet is run.
            If it returns false, it wil use SetScript block to set the host
            to the desired state. This configuration will never be used on
            a host with the desired state so it will always return false. #>
            TestScript = { return $false }
        }

        <# After the new DC has successfully replicated the PDC, it must seize
        all master roles from the pre-existing DC:
        * Primary Domain Controller
        * Schema Master
        * RID Master
        * Infrastructure Master
        * Domain Naming Master #>
        Script MoveControllerRoles {

            DependsOn = "[Script]ReplicateDomain"

            GetScript = { Return "foo" }  

            SetScript = {

                    Move-ADDirectoryServerOperationMasterRole -Identity localhost -OperationMasterRole 0,1,2,3,4 -Confirm:$false -Force
            }

            TestScript = { return $false }
        }
        
        }
    }