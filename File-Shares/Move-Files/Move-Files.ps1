<#TODO: Clean up script, change paths to proper variables
        Use proper Begin, Process, End structure
        Figure out how to avoid double input of the Path verifying function
        Use values from support module when it is made available.        
#>

$script:VerifyPath

Function Move-Files {
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
    $DestPath = 'D:\RoboCopy\Dest'
    $RobCopyArgs = "/MT /E /COPYALL /R:1 /W:1 /V /TEE /log:$LogPath"

    do { 
    $SourcePath = Read-Host('Please input the source path for your network share, ie //fileshares')
    Verify-Path($SourcePath)
    } until (Verify-Path($script:VerifyPath = $true))

    Write-Verbose -Message "$SourcePath is valid, checking destination path next"
    $script:VerifyPath = $false

    do { 
    $SourcePath = Read-Host('Please input the destination path for your network share, ie //fileshares')
    Verify-Path($DestPath)
    } until (Verify-Path($script:VerifyPath = $true))
    Write-Verbose -InformationAction Continue "Verification OK, moving files from $script:SourcePath to $DestPath"

    $MoveFiles = "$SourcePath $DestPath $RobCopyArgs"
    Start robocopy -args "$MoveFiles"
    }

Function Verify-Path($script:VerifyPath) {
    if( 
        $(Try { 
           $PathExists = Test-Path "$script:VerifyPath".trim() 
           } 
           Catch 
           { 
           $PathExists = $true
           }
           )) 
        {
            Return $script:VerifyPath = $true
        } 
        Else {
            Write-Warning -WarningAction Continue "Input validation failed, please enter the correct path"
            Return
        }
}