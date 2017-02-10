<#TODO: Clean up script, change paths to proper variables
        Use proper Begin, Process, End structure
        Figure out how to avoid double input of the Path verifying function
        Use values from support module when it is made available.        
#>

Function Move-File {
Param(
    $SourcePath,
    $DestPath,
    $RobCopyArgs,
    $MoveLog,
    $LogPath,
    $Date,
    $MoveFile
    )

    do { 
        $SourcePath = Read-Host('Please input the source path for your network share, ie //fileshares')
        If ([string]::IsNullOrEmpty($SourcePath)) {
            Write-Host $SourcePath
            $SourcePath = "adsadas"
        } else {
            #DoNothing
        }
    } until (Test-Path($SourcePath) -PathType Container -ErrorAction Continue)

    Write-Verbose -Message "$SourcePath is valid, checking destination path next"

    do { 
        $DestPath = Read-Host('Please input the destination path for your network share, ie //fileshares')
        If ([string]::IsNullOrEmpty($DestPath)) {
            $DestPath = "adsadas"
        } else {
            #DoNothing
        }
    } until (Test-Path($DestPath) -PathType Container)

    Write-Verbose -Message "Verification OK, moving files from $SourcePath to $DestPath"
        
    $MovLog = "RoboCopy-$Date.log"
    $LogPath = "C:\ServerMigrationLogs\File-Shares\$MovLog"
    $RobCopyArgs = "/MT /E /COPYALL /R:1 /W:1 /V /TEE /log:$LogPath"
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MoveFile = "$SourcePath $DestPath $RobCopyArgs"

    Write-Verbose -Message "Running robocopy with the following args: $MoveFile"
    Start-Process robocopy -args "$MoveFile"
}