#Requires -version 4.0
######################################################
#########################\O/##########################
##   ______          _                              ##
##  |  ____|        | |                             ##
##  | |__  __  _____| |__   __ _ _ __   __ _  ___   ##
##  |  __| \ \/ / __| '_ \ / _` | '_ \ / _` |/ _ \  ##
##  | |____ >  < (__| | | | (_| | | | | (_| |  __/  ##
##  |______/_/\_\___|_| |_|\__,_|_| |_|\__, |\___|  ##
##                                      __/ |       ##
##                                     |___/        ##
######################################################
######################################################

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
$ErrorActionPreference = 'Continue'

#Dot Source required Function Libraries
$DotPath = Resolve-Path "$PSScriptRoot\..\Libraries\Log-Functions.ps1"
. $DotPath

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
    [string]$fileShare,
    [parameter(Mandatory=$true)]
    [string]$ComputerName,
    [parameter(Mandatory=$true)]
    [PSCredential]$DomainCredential
  )
  
  Begin{
    if(!($verifyLogPath)) {
      New-Item -ItemType Directory -Path $sLogPath > $null
    }
    $variableOutput = '        $fileShare ' + "= $fileShare `n"`
    +'        $tarComp ' + "= $ComputerName `n"`
    +'        $DomainCredential ' + "= $DomainCredential"
    #Log-Write -LogPath $sLogFile -LineValue "Downloading prerequisites for Microsoft Exchange 2016..."
    #Log-Write -LogPath $sLogFile -LineValue "The following variables are set for $MyInvocation.MyCommand.Name:"
    #Log-Write -LogPath $sLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      #Checking package provider list for NuGet
      $nuSession = New-PSSession -ComputerName $ComputerName -Credential $DomainCredential
      $nuget = Invoke-Command -Session $nuSession -ScriptBlock { 
        $nuget = Get-PackageProvider | Where-Object -Property Name -eq nuget
        Return $nuget 
      }
      Remove-PSSession -Name $nuSession
     
      #Creating the required folders if they do not exist 
      if (!($verifyPath)) {
        New-Item -ItemType Directory -Path "$fileshare" > $null
        Write-Verbose -Message "Path not found, created required path on $fileshare" 
        #Log-Write -LogPath $sLogFile -LineValue "Path not found, created required path on $fileshare"
      } else {
        Write-Verbose -Message "Path found on $fileshare"
        #Log-Write -LogPath $sLogFile -LineValue "Path found on $fileShare"
      }
      
      #Checking if NuGet is in the package provider list, and installing it if it's not
      if (!($nuget)) {
        Write-Verbose -Message "NuGet not installed, installing now..."
        #Log-Write -LogPath $sLogFile -LineValue "Nuget not installed, installing now..."
        Install-PackageProvider -Name NuGet -Force
      } else {
        Write-Verbose -Message "NuGet already installed, continuing prerequisite checks"
        #Log-Write -LogPath $sLogFile -LineValue "NuGet already installed, continuing prerequisite checks"
      }  
          
      #Downloading UCMA 4.0 Runtime      
      Write-Verbose -Message "Starting download of UCMA Runtime 4.0"
      #Log-Write -LogPath $sLogFile -LineValue "Starting download of UCMA Runtime 4.0"

      Start-BitsTransfer -Source https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe -Destination $fileshare -Description 'Downloading prerequisites'
      Write-Verbose -Message "Downloading file from https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe to $fileShare"
      #Log-Write -LogPath $sLogFile -LineValue "Downloading file from https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe to $fileShare"

      #Downloading Exchange 2016
      #Write-Verbose -Message "Starting download of Exchange 2016 CU5"
      #Log-Write -LogPath $sLogFile -LineValue "Starting download of Exchange 2016 CU5"
      Start-BitsTransfer -Source https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso -Destination $fileshare -Description 'Downloading prerequisites'
      Write-Verbose -Message "Downloading file from https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso to $fileShare"
      #Log-Write -LogPath $sLogFile -LineValue "Downloading file from https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso to $fileShare"

    }     
    Catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      #Log-Write -LogPath $sLogFile -LineValue "Got all prerequisites successfully."
      #Log-Write -LogPath $sLogFile -LineValue " "
      Write-Verbose -Message 'Got all prerequisites successfully.'
    }
  }
}

#Mounts Exchange 2016 image from share
Function Mount-Exchange {
  Param(
    [Parameter(Mandatory=$true)]
    [String]$SourceFile
  )
  [bool]$finished=$false
  $er = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  Do {
    Try {          
      $ExchangeBinary = (Mount-DiskImage -ImagePath $SourceFile\ExchangeServer2016-x64-cu5.iso `
      -PassThru | Get-Volume).Driveletter + ":"
      $finished = $true
      $ErrorActionPreference = $er
      Return $ExchangeBinary
    }
    Catch {
      $SourceFile = Read-Host(`
      "The path $SourceFile does not contain the ISO file, please enter the correct path for the Exchange 2016 ISO Image folder")
      $finished = $false
    }
  }
  While ($finished -eq $false)
}

Function Install-Prerequisite {
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$fileShare,
    [parameter(Mandatory=$true)]
    [string]$ComputerName,
    [parameter(Mandatory=$true)]
    [PSCredential]$DomainCredential,
    [parameter(Mandatory=$true)]
    [String]$ExchangeBinary
  )
  
  Begin{
    $variableOutput = '        $fileShare ' + "= $fileShare"
    #Log-Write -LogPath $sLogFile -LineValue 'Installing prerequisites for Microsoft Exchange 2013...'
    #Log-Write -LogPath $sLogFile -LineValue "The following variables are set for $MyInvocation.MyCommand.Name :"
    #Log-Write -LogPath $sLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      [int]$i = 0
      $InstallFiles = Get-ChildItem -Path $fileShare
      $total = $InstallFiles.Count
      $Domain = $env:USERDOMAIN
      
      Write-Verbose -Message "Total amount of files to be installed is $total, starting installation"
      #Log-Write -LogPath $sLogPath -LineValue "Total amount of files to be installed is $total, starting installation"

      Install-Module -Name xExchange, xPendingReboot, xWindowsUpdate
      
      <#     Foreach($element in $InstallFiles) {
          $i++
          Write-Progress -Activity 'Installing prerequisites for Exchange 2016' -Status "Currently installing file $i of $total"`
          -PercentComplete (($i / $total) * 100)          Write-Verbose -Message "Installing file $i of $total"          Write-Verbose -Message "Installing $element.name"          Log-Write -LogPath $sLogPath -LineValue "Installing file $i of $total"          Log-Write -LogPath $sLogPath -LineValue "Installing $element.name"          Invoke-Command -ComputerName $tarComp -Credential $DomainCredential -ScriptBlock {
          Start-Process -FilePath $element.FullName -ArgumentList '/passive /norestart' -Wait
          }
      }#>
    }
       
    Catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      #Log-Write -LogPath $sLogFile -LineValue "Installed prerequisites successfully."
      #Log-Write -LogPath $sLogFile -LineValue ""
      Write-Verbose -Message "Installed prerequisites successfully."
    }
  }
}
<#Function Migrate-Transport {
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
} #>

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
$i = 0

#Temporary to run commands during test environment
$cred = Get-Credential

Get-Prerequisite -fileShare $fileshare -ComputerName 192.168.58.116 -DomainCredential $cred

Mount-Exchange -SourceFile $fileshare

Install-Prerequisite -fileShare $fileshare -ComputerName 192.168.58.116 -DomainCredential $cred -ExchangeBinary $ExchangeBinary

#Log-Finish -LogPath $sLogFile