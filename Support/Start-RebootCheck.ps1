<# Script attempts to establish a PowerShell session to the $ComputerName,
and loops until connection is successful. Removes the session afterwards. #>

Param (
  $ComputerName,
  $DomainCredential
)
$NoConnectivity = $true
do {
  try {
    Write-Output "Trying connection to $ComputerName..."
    if ($s = New-PSSession -ComputerName $ComputerName -Credential $DomainCredential -ErrorAction Stop){
    Write-Output "PSSession successfully established."
    Remove-PSsession $s
    $NoConnectivity = $false}
  } catch {
    $RetryTime = 30
    Write-Output "Cannot establish PowerShell connectivity to the server. Retrying in $RetryTime seconds."
    start-sleep -s $RetryTime
  }
} while ($NoConnectivity)
