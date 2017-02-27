Param($ComputerName, $Source, $PackagePath, $InstanceName, $Credential)

Log-Start -LogPath $sLogFile -LogName $sLogName -ScriptVersion $sScriptVersion

Import-Module $PSScriptRoot\MSSQL-Migration.psm1 -Force

#Install modules on remote computer.
Invoke-Command -ComputerName $ComputerName -ScriptBlock $PSScriptRoot\..\Support\Install-SMModule.ps1 -Credential $Credential

$ConfigureSQL = {
    Param(
        $PackagePath,
        $Credential
    )
    Start-MSSQLInstallConfig -PackagePath $PackagePath -Credential $Credential
}
Invoke-Command -ComputerName $ComputerName -ScriptBlock $ConfigureSQL -ArgumentList $PackagePath, $Credential -Credential $Credential

Start-MSSQLDeployment -ComputerName $ComputerName -PackagePath $PackagePath -InstanceName $InstanceName -Credential $Credential

Log-Write -LogPath $sLogFile -LineValue "SQL Server 2016 was successfully deployed on $ComputerName."

Log-Write -LogPath $sLogFile -LineValue "Starting SQL Instance migration from $Source\$InstanceName to $ComputerName\$InstanceName."
Start-MSSQLMigration -Source $Source -Destination $ComputerName -InstanceName $InstanceName -Share $PackagePath -SqlCredential $Credential.GetNetworkCredential().Password

Log-Finish -LogPath $sLogFile -NoExit $True