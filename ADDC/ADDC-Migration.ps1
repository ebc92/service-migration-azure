#Getting migration variables from configuration file
$DNS =   $SMAConfig.ADDC.source
$ComputerName = $SMAConfig.ADDC.destination
$VMName = $SMAConfig.ADDC.hostname
$InterfaceAlias = $SMAConfig.ADDC.interfacealias
$DomainName = $SMAConfig.ADDC.domainname
$aLogPath = $SMAConfig.Global.logpath

#Building a string with time and date to use as file name for log file.
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$aLogName = "SMA-ADDC-$($xLogDate).log"
$aLogFile = Join-Path -Path $aLogPath -ChildPath $aLogName

<# Remotely install the DSC resources needed to successfully
 deploy and configure ADDC on Azure VM. #>
Invoke-Command -ComputerName $ComputerName -Credential $DomainCredential -ScriptBlock {Install-Module xComputerManagement, xActiveDirectory, xNetworking -Force}

<# The DSC Local Configuration Manager must allow operations as
 a domain user and handling plaintext credentials. This is
 specified in the DSC configuration data defined here. #>
$cd = @{
    AllNodes = @(
        @{
            NodeName = $ComputerName
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    )
}

<# The AD DSC configuration is used to generate a DSC document.
 The configuration data is passed to the destination Local 
 Configuration Manager in the generated document. #>
Log-Write -LogPath $aLogFile -LineValue "Creating DSC configuration document.."
DesiredStateAD -ComputerName $ComputerName -InterfaceAlias $InterfaceAlias -VMName $VMName -ConfigurationData $cd -DNS $DNS -DomainName $DomainName -DomainCredentials $DomainCredential -SafeModeCredentials $DomainCredential
$DSCDocument = Join-Path -Path (Get-Location) -ChildPath "DesiredStateAD"
Set-DscLocalConfigurationManager -ComputerName $ADServer -Path $DSCDocument -Credential $LocalCredentials


<# DSC document is passed to the destination host and starts
 the deployment process. To achieve a high log level, the 
 verbose output of the DSC deployment is written to the service log file. #>
Start-Transcript -Path $aLogFile -Append
Start-DscConfiguration -ComputerName $ComputerName -Path $DSCDocument -Credential $DomainCredential -Wait -Force -Verbose
Stop-Transcript