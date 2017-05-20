# Dot source the manage-configuration script and import the configuration file to session scope.
$SMARoot = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
. Join-Path -Path $SMARoot -ChildPath "Libraries\Manage-Configuration.ps1"
$SMAConfig = Get-IniContent -FilePath (Join-Path -Path $SMARoot -ChildPath "Configuration.ini")

# Get migration variables from configuration file
$Source = $SMAConfig.MSSQL.source
$Destination = $SMAConfig.MSSQL.destination
$InstanceName = $SMAConfig.MSSQL.instance
$PackagePath = Join-Path -Path $SMAConfig.Global.fileshare -ChildPath $SMAConfig.MSSQL.packagepath

Try{
    # Test the connection to the specified destination SQL host.
    Write-Output "Testing connection to $($Destination)..."
    $ConnectionTest = Test-SqlConnection -SqlServer "$($Destination)\$($InstanceName),1433" -SqlCredential ($SqlCredential = Get-Credential)
    If (!$ConnectionTest.ConnectSuccess){
        Write-Output "Could not establish connection to the destination server."
    } else {
        # If the connection test was successfull, start the migration using the BackupRestore method.
        Write-Output "Connection test was successfull, starting SQL migration!"
        Start-SqlMigration -Source "$($Source)\$($InstanceName),1433" -Destination "$($Destination)\$($InstanceName),1433" -SourceSqlCredential $SqlCredential -DestinationSqlCredential $SqlCredential -NetworkShare $PackagePath -BackupRestore     
    }
} Catch {
    Write-Output  $_.Exception -ExitGracefully
}