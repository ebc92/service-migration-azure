Function Start-ADDCDeploymentProcess {

Param (
    [Parameter(Mandatory=$true)]$domain,
    [Parameter(Mandatory=$true)]$addresses,
    [Parameter(Mandatory=$true)]$pw,
    [Parameter(Mandatory=$true)]$computer
)
    . ..\Support\Get-GredentialObject.ps1

    $DomainCredential = Get-CredentialObject -domain $domain
    $Credential = Get-CredentialObject

    $CfgDns = {
    
        Param(
            $p1,
            $p2,
            $p3,
            $p4
        )
        
        Function Configure-DomainDNS {

        Param(
        $addresses, 
        $domain, 
        $computer,
        $DomainCredential
        )

        Process {
            Try {
                $interface = Get-NetAdapter | Select ifIndex,InterfaceDescription
                #Logging
                Write-Host "Configuring DNS on adapter $($interface[0].InterfaceDescription)"

                Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses($addresses)
                    
                $dns = Get-DnsClientServerAddress | Select InterfaceIndex,AddressFamily,ServerAddresses
                foreach ($element in $dns) {
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
                Add-Computer -ComputerName $computer -DomainName $domain -Credential $DomainCredential
            } Catch {
                Write-Host $_.Exception.Message
            }
        }
        }

    Configure-DomainDNS -addresses $p1 -domain $p2 -computer $p3 -DomainCredential $p4
    }
    
    Invoke-Command -ComputerName $computer -ScriptBlock $CfgDns -ArgumentList $addresses,$domain,$computer,$DomainCredential -Credential $Credential
    Reboot-and-Deploy -computer $computer -credential $DomainCredential -pw $pw -functionDeployDC ${Function:Deploy-DomainController} -FunctionMoveFSMO ${Function:Move-OperationMasterRoles}
} 

Workflow Reboot-and-Deploy {

Param(
    [Parameter(Mandatory=$true)] $pw,
    [Parameter(Mandatory=$true)] $computer,
    [Parameter(Mandatory=$true)] $credential,
    [Parameter(Mandatory=$true)] $FunctionDeployDC,
    [Parameter(Mandatory=$true)] $FunctionMoveFSMO
)

    Restart-Computer -PSComputerName $computer -Force -Wait -For WinRM

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
              
        Invoke-Command -ComputerName $using:computer -ScriptBlock $depDC -ArgumentList $using:FunctionDeployDC,$using:pw,$using:credential -Credential $using:credential

        
    }

    InlineScript {

        . ..\Support\Start-RebootCheck.ps1

        Start-RebootCheck -ComputerName $computer

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

        Invoke-Command -ComputerName $using:computer -ScriptBlock $postDep -ArgumentList $using:FunctionMoveFSMO -Credential $using:credential  
    }

    Write-Output "End of script"
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
    Write-Output "Installing"
    Install-ADDSDomainController -DomainName (Get-WmiObject win32_computersystem).Domain -InstallDns -SafeModeAdministratorPassword $password -Credential $domaincred -Force
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