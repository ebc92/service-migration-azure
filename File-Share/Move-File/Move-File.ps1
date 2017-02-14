<#TODO: Clean up script, change paths to proper variables
        Use proper Begin, Process, End structure
        Figure out how to avoid double input of the Path verifying function
        Use values from support module when it is made available.        
#>

Function Move-File {
Param(
    [parameter(Mandatory=$true)]$SourcePath,
    [parameter(Mandatory=$true)]$DestPath,
    [parameter(Mandatory=$true)]$Credential,
    $RobCopyArgs,
    $MoveLog,
    $LogPath,
    $Date,
    $MoveFile
    )
    Begin {
    Invoke-Command -ComputerName $using:computer -Credential $using:credential -ScriptBlock {
    Function
    Install-WindowsFeature -Name "FileAndStorage-Services" -IncludeAllSubFeature -IncludeManagementTools -Restart
    }
    
    }
    Process {
    #Do until loop that checks if the Path is a container, and valid
    do { 
        $SourcePath = Read-Host('Please input the source path for your network share, ie \\fileshare')
        #Need an if statement, because Test-Path breaks on empty string, so this fills a non valid dummy string to negate this.
        If ([string]::IsNullOrEmpty($SourcePath)) {
            $SourcePath = "SomeString"
        } else {
            #DoNothing
        }
    } until (Test-Path($SourcePath) -PathType Container -ErrorAction Continue)

    Write-Verbose -Message "$SourcePath is valid, checking destination path next"

    do { 
        $DestPath = Read-Host('Please input the destination path for your network share, ie \\fileshare')
        If ([string]::IsNullOrEmpty($DestPath)) {
            $DestPath = "SomeString"
        } else {
            #DoNothing
        }
    } until (Test-Path($DestPath) -PathType Container)

    Write-Verbose -Message "Verification OK, moving files from $SourcePath to $DestPath"

    #Writes all info to a $RobCopyArgs, and starts robocopy. This also saves a logfile locally to C:\ServerMigrationLogs\File-Shares
    $MovLog = "RoboCopy-$Date.log"
    $LogPath = "C:\ServerMigrationLogs\File-Shares\$MovLog"
    $RobCopyArgs = "/MT /Z /E /COPYALL /R:60 /W:1 /V /TEE /log:$LogPath"
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MoveFile = "$SourcePath $DestPath $RobCopyArgs"

    Write-Verbose -Message "Running robocopy with the following args: $MoveFile"

    Start-Process robocopy -args "$MoveFile"
    }
}