Function Deploy-DomainController {

<#
  .SYNOPSIS
  Deploy and promote a domain controller on the local computer using ad-domain-services.
  .DESCRIPTION
  The function will run a prerequisite test for Install-ADDSForest. If successful, it will deploy
  and promote a domain controller and set up a new forest using provider params $domainname $netbiosname and $pw.
  .EXAMPLE
  Deploy-DomainController -domainname "mydomain.local" -netbiosname "mydomain" -pw "p455w0rd"
  #>

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
        While ($confirm -notmatch "[y|n]"){
            $confirm = read-host "Do you want to continue? (Y/N)"
        }
    } Else {
        Write-Host "Test failed:"
        Write-Host $result.Message
    }

    If ($confirm -eq "y"){
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
    }

}
}