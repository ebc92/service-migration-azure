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

# Install service-migration azure on the source
Log-Write -LogPath $sLogFile -LineValue "Installing service-migratio-azure on SQL source host..."
Try {
    $SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")

    $SQLSession = New-PSSession -ComputerName $Source -Credential $DomainCredential
    Invoke-Command -Session $SQLSession -ScriptBlock {param($SMAConfig)$global:SMAConfig} -ArgumentList $SMAConfig
    Invoke-Command -Session $SQLSession -FilePath (Join-Path $SMARoot -ChildPath "\Support\Install-SMModule.ps1") -ErrorAction Stop
    Log-Write -LogPath $sLogFile -LineValue "Service-migration-azure was successfully installed on SQL source host."

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when trying to install service-migration-azure on source host."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False

}

# Retrieve configuration file from SQL source host
$ScriptBlock = {
    $sLogFile = $using:sLogFile
    $SMARoot = "C:\service-migration-azure"

    # Dot source libraries
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

Invoke-Command -Session $SQLSession -ScriptBlock $ScriptBlock
Remove-PSSession $SQLSession

# Creating DSC configuration data
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

    Log-Write -LogPath $sLogFile -LineValue "Starting DSC configuration. Writing transcript to log."

    Start-Transcript -Path $sLogFile -Append
    Start-DscConfiguration -ComputerName $Destination -Path .\DesiredStateSQL -Verbose -Wait -Force -Credential $Credential -ErrorAction Stop
    Stop-Transcript

    Log-Write -LogPath $sLogFile -LineValue "DSC configuration was succcessfully pushed."

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when pushing the DSC configuration."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}

$SQLSession = New-PSSession -ComputerName $Destination -Credential $DomainCredential
$ConfigurationPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\Configuration.ini")
Copy-Item -ToSession $SQLSession -Path $ConfigurationPath -Destination "C:\service-migration-azure-develop" -Force
Remove-PSSession $SQLSession

$dialog = New-Object -ComObject Wscript.Shell
$dialog.Popup("LOG ON TO $($Source) AND RUN THE START-MSSQLMIGRATION SCRIPT MANUALLY.")

$dialog = New-Object -ComObject Wscript.Shell
$dialog.Popup("I hereby confirm and solemnly swear that the`nStart-SQLMigration.ps1 script has been successfully`nrun on $($Source) and that service-migration-azure`nmay proceed with the migration.")
