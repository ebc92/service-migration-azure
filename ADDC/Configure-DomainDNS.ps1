Function Configure-DomainDNS {

<#
  .SYNOPSIS
  Configure and verify new DNS addresses.
  .DESCRIPTION
  Assumes there is only 1 valid ethernet interface.
  .EXAMPLE
  Example syntax
  #>

Param($addresses, $domain)

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
        Add-Computer -DomainName $domain
        Restart-Computer
        } Catch {
            Write-Host "Install failed:"
            Write-Host $_.Exception.Message
        }
    }
}