Function Configure-PSRemoting {
Param($ComputerName)

Process {
    Enable-PSRemoting -Force
    $val = (get-item wsman:\localhost\Client\TrustedHosts).value
    If($val){
        set-item wsman:\localhost\Client\TrustedHosts -value "$val, $ComputerName" -Force
    } Else {
    set-item wsman:\localhost\Client\TrustedHosts -value "$ComputerName" -Force
    }
    netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes
    
    Set-Service -Name WinRM -StartupType Boot

    Restart-Service WinRM
}
}