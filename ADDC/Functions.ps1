$script:globalvar = "topkek"
$ScriptBlock = {
    Param(
        $p1,
        $p2
        )
    function do-something {
    Param (
        $index,
        $family
        )
        Get-DnsClientServerAddress -InterfaceIndex $index -AddressFamily $family
        Write-Host $script:globalvar
    }
    do-something -index $p1 -family $p2
}

Function do-else {
    Invoke-Command -ComputerName TESTSRV-2016 -ScriptBlock $ScriptBlock -ArgumentList 5,"IPv4" -Credential Administrator
}