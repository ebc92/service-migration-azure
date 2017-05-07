Function Connect-Exchange {
  Param(
    [Parameter(Mandatory=$true)]
    [pscredential]$DomainCredential,
    [Parameter(Mandatory=$true)]
    [String]$ComputerName
  )
  
  $exchangesession = New-PSSession -ConfigurationName Microsof.Exchange -ConnectionUri http://$ComputerName/PowerShell `
  -Credential $DomainCredential -Authentication Kerberos

}