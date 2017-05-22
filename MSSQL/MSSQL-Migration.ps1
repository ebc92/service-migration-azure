# Verify that SQL Credentials have been defined in the Master script.
if(!$SqlCredential){
    Write-Output "No SQL credentials in scope, aborting!"
    break
}

# Get migration variables from configuration file
$Source = $SMAConfig.MSSQL.source
$Destination = $SMAConfig.MSSQL.destination
$Instance = $SMAConfig.MSSQL.instance
$ComputerName = $SMAConfig.MSSQL.hostname
$PackagePath = Join-Path -Path $SMAConfig.Global.fileshare -ChildPath $SMAConfig.MSSQL.packagepath


# Build a string with time and date to use as file name for log file.
$sLogPath = $SMAConfig.Global.logpath
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$sLogName = "SMA-MSSQL-$($xLogDate).log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

# Install service-migration azure on the source
Log-Write -LogPath $sLogFile -LineValue "Installing service-migratio-azure on SQL source host..."
Try {
    # Get the service-migration-azure package root
    $SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")

    # Create a persistent PSSession for reuse
    $SQLSession = New-PSSession -ComputerName $Source -Credential $DomainCredential

    # Pass the configuration file to the PSSession
    Invoke-Command -Session $SQLSession -ScriptBlock {param($SMAConfig)$global:SMAConfig} -ArgumentList $SMAConfig

    # Run the "Install-SMModule.ps1" script on the destination to install service-migration-azure to C:\.
    Invoke-Command -Session $SQLSession -FilePath (Join-Path $SMARoot -ChildPath "\Support\Install-SMModule.ps1") -ErrorAction Stop
    Log-Write -LogPath $sLogFile -LineValue "Service-migration-azure was successfully installed on SQL source host."

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when trying to install service-migration-azure on source host."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False

}

# Retrieve configuration file from SQL source host
$ScriptBlock = {
    $sLogPath = $using:sLogPath
    $sLogFile = $using:sLogFile
    $SMARoot = "C:\service-migration-azure-develop"
    $sLogName = $using:sLogName

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

# Pass the ScriptBlock to the SQL source host and remove the PSSession.
Invoke-Command -Session $SQLSession -ScriptBlock $ScriptBlock
Remove-PSSession $SQLSession

<# The DSC Local Configuration Manager must allow 
 handling plaintext credentials. This is specified in 
 the DSC configuration data defined here. #>
$cd = @{
    AllNodes = @(
        @{
            NodeName = $Destination
            Role = "SqlServer"
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    );
}

Try {
    Invoke-command -ComputerName $Destination -ScriptBlock {Install-Module xNetworking -Force} -Credential $DomainCredential
    # The AD DSC configuration is used to generate a DSC document.
    Log-Write -LogPath $sLogFile -LineValue "Generating MOF-file from DSC script."
    DesiredStateSQL -ConfigurationData $cd -PackagePath $PackagePath -DomainCredential $DomainCredential
    Log-Write -LogPath $sLogFile -LineValue "Starting DSC configuration. Writing transcript to log."

    <# DSC document is passed to the destination host and starts
    the deployment process. To achieve a high log level, the 
    verbose output of the DSC deployment is written to the service log file. #>
    $dscLogName = "SMA-MSSQL-$($xLogDate)-DSC.log"
    Start-Transcript -Path (Join-path -Path $sLogPath -ChildPath $dscLogName) -Append
    Start-DscConfiguration -ComputerName $Destination -Path .\DesiredStateSQL -Verbose -Wait -Force -Credential $DomainCredential -ErrorAction Stop
    Stop-Transcript

    Log-Write -LogPath $sLogFile -LineValue "DSC configuration was succcessfully pushed."

} Catch {
    Log-Write -LogPath $sLogFile -LineValue "An error occured when pushing the DSC configuration."
    Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
}

# Create a new PSSession to the destination SQL host.
$SQLSession = New-PSSession -ComputerName $Destination -Credential $DomainCredential

# Copy the SMA Configuration file to the destination SQL host and remove the session.
$ConfigurationPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\Configuration.ini")
Copy-Item -ToSession $SQLSession -Path $ConfigurationPath -Destination "C:\" -Force
Remove-PSSession $SQLSession

# Instruct the user to run the Start-MSSQLMigration script on the destination SQL host.
$dialog = New-Object -ComObject Wscript.Shell
$dialog.Popup("LOG ON TO $($Source) AND RUN THE START-MSSQLMIGRATION SCRIPT MANUALLY.")

$dialog = New-Object -ComObject Wscript.Shell
$dialog.Popup("I hereby confirm and solemnly swear that the`nStart-SQLMigration.ps1 script has been successfully`nrun on $($Source) and that service-migration-azure`nmay proceed with the migration.")