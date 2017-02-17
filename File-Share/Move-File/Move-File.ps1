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

    Deploy-FileShare -TarComputer $TarComputer -SourceComputer $SourceComputer -credential $Credential

    Restart-Computer -ComputerName $TarComputer -Credential $Credential -Force -Wait

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

    $DestPath = Read-Host('Please input the destination path for your network share, ie \\fileshare')

    Write-Verbose -Message "Verification OK, moving files from $SourcePath to $DestPath"

    #Writes all info to a $RobCopyArgs, and starts robocopy. This also saves a logfile locally to C:\ServerMigrationLogs\File-Shares
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MovLog = "RoboCopy-$Date.log"
    $LogPath = "C:\ServerMigrationLog\File-Share\$MovLog"
    $RobCopyArgs = "/MT /Z /E /COPYALL /R:60 /W:1 /V /TEE /log:$LogPath"
    $MoveFile = "$SourcePath $DestPath $RobCopyArgs"

    Write-Verbose -Message "Running robocopy with the following args: $MoveFile"

    Start-Process robocopy -args "$MoveFile"
    
    do {
        Start-Sleep -Seconds 30
        End-RoboCopy -LogPath $LogPath
    } until (End-RoboCopy -LogPath $LogPath = True)

    Write-Output("Files moved successfully")       
            
    Get-RegValue -SourceComputer $SourceComputer -TarComputer $TarComputer -Credential $Credential -RegPath Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\
    
    Restart-Computer -ComputerName $TarComputer -Credential $Credential -Force -Wait
    }     
}

Workflow Deploy-FileShare {
    Param(
    [parameter(Mandatory)]$TarComputer,
    [parameter(Mandatory)]$SourceComputer,
    [parameter(Mandatory)]$Credential
    )
    InlineScript {
        Install-WindowsFeature -ComputerName $using:TarComputer -Credential $using:Credential -Name "FileAndStorage-Services" -IncludeAllSubFeature -IncludeManagementTools
        }
    }

Function End-RoboCopy {
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

Function Get-RegValue {
    Param(
        [parameter(Mandatory=$true)]$SourceComputer,
        [parameter(Mandatory=$true)]$TarComputer,
        [parameter(Mandatory=$true)]$Credential,
        [parameter(Mandatory=$true)]$RegPath,
        $regvalue
        )
    Process {
        $RegName = (Invoke-Command -ComputerName $SourceComp -Credential $Credential -ScriptBlock { 
            Get-Item -path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ | Select-Object -ExpandProperty Property
            } )

    foreach($element in $RegName) {
        $RegValue = Invoke-Command -ComputerName $SourCecomp -Credential $Credential -ScriptBlock {
                (Get-ItemProperty -Path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\).$using:element
                }
        Invoke-Command -ComputerName $TarComp -Credential $Credential -ScriptBlock {
            if(Get-ItemProperty -name $using:element -Path $using:RegPath -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $using:RegPath -Name $using:element -Value $using:RegValue
                } else {
                    New-ItemProperty -Path $using:RegPath -Name $using:element -PropertyType MultiString -Value $using:RegValue
                }
            }
        }
    }
}