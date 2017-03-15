#requires -version 2
<#
    .SYNOPSIS
    <Overview of script>

    .DESCRIPTION
    <Brief description of script>

    .PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

    .INPUTS
    <Inputs if any, otherwise state None>

    .OUTPUTS
    <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

    .NOTES
    Version:        1.0
    Author:         Nikolai Thingnes Leira & Emil Claussen
    Creation Date:  24.02.2017
    Purpose/Change: Set structure of script
  
    .EXAMPLE
    <Example goes here. Repeat this attribute for more than one example>
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#Dot Source required Function Libraries
. 'C:\Scripts\Functions\Logging_Functions.ps1'

#Define all variables during testing, remove for production
$baseDir = 'C:\tempExchange'
$fileshare = "$baseDir\executables"
$verifyPath = Test-Path -Path $fileshare

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'
#Log File Info
$logDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString() 
$sLogPath = "$baseDir\log\"
$sLogName = "Migrate-Exchange-$logDate.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
$verifyLogPath = Test-Path -Path $sLogPath

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function Get-Prerequisite {
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$fileShare
  )
  
  Begin{
    if(!($verifyLogPath)) {
      New-Item -ItemType Directory -Path $sLogPath > $null
    }
    $variableOutput = '        $fileShare ' + "= $fileShare"
    Log-Write -LogPath $sLogFile -LineValue "Downloading prerequisites for Microsoft Exchange 2013..."
    Log-Write -LogPath $sLogFile -LineValue "The following variables are set for Get-Prerequisite:"
    Log-Write -LogPath $sLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      [int]$i = 0
      $downloadArray = @(
        "https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe"
        "https://download.microsoft.com/download/0/A/2/0A28BBFA-CBFA-4C03-A739-30CCA5E21659/FilterPack64bit.exe"
        "https://download.microsoft.com/download/A/A/3/AA345161-18B8-45AE-8DC8-DA6387264CB9/filterpack2010sp1-kb2460041-x64-fullfile-en-us.exe"
      )
      
      $total = $downloadArray.Count
      
      if (!($verifyPath)) {
        New-Item -ItemType Directory -Path "$fileshare" > $null
        Write-Verbose -Message "Path not found, created required path on $fileshare" 
        Log-Write -LogPath $sLogFile -LineValue "Path not found, created required path on $fileshare"
      } else {
        Write-Verbose -Message "Path found on $fileshare"
        Log-Write -LogPath $sLogFile -LineValue "Path found on $fileShare"
      }
      
      Write-Verbose -Message "Total amount of files to be donwloaded is $total, proceeding to download"
      Log-Write -LogPath $sLogFile -LineValue "Total amount of files to be donwloaded is $total, proceeding to download"
      
      foreach($element in $downloadArray) {
        $i++
        Write-Verbose -Message "Currently downloading file $i of $total"
        Log-Write -LogPath $sLogFile -LineValue "Currently downloading file $i of $total"
        Write-Progress -Activity 'Downloading prerequsites for Exchange 2013' -Status "Currently downloading file $i of $total"`
        -PercentComplete (($i / $total) * 100)
        Start-BitsTransfer -Source $element -Destination $fileshare -Description 'Downloading prerequisites'
        Write-Verbose -Message "Downloading file from $element to $fileShare"
        Log-Write -LogPath $sLogFile -LineValue "Downloading file from $element to $fileShare"
      }
    }      
    Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Got all prerequisites successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
      Write-Verbose -Message 'Got all prerequisites successfully.'
    }
  }
}

Function Install-Prerequisite {
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$fileShare
  )
  
  Begin{
    $variableOutput = '        $fileShare ' + "= $fileShare"
    Log-Write -LogPath $sLogFile -LineValue 'Installing prerequisites for Microsoft Exchange 2013...'
    Log-Write -LogPath $sLogFile -LineValue "The following variables are set for Install-Prerequisite:"
    Log-Write -LogPath $sLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      [int]$i = 0
      $InstallFiles = Get-ChildItem -Path $fileShare
      $total = $InstallFiles.Count
      
      Write-Verbose -Message "Total amount of files to be installed is $total, starting installation"
      Log-Write -LogPath $sLogPath -LineValue "Total amount of files to be installed is $total, starting installation"
      
      Foreach($element in $InstallFiles) {
        $i++
        Write-Progress -Activity 'Installing prerequisites for Exchange 2013' -Status "Currently installing file $i of $total"`
        -PercentComplete (($i / $total) * 100)        Write-Verbose -Message "Installing file $i of $total"        Write-Verbose -Message "Installing $element.name"        Log-Write -LogPath $sLogPath -LineValue "Installing file $i of $total"        Log-Write -LogPath $sLogPath -LineValue "Installing $element.name"        Start-Process -FilePath $element.FullName -ArgumentList '/passive /norestart' -Wait
      }
    }
       
    Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Installed prerequisites successfully."
      Log-Write -LogPath $sLogFile -LineValue ""
      Write-Verbose -Message "Installed prerequisites successfully."
    }
  }
}
Function Migrate-Transport {
  [CmdletBinding()]
  Param(
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue '<Write what happens>...'
  }
  
  Process{
    Try{
     
    }      
    Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

Get-Prerequisite -fileshare $fileshare
#Install-Prerequisite -fileShare $fileshare

Log-Finish -LogPath $sLogFile