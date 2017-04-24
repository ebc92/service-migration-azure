#Getting migration variables from configuration file
$AzureStack = $SMAConfig.Global.Get_Item('azurestack')
$DNS =   $SMAConfig.ADDC.Get_Item('source')
$ComputerName = $SMAConfig.ADDC.Get_Item('destination')
$VMName = $SMAConfig.ADDC.Get_Item('hostname')
$InterfaceAlias = $SMAConfig.ADDC.Get_Item('interfacealias')
$DomainName = $SMAConfig.ADDC.Get_Item('domainname')
    
#AzureStack VM Provisioning
#$target = New-AzureStackTenantDeployment -VMName $VMName -IPAddress "192.168.59.113/24"
#Log-Write -LogPath $sLogFile -LineValue "VM was provisioned, target is $($target)"

#DSC Prerequisities
Invoke-Command -ComputerName $ComputerName -Credential $LocalCredentials -ScriptBlock {Install-Module xComputerManagement, xActiveDirectory, xNetworking -Force}
$cd = @{
    AllNodes = @(
        @{
            NodeName = $ComputerName
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    )
}

#DSC Deployment
Log-Write -LogPath $sLogFile -LineValue "Creating DSC configuration document.."
DesiredStateAD -ComputerName $ComputerName -$InterfaceAlias -VMName $VMName -ConfigurationData $cd -DNS $DNS -DomainName $DomainName -DomainCredentials $DomainCredential -SafeModeCredentials $DomainCredential
$DSCDocument = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\DesiredStateAD")
Set-DscLocalConfigurationManager -ComputerName $ADServer -Path $DSCDocument -Credential $LocalCredentials
Start-DscConfiguration -ComputerName $ComputerName -Path $DSCDocument -Credential $LocalCredentials -Wait -Force -Verbose 4>> $sLogFile

#DNS GPO Update
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
Start-GpoExport -Path $SMARoot -DNS $ComputerName -DomainCredential $DomainCredential

