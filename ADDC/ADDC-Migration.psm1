Function Move-OperationMasterRoles {
Param(
    $ComputerName
)
    Try {
        Move-ADDirectoryServerOperationMasterRole -Identity $ComputerName -OperationMasterRole 0,1,2,3,4 -Confirm:$false -ErrorAction Stop
        Write-Output "All Operation Master roles were successfully migrated."
        Log-Write -LogPath $sLogFile -LineValue "All Operation Master roles were successfully migrated."
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $false
    }
}

Function Start-GpoExport {
Param (
    $Path, 
    $DNS, 
    $DomainCredential )
    #Configure-ClientDNS script assumes client only has one ethernet adapter
    Try {
        New-Item -Name "Configure-ClientDNS.ps1" -ItemType File -Path (Join-Path -Path $Path -ChildPath 'Support\GPO\{23479CB6-4EC3-4B0E-8DF3-A5F046CC623F}\DomainSysvol\GPO\Machine\Scripts\Startup\') `
        -Value "Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter)[0].ifIndex -ServerAddresses $DNS" -Force -ErrorAction Stop
        Log-Write -LogPath $sLogFile -LineValue "Successfully exported GPO for configuring new client DNS.."
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $false
    }

    Try {
        Log-Write -LogPath $sLogFile -LineValue "Attaching network drive for GPO export.."
        New-PSDrive -PSProvider FileSystem -Name "share" -Root \\192.168.58.115\C$\share -Credential $DomainCredential -ErrorAction Stop
        Log-Write -LogPath $sLogFile -LineValue "Network drive successfully added."
    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "Could not attach network drive."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $false
    }
    Copy-Item -Path (Join-Path -Path $Path -ChildPath "Support\GPO\") -Destination share:\ -Recurse -Force
}

Function Start-GpoImport {
Param (
    $Credential,
    $OrganizationalUnits )
    Try {
        Log-Write -LogPath $sLogFile -LineValue "Attaching network drive for GPO import.."
        New-PSDrive -PSProvider FileSystem -Name "share" -Root \\192.168.58.115\C$\share -Credential $Credential -ErrorAction Stop
        Log-Write -LogPath $sLogFile -LineValue "Network drive successfully added."
    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "Could not attach network drive.."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $false
    }
    
    Copy-Item 'share:\GPO' -Recurse -Destination C:\GPO
    $GpoName = "Post-Migration DNS GPO"
    New-GPO -Name $GpoName
    Import-GPO -BackupGpoName "Post-Migration DNS Update" -Path C:\GPO -TargetName $GpoName
    New-GPLink -Name $GpoName -Target "OU=Computers,DC=amstel,DC=local"
}