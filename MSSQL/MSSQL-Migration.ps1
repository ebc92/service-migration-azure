#Getting migration variables from configuration file
$Source = $SMAConfig.MSSQL.source
$Destination = $SMAConfig.MSSQL.destination
$Instance = $SMAConfig.MSSQL.instance
$ComputerName = $SMAConfig.MSSQL.hostname
$PackagePath = Join-Path -Path $SMAConfig.Global.fileshare -ChildPath $SMAConfig.MSSQL.packagepath

$sLogPath = $SMAConfig.Global.logpath
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$sLogName = "SMA-MSSQL-$($xLogDate).log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#Todo: retrieve creds & concatenate source to trustedhost
$Credential = $DomainCredential
$SqlCredential

#Install SMA
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
Invoke-Command -ComputerName $Source -FilePath (Join-Path $SMARoot -ChildPath ".\Support\Install-SMModule.ps1") -Credential $Credential

$ScriptBlock = {
    $sLogFile = $using:sLogFile
    $SMARoot = "C:\service-migration-azure"


    #Dot source libraries
    $functions = @("Libraries\Log-Functions.ps1", "\Libraries\Manage-Configuration.ps1")
    $functions | % {
    Try {
        $path = Join-Path -Path $SMARoot -ChildPath $_
        . $path -ErrorAction Stop
        $m = "Successfully sourced $($_)"
        Log-Write -LogPath $sLogFile -LineValue $m
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception
    }
}
    Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion "1.0"
    Import-Module (Join-Path -Path $SMARoot -ChildPath "MSSQL\MSSQL-Migration.psm1") -Force
    Start-MSSQLInstallConfig -PackagePath $using:PackagePath -Credential $using:DomainCredential
}

Invoke-Command -ComputerName $Source -ScriptBlock $ScriptBlock -Credential $DomainCredential

<#

$cd = @{
    AllNodes = @(
        @{
            NodeName = $Destination
            Role = "SqlServer"
            PSDscAllowPlainTextPassword = $true
        }
    );
}

Try {
    Log-Write -LogPath $sLogFile -LineValue "Generating MOF-file from DSC script."
    DesiredStateSQL -ConfigurationData $cd -PackagePath $PackagePath -DomainCredential $DomainCredential
    # ^add aDomainName, interfacealias, DNS
    Log-Write -LogPath $sLogFile -LineValue "Starting DSC configuration."
    Start-DscConfiguration -ComputerName $Destination -Path .\DesiredStateSQL -Verbose -Wait -Force -Credential $Credential -ErrorAction Stop
    Log-Write -LogPath $sLogFile -LineValue "DSC configuration was succcessfully pushed."

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when pushing the DSC configuration."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}




Try {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 

    Start-MSSQLMigration -Source $Source -Destination $Destination -InstanceName $Instance -Credential $Credential -SqlCredential $SqlCredential -Share $PackagePath

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when pushing the DSC configuration."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}

#>
