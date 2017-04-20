Function Move-OperationMasterRoles {
Param(
    $ComputerName
)
    Try {
        Move-ADDirectoryServerOperationMasterRole -Identity $ComputerName -OperationMasterRole 0,1,2,3,4 -Confirm:$false -ErrorAction Stop
        Write-Output "All Operation Master roles were successfully migrated."
    } Catch {
            Write-Output $_.Exception.message
    }
}

Function Start-GpoCopy {
Param ($DNS, $Credential )
    Try {
        New-Item -Name "Configure-ClientDNS.ps1" -Path '.\Support\GPO\{23479CB6-4EC3-4B0E-8DF3-A5F046CC623F}\DomainSysvol\GPO\Machine\Scripts\Startup\' `
        -Value "Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter)[0].ifIndex -ServerAddresses $DNS" -ErrorAction Stop
    } Catch {
        
    }

    New-PSDrive -PSProvider FileSystem -Name "share" -Root \\158.38.43.115\C$\Share -Credential $Credential -ErrorAction Stop
    Copy-Item '.\Support\GPO\' -Destination share:\ -Recurse
}

Function Start-GpoImport {
Param ($Credential)
    New-PSDrive -PSProvider FileSystem -Name "share" -Root \\158.38.43.115\C$\Share -Credential $Credential -ErrorAction Stop
    Copy-Item 'share:\GPO' -Recurse -Destination C:\GPO
    $GpoName = "Post-Migration DNS GPO"
    New-GPO -Name $GpoName
    Import-GPO -BackupGpoName "Post-Migration DNS Update" -Path C:\GPO -TargetName $GpoName
    New-GPLink -Name $GpoName -Target "OU=DNS Update,DC=amstel,DC=local"
}