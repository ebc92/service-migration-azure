Function Start-ADDCDeploymentProcess {

Param (
    $domain,
    $addresses,
    $pw,
    $computer
)

    $domaincred = Get-Credential
    $cred = Get-Credential

    $CfgDns = {
    
        Param(
            $p1,
            $p2,
            $p3
        )
        
        Function Configure-DomainDNS {

        Param($addresses, $domain, $computer)

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
                Add-Computer -ComputerName $computer -DomainName $domain -Credential $domaincred
            } Catch {
                Write-Host $_.Exception.Message
            }
        }
        }

    Configure-DomainDNS -addresses $p1 -domain $p2 -computer $p3 
    }
    
    Invoke-Command -ComputerName $computer -ScriptBlock $CfgDns -ArgumentList $addresses,$domain,$computer -Credential $cred
    Reboot-and-Deploy -computer $computer -credential $domaincred -pw $pw
    
} 

Workflow Reboot-and-Deploy {

Param(
    $pw,
    $computer,
    $credential
)

    Restart-Computer -PSComputerName $computer -Force -Wait -For WinRM

    InlineScript {
     
        $depDC = {

        Param (
            $p1,
            $p2
        )
            
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

                $query = netdom query fsmo
                $master = $query[0] | % { $_.Split(" ")} | select -last 1

                Start-RebootTest -ComputerName $computer

                repadmin /kcc
                repadmin /replicate $env:COMPUTERNAME $master $domain.DistinguishedName /full

                Move-OperationMasterRoles -ComputerName $computer
            }
        }

        Deploy-DomainController -pw $p1 -domaincred $p2
        }
              
        Invoke-Command -Credential $using:credential -ScriptBlock $depDC -ArgumentList $using:pw,$using:credential -ComputerName $using:computer 
        
        Write-host "EOS"
    }
}

Function Move-OperationMasterRoles {
Param(
    $ComputerName
)
<#
    Try {
        #Building the server container DN to get the server reference
        $siteName = nltest /server:TESTSRV-2016 /dsgetsite
        $configNCDN = (Get-ADRootDSE).ConfigurationNamingContext
        $siteContainerDN = (“CN=Sites,” + $configNCDN)
        $serverContainerDN = “CN=Servers,CN=” + $siteName[0] + “,” + $siteContainerDN
        $serverReference = Get-ADObject -SearchBase $serverContainerDN –filter {(name -eq $ComputerName)} -Properties "DistinguishedName"
        Write-Output $serverReference

        $fqdns = $ComputerName + "." + (Get-ADDomain).DNSRoot

        #Update DNS hostname by server reference
        
        Set-ADObject -Identity $serverReference.DistinguishedName -Add @{dNSHostName=$fqdns}

    } Catch {
        Write-Host $_.Exception.Message
    }
    #>
    Move-ADDirectoryServerOperationMasterRole -Identity $ComputerName -OperationMasterRole 0,1,2,3,4
    #Verify netdom query fsmo
}

Function Start-RebootTest {
Param (
    $ComputerName
)

    $down = $true
        Do {
            Try {
                Test-WSMan -ComputerName testsrv-2 -ErrorAction Stop
                $down = $false
            } Catch {
                Write-Output "There was an error ermagherd"
            }
        } While ($down)
    return $down
}