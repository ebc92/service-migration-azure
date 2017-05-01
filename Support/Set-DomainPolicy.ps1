Param(
    $DomainName,
    $DomainCredential
)

$Policy = Get-ExecutionPolicy

if($Policy -ne "Unrestricted"){
    Set-ExecutionPolicy Unrestricted
}

$Domain = (Get-WmiObject Win32_ComputerSystem).Domain

if($Domain -ne $DomainName){
    Add-Computer -DomainName amstel.local -Credential $DomainCredential
}
