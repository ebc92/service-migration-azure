Param(
    [string]$DNS
)
Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter)[0].ifIndex -ServerAddresses($DNS)