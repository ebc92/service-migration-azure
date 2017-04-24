
$ComputerName = "192.168.58.114"
$VMName = "TESTSRV-2"
$DSCDocument = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\DesiredStateAD")

$InterfaceAlias = "Ethernet0"
    
#$target = New-AzureStackTenantDeployment -VMName $VMName -IPAddress "192.168.59.113/24"
#Log-Write -LogPath $sLogFile -LineValue "VM was provisioned, target is $($target)"

Invoke-Command -ComputerName "192.168.58.114" -Credential $LocalCredentials -ScriptBlock {Install-Module xComputerManagement, xActiveDirectory, xNetworking -Force}

$cd = @{
    AllNodes = @(
        @{
            NodeName = $ComputerName
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    )
}
    
Log-Write -LogPath $sLogFile -LineValue "Creating DSC configuration document.."

$result = DesiredStateAD -ComputerName $ComputerName -$InterfaceAlias -VMName $VMName -ConfigurationData $cd -DNS 192.168.58.113 -DomainName amstel.local -DomainCredentials $DomainCredential -SafeModeCredentials $DomainCredential

Set-DscLocalConfigurationManager -ComputerName $ADServer -Path $DSCDocument -Credential $LocalCredentials

Start-DscConfiguration -ComputerName $ComputerName -Path $DSCDocument -Credential $LocalCredentials -Wait -Force -Verbose 4>> $sLogFile

#Move operation master roles

#---------dns update-------


#Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "ADDC-Migration.psm1") -Force
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
Start-GpoExport -Path $SMARoot -DNS "192.168.58.114" -DomainCredential $DomainCredential

