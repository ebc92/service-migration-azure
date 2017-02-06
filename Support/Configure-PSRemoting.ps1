Function Configure-PSRemoting {
Param($computer)
Process {
    Enable-PSRemoting -Force
    $val = (get-item wsman:\localhost\Client\TrustedHosts).value
    If($val){
        set-item wsman:\localhost\Client\TrustedHosts -value "$val, $computer" -Force
    } Else {
    set-item wsman:\localhost\Client\TrustedHosts -value "$computer" -Force
    }
    Restart-Service WinRM
}
}