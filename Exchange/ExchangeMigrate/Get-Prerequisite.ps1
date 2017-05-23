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
    <#
      .SYNOPSIS
        Gets all required files for Exchange Server 2016, including the ISO for CU5
      .DESCRIPTION
        Downloads all the required files for a Excange 2016 install, to a targeted fileshare
      .PARAMETER fileShare
        The folder on the fileshare where the executables for the Exchange 2016 is to be downloaded.
      .PARAMETER ComputerName
        Name of the server you are targeting, do not use IP as it will break the script because of WinRM authentication. Name can be amstel-mail, or the FQDN amstel-mail.amstel.local
      .PARAMETER DomainCredential
        A credential object, for example created by running Get-Credential
      .EXAMPLE
        Get-Prerequisite -fileShare \\share\TempExchange\Executables -ComputerName amstel-exch -DomainCredential CredObject
  #>
  Begin{
    $variableOutput = '        $fileShare ' + "= $fileShare `n"`
    +'        $tarComp ' + "= $ComputerName `n"`
    +'        $DomainCredential ' + "= $DomainCredential"
    Log-Write -LogPath $xLogFile -LineValue "Downloading prerequisites for Microsoft Exchange 2016..."
    Log-Write -LogPath $xLogFile -LineValue "The following variables are set for $MyInvocation.MyCommand.Name:"
    Log-Write -LogPath $xLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      
      #Checking package provider list for NuGet
      $nuget = Invoke-Command -Session $InstallSession -ScriptBlock { 
        $nuget = Get-PackageProvider | Where-Object -Property Name -eq nuget
        Return $nuget 
      }
       
      #Checking if executables already exist
      $verifyPath = Test-Path -Path $fileshare
      $UCMAExist = Test-Path "$fileshare\UcmaRuntimeSetup.exe"
      $ExchangeExist = Test-Path -Path "$fileshare\ExchangeServer2016-x64-cu5.iso"      
     
      #Creating the required folders if they do not exist 
      if (!($verifyPath)) {
        New-Item -ItemType Directory -Path "$fileshare" > $null
        Write-Verbose -Message "Path not found, created required path on $fileshare" 
        Log-Write -LogPath $xLogFile -LineValue "Path not found, created required path on $fileshare"
      } else {
        Write-Verbose -Message "Path found on $fileshare"
        Log-Write -LogPath $xLogFile -LineValue "Path found on $fileShare"
      }
      
      #Checking if NuGet is in the package provider list, and installing it if it's not
      if (!($nuget)) {
        Write-Verbose -Message "NuGet not installed, installing now..."
        Log-Write -LogPath $xLogFile -LineValue "Nuget not installed, installing now..."
        Invoke-Command -Session $InstallSession -ScriptBlock { 
          Install-PackageProvider -Name NuGet -Force
        }
      } else {
        Write-Verbose -Message "NuGet already installed, continuing prerequisite checks"
        Log-Write -LogPath $xLogFile -LineValue "NuGet already installed, continuing prerequisite checks"
      }    
      
      #Checks if UCMA executable exists
      if (!($UCMAExist)) {
        #Downloading UCMA 4.0 Runtime      
        Write-Verbose -Message "Starting download of UCMA Runtime 4.0"
        Log-Write -LogPath $xLogFile -LineValue "Starting download of UCMA Runtime 4.0"

        Start-BitsTransfer -Source https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe -Destination $fileshare -Description 'Downloading prerequisites'
        Write-Verbose -Message "Downloading file from https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe to $fileShare"
        Log-Write -LogPath $xLogFile -LineValue "Downloading file from https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe to $fileShare"
        Write-Verbose -Message "UCMA successfully downloaded"
        Log-Write -LogPath $xLogFile -LineValue "UCMA successfully downloaded"
      }else{
        #UCMA already exist, no need to download
        Write-Verbose -Message "UCMA already exist, no need to download"
        Log-Write -LogPath $xLogFile -LineValue "UCMA already exist, no need to download"
      }

      #Checks if the ISO exists
      if (!($ExchangeExist)) {
        #Downloading Exchange 2016
        #Write-Verbose -Message "Starting download of Exchange 2016 CU5"
        Log-Write -LogPath $xLogFile -LineValue "Starting download of Exchange 2016 CU5"
        Write-Verbose -Message "Downloading file from https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso to $fileShare"
        Log-Write -LogPath $xLogFile -LineValue "Downloading file from https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso to $fileShare"
        Start-BitsTransfer -Source https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso -Destination $fileshare -Description 'Downloading prerequisites'
        Write-Verbose -Message "Exchange 2016 successfully downloaded"
        Log-Write -LogPath $xLogFile -LineValue "Exchange 2016 successfully downloaded"
      }else{
        #Exchange ISO already exists, no need to download
        Write-Verbose -Message "Exchange ISO already exists, no need to download"
        Log-Write -LogPath $xLogFile -LineValue "Exchange ISO already exists, no need to download"
      }
    }
         
    Catch {
      Log-Error -LogPath $xLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      $InstallSession | Remove-PSSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $xLogFile -LineValue "Got all prerequisites successfully."
      Log-Write -LogPath $xLogFile -LineValue "-------------------- Function Get-Prerequisite Finished --------------------"
      Write-Verbose -Message 'Got all prerequisites successfully.'
    }
  }
}