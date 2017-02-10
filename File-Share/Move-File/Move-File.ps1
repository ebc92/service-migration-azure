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
    $MoveFiles
    )
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MovLog = "RoboCopy-$Date.log"
    $LogPath = "C:\ServerMigrationLogs\File-Shares\$MovLog"
    $RobCopyArgs = "/MT /E /COPYALL /R:1 /W:1 /V /TEE /log:$LogPath"

    do { 
    $SourcePath = Read-Host('Please input the source path for your network share, ie //fileshares')
        If ($SourcePath.ToString::IsNullOrEmpty) {
        Write-Host $SourcePath
        $SourcePath = "adsadas"
        Write-Host $SourcePath
        } else {
        #DoNothing
        }
    } until (Test-Path($SourcePath) -PathType Container -ErrorAction Continue)

    Write-Verbose -Message "$SourcePath is valid, checking destination path next"

    do { 
    $DestPath = Read-Host('Please input the destination path for your network share, ie //fileshares')
    If ($DestPath::IsNullOrEmpty) {
        $DestPath = "adsadas"
        Write-Host $DestPath
        } else {
        #DoNothing
        }
    } until (Test-Path($DestPath) -PathType Container)
    Write-Verbose -InformationAction Continue "Verification OK, moving files from $SourcePath to $DestPath"

    $MoveFiles = "$SourcePath $DestPath $RobCopyArgs"
    Start-Process robocopy -args "$MoveFiles"
}
<#
Function Verify-Path($VerifyPath) {
    If (Test-Path($VerifyPath) -PathType Container)  {
            Return $VerifyPath
            } Else {
            Write-Host "Scriptet stoppa ikkje wtf script"
            Return $VerifyPath
            }    
}#>