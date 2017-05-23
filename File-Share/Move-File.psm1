Function Move-File {
  Param(
    [parameter(Mandatory=$true)]
    [string]$SourceComputer,
    [parameter(Mandatory=$true)]
    [string]$ComputerName,
    [parameter(Mandatory=$true)]
    [pscredential]$DomainCredential,
    [parameter]
    [string]$SourcePath,
    [parameter]
    [string]$DestPath
    )

  Process {
    #Runs the Deploy-Share function to install the required server role
    Deploy-FileShare -TarComputer $ComputerName -SourceComputer $SourceComputer -DomainCredential $DomainCredential

    #Restarts the computer to ensure there are no pending restarts
    Restart-Computer -ComputerName $ComputerName -Credential $DomainCredential -Force -Wait

    #Writes all info to a $RobCopyArgs, and starts robocopy. This also saves a logfile locally to C:\Logs\FSS
    $Date = (Get-Date -Format ddMMMyyyy_HHmm).ToString()
    $MovLog = "RoboCopy-$Date.log"
    $LogPath = "C:\Logs\FSS\$MovLog"
    $RobCopyArgs = "/MT /Z /E /COPYALL /R:60 /W:1 /V /TEE /log:$LogPath"
    $MoveFile = "$SourcePath $DestPath $RobCopyArgs"

    Write-Verbose -Message "Running robocopy with the following args: $MoveFile"
    #Starts RoboCopy with the specified arguments
    Start-Process robocopy -args "$MoveFile"
    
    #Runs a do .. until loop that reads the tail end of the log for the "Ended" message from RoboCopy
    do {
        Start-Sleep -Seconds 30
        End-RoboCopy -LogPath $LogPath
    } until (End-RoboCopy -LogPath $LogPath = True)

    Write-Output("Files moved successfully")       
    
    #Gets the register value from the source computer, and updates the target computer registry so the share is active
    Get-RegValue -SourceComputer $SourceComputer -ComputerName $ComputerName -DomainCredential $DomainCredential -RegPath Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\
    
    #Restarts the target computer so it updates to the new registry values
    Restart-Computer -ComputerName $ComputerName -Credential $DomainCredential -Force -Wait
    }     
}

Workflow Deploy-FileShare {
    Param(
    [parameter(Mandatory)]$TarComputer,
    [parameter(Mandatory)]$SourceComputer,
    [parameter(Mandatory)]$DomainCredential
    )
    InlineScript {
        #Installs the required Windows Feature
        Install-WindowsFeature -ComputerName $using:TarComputer -Credential $using:DomainCredential -Name "FileAndStorage-Services" -IncludeAllSubFeature -IncludeManagementTools
        }
    }

Function End-RoboCopy {
    Param(
        [string]$LogPath
    )

    Process {
        #Scans the RoboCopy logfile for the "Ended" message.
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
        [parameter(Mandatory=$true)]$ComputerName,
        [parameter(Mandatory=$true)]$DomainCredential,
        [parameter(Mandatory=$true)]$RegPath,
        $regvalue
        )
    Process {
        #Gets the register entries from the source computer, and saves it to a $RegName variable
        $RegName = (Invoke-Command -ComputerName $SourceComputer -Credential $DomainCredential -ScriptBlock { 
            Get-Item -path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ | Select-Object -ExpandProperty Property
            } )
            
    #Runs a foreach loop on all the entries in the RegName variable so that it can support multiple shares
    foreach($element in $RegName) {
        #Gets the register value from the Source Computer
        $RegValue = Invoke-Command -ComputerName $SourceComputer -Credential $DomainCredential -ScriptBlock {
                (Get-ItemProperty -Path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\).$using:element
                }
                
        #Updates the registry value on the target computer so it matches the shares from the Source Computer        
        Invoke-Command -ComputerName $ComputerName -Credential $DomainCredential -ScriptBlock {
            if(Get-ItemProperty -name $using:element -Path $using:RegPath -ErrorAction SilentlyContinue) {
                    Set-ItemProperty -Path $using:RegPath -Name $using:element -Value $using:RegValue
                } else {
                    New-ItemProperty -Path $using:RegPath -Name $using:element -PropertyType MultiString -Value $using:RegValue
                }
            }
        }
    }
}