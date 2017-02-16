Function Get-RegValue {
Param(
    [parameter(Mandatory=$true)]$SourceComputer,
    [parameter(Mandatory=$true)]$TarComputer,
    [parameter(Mandatory=$true)]$Credential,
    [parameter(Mandatory=$true)]$RegPath,
    $regvalue
    )
Process {

    $RegName = (Invoke-Command -ComputerName $SourceComp -Credential $Credential -ScriptBlock { 
        Get-Item -path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ | Select-Object -ExpandProperty Property
        } )

    foreach($element in $RegName) {
        $RegValue = Invoke-Command -ComputerName $SourCecomp -Credential $Credential -ScriptBlock {
                (Get-ItemProperty -Path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\).$using:element
                #write-host("navn på export regkey er: $using:element og regname er $regname, value er `n $regvalue ")
            }
        Invoke-Command -ComputerName $TarComp -Credential $Credential -ScriptBlock {
            if(Get-ItemProperty -name $using:element -Path $using:RegPath -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $using:RegPath -Name $using:element -Value $using:RegValue
                    #Write-Host("Fann en key, oppdaterer denne. Navn på import regkey er: $using:element og regname er $using:regname value er `n $using:regvalue")
                } else {
                    New-ItemProperty -Path $using:RegPath -Name $using:element -PropertyType MultiString -Value $using:RegValue
                    #Write-Host("Ingen key oppdaget, lager ny. Navn på import regkey er: $using:element og regname er $using:regname value er `n $using:regvalue")
                }
            }
        }
    }
}