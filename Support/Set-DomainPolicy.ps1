Param(
    $DomainName,
    $Username,
    $Password
)

Set-ExecutionPolicy Unrestricted

$Username = "$($DomainName.Split(".")[0])\$($Username)"
$SecureString = ConvertTo-SecureString $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($Username,$SecureString)

Add-Computer -DomainName $DomainName -Credential $Credential

Enable-PSRemoting -Force

Set-Item wsman::localhost\Client\TrustedHosts -Value "*" -Force

Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -RemoteAddress Any