Param(
    $TrustedHost
)
Set-Item wsman::localhost\Client\TrustedHosts -Value $TrustedHost