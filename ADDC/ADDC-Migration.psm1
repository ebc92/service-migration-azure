Function Start-ADDCDeployment {
    Param (
        [Parameter(Mandatory=$true)]
        [String]$DNS,
        [Parameter(Mandatory=$true)]
        [String]$DomainName,
        [Parameter(Mandatory=$true)]
        [PSCredential]$LocalCredentials
    )

    Try {
            Log-Write -LogPath $sLogFile -LineValue "Generating MOF-file from DSC script.."s
            ADDCInstall -DNS $DNS -DomainName $DomainName -DomainCredential $DomainCredential

            Log-Write -LogPath $sLogFile -LineValue "Starting DSC configuration."
            Start-DscConfiguration -ComputerName $ComputerName -Path .\SQLInstall -Verbose -Wait -Force -Credential $LocalCredentials
            Log-Write -LogPath $sLogFile -LineValue "DSC configuration was succcessfully executed"

        } Catch {
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
}