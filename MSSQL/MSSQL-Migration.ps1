if(!$SqlCredential){
    Write-Output "No SQL credentials in scope, aborting!"
    break
}

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

#*DomainCredential
#*SqlCredential



<#Install SMA
Log-Write -LogPath $sLogFile -LineValue "Installing service-migratio-azure on SQL source host..."
Try {
    Write-Output $PSScriptRoot
    $SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
    Write-Output $SMARoot
    $SQLSession = New-PSSession -ComputerName $Source -Credential $DomainCredential
    Invoke-Command -Session $SQLSession -ScriptBlock {param($SMAConfig)$global:SMAConfig} -ArgumentList $SMAConfig
    Invoke-Command -Session $SQLSession -FilePath (Join-Path $SMARoot -ChildPath "\Support\Install-SMModule.ps1") -ErrorAction Stop
} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when trying to install service-migration-azure on source host."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}
Log-Write -LogPath $sLogFile -LineValue "SMA was installed."

<# Retrieve configuration file from source SQL server
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
    Log-Write -LogPath $sLogFile -LineValue "Starting DSC configuration."
    Start-DscConfiguration -ComputerName $Destination -Path .\DesiredStateSQL -Verbose -Wait -Force -Credential $Credential -ErrorAction Stop
    Log-Write -LogPath $sLogFile -LineValue "DSC configuration was succcessfully pushed."

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when pushing the DSC configuration."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}


$ScriptBlock = {
    Param(
    $Source,
    $Destination,
    $Instance,
    $SqlCredential,
    $PackagePath
    )
    
    $sLogPath = $using:sLogPath
    $sLogName = "SMA-MSSQL-$($using:xLogDate).log"
    $sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

    $Source = $using:Source
    $Destination = $using:Destination
    $Instance = $using:Instance
    $SqlCredential = $using:SqlCredential
    $PackagePath = $using:PackagePath

    Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion "1.0"

    Try {
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 

        Start-MSSQLMigration -Source $Source -Destination $Destination -InstanceName $Instance -Credential $SqlCredential -SqlCredential $SqlCredential -Share $PackagePath -ErrorAction Stop

    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "An error occured when trying to start the SQL migration."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
}



Try {
    Log-Write -LogPath $sLogFile -LineValue "Starting the SQL Server migration..."
    Invoke-Command -Session $SQLSession -ScriptBlock $ScriptBlock
} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when trying to run the migration."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}
#>

    Log-Write -LogPath $sLogFile -LineValue "Installing DBATools for SQL Server migration."
    Try {
        $DbaTools = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\Libraries\Install-DBATools.ps1")
        & $DbaTools

    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -Logpath $sLogFile -LineValue "dbatools installation failed.."
    }

Start-MSSQLMigration -Source $Source -Destination $Destination -InstanceName $Instance -Credential $SqlCredential -SqlCredential $SqlCredential -Share $PackagePath -ErrorAction Stop