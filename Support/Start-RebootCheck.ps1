Function Start-RebootCheck {
    Param (
        $ComputerName,
        $DomainCredential
    )
    $NoConnectivity = $true
        do {
            try {
                Write-Output "Trying connection to $ComputerName..."
                if (New-PSSession -ComputerName $ComputerName -Credential $DomainCredential -ErrorAction Stop){
                Write-Output "yay" 
                $NoConnectivity = $false}
            } catch {
                $RetryTime = 30
                Write-Output "Cannot establish PowerShell connectivity to the server. Retrying in $RetryTime seconds."
                start-sleep -s $RetryTime
            }
        } while ($NoConnectivity)
}