Param($ComputerName, $PackagePath, $InstanceName, $Credential)

Import-Module $PSScriptRoot\MSSQL-Migration.psm1 -Force

Log-Start -LogPath $sLogFile -LogName $sLogName -ScriptVersion $sScriptVersion

#TODO: On remote server: download and import mssql module

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

#Start the migration

Log-Finish -LogPath $sLogFile -NoExit $True