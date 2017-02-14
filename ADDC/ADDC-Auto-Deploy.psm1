Function Start-ADDCDeploymentProcess {

Param (
    [Parameter(Mandatory=$true)]$Domain,
    [Parameter(Mandatory=$true)]$DNS,
    [Parameter(Mandatory=$true)]$Password,
    [Parameter(Mandatory=$true)]$ComputerName
)
    . ..\Support\Get-GredentialObject.ps1

    $DomainCredential = Get-CredentialObject -domain $Domain
    $Credential = Get-CredentialObject

    $CfgDns = {
    
        Param(
            $DNS,
            $Domain,
            $ComputerName,
            $DomainCredential
        )
        
        Function Configure-DomainDNS {

        Param(
        $DNS, 
        $Domain, 
        $ComputerName,
        $DomainCredential
        )

        Process {
            Try {
                $interface = Get-NetAdapter | Select ifIndex,InterfaceDescription
                #Logging
                Write-Host "Configuring DNS on adapter $($interface[0].InterfaceDescription)"

                Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses($DNS)
                    
                $DNSClient = Get-DnsClientServerAddress | Select InterfaceIndex,AddressFamily,ServerAddresses
                foreach ($element in $DNSClient) {
                    If ($element.InterfaceIndex -eq $interface[0].ifIndex -and $element.AddressFamily -eq 2){
                            #Logging
                            Write-Host $element.ServerAddresses
                    }
                }
        
            } Catch {
                Write-Host "DNS config failed:"
                Write-Host $_.Exception.Message
            }
            Try {
                Add-Computer -ComputerName $ComputerName -DomainName $domain -Credential $DomainCredential
            } Catch {
                Write-Host $_.Exception.Message
            }
        }
        }

    Configure-DomainDNS -DNS $DNS -Domain $Domain -ComputerName $ComputerName -DomainCredential $DomainCredential
    }
    
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $CfgDns -ArgumentList $DNS,$Domain,$ComputerName,$DomainCredential -Credential $Credential
    Reboot-and-Deploy -ComputerName $ComputerName -DomainCredential $DomainCredential -LocalCredential $Credential -pw $Password -functionDeployDC ${Function:Deploy-DomainController}

            . ..\Support\Start-RebootCheck.ps1

        Start-RebootCheck -ComputerName $ComputerName

        Start-sleep -s 30

        $postDep = {

        Param(
            $FunctionMoveFSMO
        )
            
            New-Item -Path function: -Name Move-OperationMasterRoles -Value $FunctionMoveFSMO

            $query = netdom query fsmo
            $master = $query[0] | % { $_.Split(" ")} | select -last 1

            repadmin /kcc
            repadmin /replicate $env:COMPUTERNAME $master (Get-ADDomain).DistinguishedName /full

            Move-OperationMasterRoles -ComputerName $env:COMPUTERNAME
        }

        Invoke-Command -ComputerName $ComputerName -ScriptBlock $postDep -ArgumentList ${Function:Move-OperationMasterRoles} -Credential $DomainCredential

    Write-Output "End of script"
} 

Workflow Reboot-and-Deploy {

Param(
    [Parameter(Mandatory=$true)] $pw,
    [Parameter(Mandatory=$true)] $ComputerName,
    [Parameter(Mandatory=$true)] $LocalCredential,
    [Parameter(Mandatory=$true)] $DomainCredential,
    [Parameter(Mandatory=$true)] $FunctionDeployDC
)

    Restart-Computer -PSComputerName $ComputerName -Protocol WSMan -Force -Wait -For WinRM -PSCredential $LocalCredential

    InlineScript {
     
        $depDC = {

        Param (
            $DeployFunction,
            $DomainPassword,
            $DomainCredential
        )

        New-Item -Path function: -Name Deploy-DomainController -Value $DeployFunction

        Deploy-DomainController -pw $DomainPassword -domaincred $DomainCredential

        }
              
        Invoke-Command -ComputerName $using:ComputerName -ScriptBlock $depDC -ArgumentList $using:FunctionDeployDC,$using:pw,$using:DomainCredential -Credential $using:DomainCredential

    }

}

Function Deploy-DomainController {

Param($pw, $domaincred)

Begin {
    Add-WindowsFeature -Name “ad-domain-services” -IncludeAllSubFeature -IncludeManagementTools
    Import-Module ADDSDeployment
}

Process {
    $password = ConvertTo-SecureString $pw -AsPlainText -Force
    Try {
    #Log
    Write-Output "Installing domain and promoting DC"
    Install-ADDSDomainController -DomainName (Get-WmiObject win32_computersystem).Domain -InstallDns -SafeModeAdministratorPassword $password -Credential $domaincred -ErrorAction Stop -Force
    } Catch {
        Write-Output "Install failed:"
        Write-Output $_.Exception.Message
    } 
}
}

Function Move-OperationMasterRoles {
Param(
    $ComputerName
)
<# 
########################################################
Updating the NTDS Object DNS hostname for FSMO migration.
########################################################
    Try {
        $siteName = nltest /server:TESTSRV-2016 /dsgetsite
        $configNCDN = (Get-ADRootDSE).ConfigurationNamingContext
        $siteContainerDN = (“CN=Sites,” + $configNCDN)
        $serverContainerDN = “CN=Servers,CN=” + $siteName[0] + “,” + $siteContainerDN
        $serverReference = Get-ADObject -SearchBase $serverContainerDN –filter {(name -eq $ComputerName)} -Properties "DistinguishedName"
        $fqdns = $ComputerName + "." + (Get-ADDomain).DNSRoot    

        Set-ADObject -Identity $serverReference.DistinguishedName -Add @{dNSHostName=$fqdns}
    } Catch {
    } #>
    Try {
        Move-ADDirectoryServerOperationMasterRole -Identity $ComputerName -OperationMasterRole 0,1,2,3,4 -Confirm:$false -ErrorAction Stop
        Write-Output "All Operation Master roles were successfully migrated."
    } Catch {
            Write-Output $_.Exception.message
    }
}