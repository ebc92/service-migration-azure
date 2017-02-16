Function Get-CredentialObject {
Param (
    $domain
)
    $user = "Administrator"

    if ($domain -ne $null){
        $domainname = $domain | % {$_.Split(".")}
        $result = $domainname[0]
        $username = "$result\$user"
        $password = Read-Host -Prompt "Enter domain Administrator password" -AsSecureString
    } else {
        $username = $user
        $password = Read-Host -Prompt "Enter local Administrator password" -AsSecureString
    }

    $credential = New-Object System.Management.Automation.PSCredential($username,$password)

    return $credential
}