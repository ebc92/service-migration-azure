Function Get-RegValue {
#args(
#)

Process {
    $sourcecomp = "158.38.43.115"
    $tarcomp = "158.38.43.116"
    $username = "administrator"
    $passord = ConvertTo-SecureString "swEn5ce?" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$passord



    $regname = (Invoke-Command -ComputerName $sourcecomp -Credential $credential -ScriptBlock { 
        Get-Item -path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ | Select-Object -ExpandProperty Property
        } )

    foreach($element in $regname) {
        Invoke-Command -ComputerName $sourcecomp -Credential $credential -ScriptBlock {
                $regvalue = (Get-ItemProperty -Path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\).$using:element
                write-host("navn på export regkey er: $using:element og regname er $regname, value er `n $regvalue ")
            }
        Invoke-Command -ComputerName $tarcomp -Credential $credential -ScriptBlock {
                New-ItemProperty -Path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ -Name $using:element -PropertyType String -Value $using:regvalue
                Write-Host("Navn på import regkey er: $using:element og regname er $using:regname value er `n $using:regvalue")
            }
        }
    }
}