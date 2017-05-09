Param(
    $DomainName,
    $Username,
    $Password
)

Set-ExecutionPolicy Unrestricted

$Credential = New-Object System.Management.Automation.PSCredential($Username,$Password)

Add-Computer -DomainName $DomainName -Credential $Credential

Enable-PSRemoting -Force

Set-Item wsman::localhost\Client\TrustedHosts -Value "*" -Force