Param(
    $ComputerName, 
    $Source, 
    $PackagePath, 
    $InstanceName, 
    $Credential, 
    $SqlCredential
)

#Install modules on remote computer.
Invoke-Command -ComputerName $ComputerName -FilePath $ModulePath -Credential $Credential 

Start-MSSQLInstallConfig -PackagePath $PackagePath -Credential $Credential

Start-MSSQLDeployment -ComputerName $ComputerName -PackagePath $PackagePath -InstanceName $InstanceName -Credential $Credential

Log-Write -LogPath $sLogFile -LineValue "SQL Server 2016 was successfully deployed on $ComputerName."

#Log-Write -LogPath $sLogFile -LineValue "Starting SQL Instance migration from $Source\$InstanceName to $ComputerName\$InstanceName."

#Start-MSSQLMigration -Source $Source -Destination $ComputerName -InstanceName $InstanceName -Share $PackagePath -SqlCredential $SqlCredential -Credentials $Credential