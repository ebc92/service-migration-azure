Function Start-RebootCheck {
    Param (
        $ComputerName
    )

        $down = $true
            Do {
                Try {
                    Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
                    $down = $false
                } Catch {
                    Write-Output "Waiting for reboot to finish."
                }
            } While ($down)
        Write-Output "The WinRM service is started and the reboot was successful."
}