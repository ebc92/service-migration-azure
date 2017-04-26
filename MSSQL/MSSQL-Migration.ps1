#Getting migration variables from configuration file
$AzureStack = $SMAConfig.Global.Get_Item('azurestack')
$Source = $SMAConfig.MSSQL.Get_Item('source')
$Destination =   $SMAConfig.MSSQL.Get_Item('destination')
$Instance = $SMAConfig.MSSQL.Get_Item('instance')
$PackagePath = Join-Path -Path $SMAConfig.Global.Get_Item('fileshare') -ChildPath $SMAConfig.MSSQL.Get_Item('packagepath')

$LogPath = $SMAConfig.Global.Get_Item('logpath')

#Todo: retrieve creds & concatenate source to trustedhost
$Credential = $DomainCredential
$SqlCredential

#Install SMA
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
Invoke-Command -ComputerName $Source -FilePath (Join-Path $SMARoot -ChildPath ".\Support\Install-SMModule.ps1") -Credential $Credential

$ScriptBlock = {
    $sLogFile = $using:LogPath
    $SMARoot = "C:\service-migration-azure"


    #Dot source libraries
    $functions = @("Libraries\Log-Functions.ps1", "\Libraries\Manage-Configuration.ps1")
    $functions | % {
    Try {
        $path = Join-Path -Path $PSScriptRoot -ChildPath $_
        . $path -ErrorAction Stop
        $m = "Successfully sourced $($_)"
        Log-Write -LogPath $sLogFile -LineValue $m
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception
    }
}

    Import-Module (Join-Path -Path $SMARoot -ChildPath "MSSQL\MSSQL-Migration.psm1") -Force
    Start-MSSQLInstallConfig -PackagePath $using:PackagePath -Credential $using:Credential
}

Invoke-Command -ComputerName $Source -ScriptBlock $ScriptBlock -Credential $Credential

#

#Start-MSSQLDeployment -ComputerName $ComputerName -PackagePath $PackagePath -InstanceName $InstanceName -Credential $Credential

#Log-Write -LogPath $sLogFile -LineValue "SQL Server 2016 was successfully deployed on $ComputerName."

#Log-Write -LogPath $sLogFile -LineValue "Starting SQL Instance migration from $Source\$InstanceName to $ComputerName\$InstanceName."

#Start-MSSQLMigration -Source $Source -Destination $ComputerName -InstanceName $InstanceName -Share $PackagePath -SqlCredential $SqlCredential -Credentials $Credential