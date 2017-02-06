Function Configure-PSRemoting {
Param($computer)
Process {
    Enable-PSRemoting -Force
    $val = (get-item wsman:\localhost\Client\TrustedHosts).value
    set-item wsman:\localhost\Client\TrustedHosts -value "$computer" -Force
}
}