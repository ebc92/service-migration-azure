Param (
    $ADServer,
    $VMName,
    $DSCDocument
)
    
    #$target = New-AzureStackTenantDeployment -VMName "TenantAD" -IPAddress "192.168.59.113/24"

Invoke-Command -ComputerName "192.168.59.113" -Credential $LocalCredentials -ScriptBlock {Install-Module xComputerManagement, xActiveDirectory, xNetworking -Force}

$cd = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    )
}
    
Log-Write -LogPath $sLogFile -LineValue "Creating DSC configuration document.."

$result = InstallADDC -ConfigurationData $cd -DNS 192.168.58.113 -ComputerName $VMName -DomainName amstel.local -DomainCredentials $Credentials -SafeModeCredentials $Credentials | out-string

Log-Write -LogPath $sLogFile -LineValue $result

Set-DscLocalConfigurationManager -ComputerName $ADServer -Path $DSCDocument -Credential $LocalCredentials

Start-DscConfiguration -ComputerName $ADServer -Path $DSCDocument -Credential $LocalCredentials -Wait -Force -Verbose 4>> $sLogFile