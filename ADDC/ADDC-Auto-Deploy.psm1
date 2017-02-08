Function Init-Process {
Param (
    $domain,
    $addresses,
    $netbios,
    $pw,
    $computer
    )

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
        #Add-Computer -ComputerName $computer -DomainName $domain -Credential Administrator
    }
}
        Configure-DomainDNS -addresses $p1 -domain $p2 -computer $p3 
    }
    $cred = Get-Credential
    Invoke-Command -ComputerName $computer -ScriptBlock $CfgDns -ArgumentList $addresses,$domain,$computer -Credential $cred
    Reboot-and-Deploy -computer $computer -credential $cred
    
} 

Workflow Reboot-and-Deploy {
Param(
    $domain,
    $addresses,
    $netbios,
    $pw,
    $computer,
    $credential
    )
    #Restart-Computer -PSComputerName $computer -Force -Wait -For WinRM
    InlineScript { 
        $depDC = {
        Param (
            $p1,
            $p2,
            $p3
            )
            Function Deploy-DomainController {

Param($pw, $domainname, $netbiosname)

Begin {
    Add-WindowsFeature -Name “ad-domain-services” -IncludeAllSubFeature -IncludeManagementTools
    Import-Module ADDSDeployment
}

Process {
    $password = ConvertTo-SecureString $pw -AsPlainText -Force

    $result = Test-ADDSForestInstallation -DomainName $domainname `
        -DomainNetbiosName $netbiosname `
        -ForestMode “Win2012” `
        -DomainMode “Win2012” `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $password

    If ($result.status -eq "Success") {
        Write-Host "Prerequisites for ADDS Forest Installation was tested successfully."
        $confirm = ""
        #While ($confirm -notmatch "[y|n]"){
        #    $confirm = read-host "Do you want to continue? (Y/N)"
        #}
    } Else {
        Write-Host "Test failed:"
        Write-Host $result.Message
    }

    #If ($confirm -eq "y"){
        Try {
            Write-Host "Installing"
            Install-ADDSForest -DomainName $domainname `
            -DomainNetbiosName $netbiosname `
            -DatabasePath “C:\Windows\NTDS” `
            -SysvolPath “C:\Windows\SYSVOL” `
            -LogPath “C:\Windows\NTDS” `
            -ForestMode “Win2012” `
            -DomainMode “Win2012” `
            -InstallDns:$true `
            -CreateDnsDelegation:$false `
            -SafeModeAdministratorPassword $password `
            -Force:$true
        } Catch {
            Write-Host "Install failed:"
            Write-Host $_.Exception.Message
        }
    #}
}
}
            Deploy-DomainController -pw $p1 -domainname $p2 -netbiosname $p3
        }
        Invoke-Command -Credential $credential -ScriptBlock $depDC -ArgumentList $pw,$domain,$netbios -ComputerName $computer 
    }
}