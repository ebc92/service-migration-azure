Function Start-ADDCDeploymentProcess {

Param (
    [Parameter(Mandatory=$true)]$domain,
    [Parameter(Mandatory=$true)]$addresses,
    [Parameter(Mandatory=$true)]$pw,
    [Parameter(Mandatory=$true)]$computer
)

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
    Reboot-and-Deploy -computer $computer -credential $DomainCredential -pw $pw -functionDeployDC ${Function:Deploy-DomainController}
    
} 

Workflow Reboot-and-Deploy {

Param(
    [Parameter(Mandatory=$true)] $pw,
    [Parameter(Mandatory=$true)] $computer,
    [Parameter(Mandatory=$true)] $credential,
    $FunctionDeployDC,
    $FunctionRebootCheck
)

    Restart-Computer -PSComputerName $computer -Force -Wait -For WinRM -Credential $credential

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

    Start-RebootCheck -ComputerName $computer

    InlineScript {

        $postDep = {

        Param(
            $FunctionMoveFSMO,
            $ComputerName
        )
            
            New-Item -Path function: -Name Move-OperationMasterRoles -Value $FunctionMoveFSMO
            Move-OperationMasterRoles -ComputerName $ComputerName
        
            $query = netdom query fsmo
            $master = $query[0] | % { $_.Split(" ")} | select -last 1

            repadmin /kcc
            repadmin /replicate $env:COMPUTERNAME $master $domain.DistinguishedName /full

            Move-OperationMasterRoles -ComputerName $computer
        }

        Invoke-Command -ComputerName $using:computer -ScriptBlock $postDep -ArgumentList ${function:Move-OperationMasterRoles},$using:computer -Credential $using:credential
        
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
                    Write-Host "Installing"
                    Install-ADDSDomainController -DomainName (Get-WmiObject win32_computersystem).Domain -InstallDns -SafeModeAdministratorPassword $password -Credential $domaincred -Force
                } Catch {
                    Write-Host "Install failed:"
                    Write-Host $_.Exception.Message
                } 
            }
        }

Function Move-OperationMasterRoles {
Param(
    $ComputerName
)
<# 
########################################################
Updating the NTDS Object DNS hostname for FSMO migration
########################################################
    Try {
        $siteName = nltest /server:TESTSRV-2016 /dsgetsite
        $configNCDN = (Get-ADRootDSE).ConfigurationNamingContext
        $siteContainerDN = (“CN=Sites,” + $configNCDN)
        $serverContainerDN = “CN=Servers,CN=” + $siteName[0] + “,” + $siteContainerDN
        $serverReference = Get-ADObject -SearchBase $serverContainerDN –filter {(name -eq $ComputerName)} -Properties "DistinguishedName"
        $fqdns = $ComputerName + "." + (Get-ADDomain).DNSRoot    

        Set-ADObject -Identity $serverReference.DistinguishedName -Add @{dNSHostName=$fqdns}

        Move-ADDirectoryServerOperationMasterRole -Identity $ComputerName -OperationMasterRole 0,1,2,3,4
    } Catch {
        Write-Host $_.Exception.Message
    }
    #>
    Move-ADDirectoryServerOperationMasterRole -Identity $ComputerName -OperationMasterRole 0,1,2,3,4
}

Function Get-CredentialObject {
Param (
    $domain
)
    $user = "Administrator"

    if ($domain -ne $null){
        $username = "$domain\$user"
        $password = Read-Host -Prompt "Enter domain Administrator password" -AsSecureString
    } else {
        $username = $user
        $password = Read-Host -Prompt "Enter local Administrator password" -AsSecureString
    }
        
    $credential = New-Object System.Management.Automation.PSCredential($username, $password)

    return $credential
}

Function Start-RebootCheck {
    Param (
        $ComputerName
    )

        $down = $true
            Do {
                Try {
                    Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
                    $down = $false
                } Catch {
                    Write-Output "Waiting for reboot to finish."
                }
            } While ($down)
        Write-Output "The WinRM service is started and the reboot was successful."
    }