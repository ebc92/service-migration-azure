#Getting migration variables from configuration file
$SMARoot = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")
. Join-Path -Path $SMARoot -ChildPath "Libraries\Manage-Configuration.ps1"
$SMAConfig = Get-IniContent -FilePath (Join-Path -Path $SMARoot -ChildPath "Configuration.ini")
$Source = $SMAConfig.MSSQL.source
$Destination = $SMAConfig.MSSQL.destination
$InstanceName = $SMAConfig.MSSQL.instance
$PackagePath = Join-Path -Path $SMAConfig.Global.fileshare -ChildPath $SMAConfig.MSSQL.packagepath

Try{
    Write-Output "Testing connection to $($Destination)..."
    $ConnectionTest = Test-SqlConnection -SqlServer "$($Destination)\$($InstanceName),1433" -SqlCredential ($SqlCredential = Get-Credential)
    If (!$ConnectionTest.ConnectSuccess){
        Write-Output "Could not establish connection to the destination server."
    } else {
        Write-Output "Connection test was successfull, starting SQL migration!"
        Start-SqlMigration -Source "$($Source)\$($InstanceName),1433" -Destination "$($Destination)\$($InstanceName),1433" -SourceSqlCredential $SqlCredential -DestinationSqlCredential $SqlCredential -NetworkShare $PackagePath -BackupRestore     
    }
} Catch {
    Write-Output  $_.Exception -ExitGracefully
}