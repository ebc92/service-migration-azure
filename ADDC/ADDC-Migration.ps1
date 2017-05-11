#Getting migration variables from configuration file
$DNS =   $SMAConfig.ADDC.source
$ComputerName = $SMAConfig.ADDC.destination
$VMName = $SMAConfig.ADDC.hostname
$InterfaceAlias = $SMAConfig.ADDC.interfacealias
$DomainName = $SMAConfig.ADDC.domainname

$aLogPath = $SMAConfig.Global.logpath
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$aLogName = "SMA-ADDC-$($xLogDate).log"
$aLogFile = Join-Path -Path $aLogPath -ChildPath $aLogName

#DSC Prerequisities
Invoke-Command -ComputerName $ComputerName -Credential $DomainCredential -ScriptBlock {Install-Module xComputerManagement, xActiveDirectory, xNetworking -Force}
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
Log-Write -LogPath $aLogFile -LineValue "Creating DSC configuration document.."
DesiredStateAD -ComputerName $ComputerName -$InterfaceAlias -VMName $VMName -ConfigurationData $cd -DNS $DNS -DomainName $DomainName -DomainCredentials $DomainCredential -SafeModeCredentials $DomainCredential
$DSCDocument = Join-Path -Path (Get-Location) -ChildPath "DesiredStateAD"
Set-DscLocalConfigurationManager -ComputerName $ADServer -Path $DSCDocument -Credential $LocalCredentials

Start-Transcript -Path $aLogFile -Append

Start-DscConfiguration -ComputerName $ComputerName -Path $DSCDocument -Credential $DomainCredential -Wait -Force -Verbose

Stop-Transcript