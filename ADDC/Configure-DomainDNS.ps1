Function Configure-DomainDNS {

Param($addresses, $domain, $ComputerName)

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
        Add-Computer -DomainName $domain
        Share-and-Deploy -computer $ComputerName
    }
}
Workflow Share-and-Deploy {
Param($computer)
    Restart-Computer -PSComputerName $computer -Wait
    New-Item -PSComputerName $computer -Name "Scripts" -ItemType Directory
 
    InlineScript {New-SMBShare –Name “Scripts” –Path “C:\Scripts” –FullAccess amstel\Administrator } -PSComputerName $computer
    Start-sleep 2
    New-PSDrive -Name "E" -PSProvider FileSystem -Root \\TESTSRV-2016\Scripts
    Copy-Item C:\Users\Administrator\Desktop\service-migration-azure\ADDC\Deploy-DomainController.ps1 E:
    Start-sleep 2
    InlineScript {. C:\Scripts\Deploy-DomainController.ps1 -domainname amstel.local -netbiosname amstel -pw "p455w0rd"} -PSComputerName $computer
}