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
$fileshare = 'c:\tempExchange'

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogPath = '$'
$sLogName = 'Migrate-Exchange.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function Get-PreRequisites{
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$fileshare
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue 'Downloading prerequisites for Microsoft Exchange 2013...'
  }
  
  Process{
    Try{
      $verifyPath = Test-Path -Path $fileshare
      [int]$i = 0
      $downloadString = @'
https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe
https://download.microsoft.com/download/0/A/2/0A28BBFA-CBFA-4C03-A739-30CCA5E21659/FilterPack64bit.exe
https://download.microsoft.com/download/A/A/3/AA345161-18B8-45AE-8DC8-DA6387264CB9/filterpack2010sp1-kb2460041-x64-fullfile-en-us.exe
'@
      $downloadArray = $downloadString.Split("`n",[StringSplitOptions]::RemoveEmptyEntries)
      if (!($verifyPath)) {
        New-Item -ItemType Directory -Path "$fileshare"
        Write-Verbose -Message "Path not found, created required path on $fileshare"
      } else {
        Write-Verbose -Message "Path found, downloading prerequisites to $fileshare"
      }
      
      foreach($element in $downloadArray) {
        $i++
        "$element Checking next $i"
        Write-Progress -Activity 'Downloading prerequsites for Exchange 2013' -Status "Currently downloading file $element of $downloadArray.count"`
        -PercentComplete (($i / $downloadArray.Count) * 100)
        "$element $fileshare"
        Start-BitsTransfer -Source $element -Destination $fileshare -Description 'Downloading prerequisites'
        Write-Verbose -Message "Downloading file from $element"
      }
    }      
    Catch{
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
Script Execution goes here
Log-Finish -LogPath $sLogFile