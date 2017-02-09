<#TODO: Clean up script, change paths to proper variables
        Use proper Begin, Process, End structure
        Figure out how to avoid double input of the Path verifying function
        Use values from support module when it is made available.        
#>
$script:SourcePath
$script:DestPath

Function Move-Files {
Param(
    $RobCopyArgs,
    $MoveLog,
    $ScriptPath,
    $LogPath,
    $Date,
    $MoveFiles
    )
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MovLog = "RoboCopy-$Date.log"
    $ScriptPath = "C:\ServerMigrationLogs\File-Shares"
    $LogPath = "$ScriptPath\$MovLog"
    $script:SourcePath = 'D:\Battle.net' #Read-Host('Please input the source path for your network share, ie //fileshares')
    $script:DestPath = 'D:\RoboCopy\Dest'
    $RobCopyArgs = "/MT /E /COPYALL /R:1 /W:1 /V /TEE /log:$LogPath"
    do { 
    Verify-FolderSource($script:SourcePath)
    } until (Verify-FolderSource($true))
    
    do { 
    Verify-FolderDest($script:DestPath)
    } until (Verify-FolderDest($true))
    $MoveFiles = "$script:SourcePath $script:DestPath $RobCopyArgs"
    Start robocopy -args "$MoveFiles"
    }

Function Verify-FolderSource($verifyPath) {
    if( $(Try { Test-Path $script:SourcePath.trim() } Catch { $false }) ) 
        {
            Write-Host "Source Path is Valid, testing destination next"
            Return $true
        } 
        Else {
            $script:SourcePath = Read-Host('Please enter a valid source')
            Return
        }
}

Function Verify-FolderDest($verifyPath) {
    if( $(Try { Test-Path $script:DestPath.trim() } Catch { $false }) ) 
        {
            Write-Host "Destination Path is Valid, starting file transfer"
            Return $true
        } 
        Else {
            $script:DestPath = Read-Host('Please enter a valid destination')
            Return
        }
}