Function Start-RebootCheck {
    Param (
        $ComputerName,
        $DomainCredential
    )
    $NoConnectivity = $true
        do {
            try {
                Write-Output "trying connection"
                if (New-PSSession -ComputerName 158.38.43.114 -Credential $DomainCredential -ErrorAction Stop){
                Write-Output "yay" 
                $NoConnectivity = $false}
            } catch {
                Write-Output "Cannot establish PowerShell connectivity to the server."
                start-sleep -s 30
            }
        } while($bool)
}