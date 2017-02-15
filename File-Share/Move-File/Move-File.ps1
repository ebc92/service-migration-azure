<#TODO: Clean up script, change paths to proper variables
        Use proper Begin, Process, End structure
        Figure out how to avoid double input of the Path verifying function
        Use values from support module when it is made available.        
#>

Function Move-File {
Param(
    [parameter(Mandatory=$true)]$SourceComputer,
    [parameter(Mandatory=$true)]$TarComputer,
    $username,
    $SourcePath,
    $DestPath,
    $Credential,
    $RobCopyArgs,
    $MoveLog,
    $LogPath,
    $Date,
    $MoveFile
    )

Process {
    $username = Read-Host("Username plx")    
    $pw = Read-Host("password plx") -AsSecureString
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$pw

    Deploy-FileShare -TarComputer $TarComputer -credential $Credential

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

   # do { 
        $DestPath = Read-Host('Please input the destination path for your network share, ie \\fileshare')
        <#If ([string]::IsNullOrEmpty($DestPath)) {
            $DestPath = "SomeString"
        } else {
            #DoNothing
        }
    } until (Test-Path($DestPath) -PathType Container) #>

    Write-Verbose -Message "Verification OK, moving files from $SourcePath to $DestPath"

    #Writes all info to a $RobCopyArgs, and starts robocopy. This also saves a logfile locally to C:\ServerMigrationLogs\File-Shares
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MovLog = "RoboCopy-$Date.log"
    $LogPath = "C:\ServerMigrationLog\File-Share\$MovLog"
    $RobCopyArgs = "/MT /Z /E /COPYALL /R:60 /W:1 /V /TEE /log:$LogPath"
    $MoveFile = "$SourcePath $DestPath $RobCopyArgs"

    Write-Verbose -Message "Running robocopy with the following args: $MoveFile"

    Start-Process robocopy -args "$MoveFile"
    #Invoke-Command -ComputerName $SourceComputer -Credential $credential -ScriptBlock {
    #    Start-Process robocopy -args "$using:MoveFile" }
    
    do {
        Start-Sleep -s 30
        RoboCopy-End -LogPath $LogPath
    } until (RoboCopy-End -LogPath $LogPath = True)

    Write-Output("Files moved successfully")       
    }      
}

Workflow Deploy-FileShare {
    Param(
    [parameter(Mandatory)]$TarComputer,
    [parameter(Mandatory)]$Credential
    )
    InlineScript {
        Install-WindowsFeature -ComputerName $using:TarComputer -Credential $using:Credential -Name "FileAndStorage-Services" -IncludeAllSubFeature -IncludeManagementTools
        Restart-Computer -PSComputerName $using:TarComputer -PSCredential $Credential -Force -Wait
        }
    }

Function RoboCopy-End {
    Param(
        [string]$LogPath
    )

    Process {
        $tailLog = Get-Content $LogPath -tail 2
        If ($tailLog -like '*Ended :*') {
        Return $true
        } else {
        Return
        }
    }
}