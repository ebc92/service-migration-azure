Function Install-Prerequisite {
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$baseDir,
    [parameter(Mandatory=$true)]
    [string]$ComputerName,
    [parameter(Mandatory=$true)]
    [PSCredential]$DomainCredential,
    [parameter(Mandatory=$true)]
    [securestring]$CertPW
  )
  
  Begin{
    $variableOutput = '        $fileShare ' + "= $fileShare"
    Log-Write -LogPath $xLogFile -LineValue 'Installing prerequisites for Microsoft Exchange 2013...'
    Log-Write -LogPath $xLogFile -LineValue "The following variables are set for $MyInvocation.MyCommand.Name :"
    Log-Write -LogPath $xLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      #$CertPW = Read-Host -Prompt "Please input a password for the certificate: " -AsSecureString
      $Domain = "Amstel"
      $CertExportPath = "C:\Cert\dsccert.cer"
      $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name
      
      Log-Write -LogPath $xLogFile -LineValue "Testing if the certificate path exists"
      Write-Verbose -Message "Testing if the certificate path exists"
      Invoke-Command -Session $InstallSession -ScriptBlock {      
        #Check to see if certificate directory exists, and creates it if not
        $VerifyCertPath = (Test-Path -Path "C:\Cert\")
        if (!($VerifyCertPath)){
          Write-Verbose -Message "Creating folder for certificate"    
          New-Item -Path "C:\Cert" -ItemType Directory -ErrorAction Ignore
        }
      }
      
      Log-Write -LogPath $xLogFile -LineValue "Getting the certificate thumb"
      Write-Verbose -Message "Getting the certificate thumb"
      $CertThumb = Invoke-Command -Session $InstallSession -ScriptBlock { 
        Write-Verbose -Message "Getting Certificate Thumbprint"
        #Get Certificate thumbprint
        $CertThumb = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$using:ComputerName-dsccert"}).Thumbprint
        $CertThumb
      }

      #Session to export the certificate to the mounted PSDrive
      Log-Write -LogPath $xLogFile -LineValue "Exporting the certificate to the file share. Thumb = $CertThumb"
      Write-Verbose -Message "Exporting the certificate to the file share. Thumb = $CertThumb"
      Invoke-Command -Session $InstallSession -ScriptBlock {
        $VerbosePreference = 'Continue'
        
        #Exporting Certificate            
        Write-Verbose -Message "Exporting cert to $using:CertExportPath"
        
        #Sets certificate export paths      
        $CertTargetPath = Join-Path -Path Cert:\LocalMachine\My -ChildPath $using:CertThumb
        $CertExport = (Get-ChildItem -Path $CertTargetPath)
      
        #Exports the DSC certificate to the mounted PSDrive
        Export-Certificate -Cert $CertExport -FilePath $using:CertExportPath -Type CERT
        $CertExport | Export-PfxCertificate -FilePath Z:\Cert\cert.pfx -Password $using:CertPW
        
        #Test-Path to verify that the ISO exists
        $isoexists = Test-Path -Path C:\TempExchange\EXCHANGESERVER2016-X64-CU5.iso

        If (!($isoexists)) {
            #Move Exchange install files
            New-Item -ItemType Directory -Path "C:\TempExchange" -ErrorAction Ignore
            Write-Verbose -Message "Moving Exchange ISO from share, to local storage"
            Start-BitsTransfer -Source "Z:\Executables\EXCHANGESERVER2016-X64-CU5.iso" -Destination "C:\TempExchange\" -Credential $using:DomainCredential
            Write-Verbose -Message "Exchange ISO successfully moved to C:\TempExchange\"
        } else {
            Write-Verbose -Message "C:\TempExchange\EXCHANGESERVER2016-X64-CU5.iso already exists, moving on"
            Log-Write -LogPath $xLogFile -LineValue "C:\TempExchange\EXCHANGESERVER2016-X64-CU5.iso already exists, moving on"
        }
      
        #Install modules
        Install-Module -Name xPendingReboot -Force -Verbose
                
        #Test-path to see if UCMA is installed
        $ucmatest = Test-Path -Path "C:\Program Files\Microsoft UCMA 4.0"
        
        #Checks if UCMA is installed
        if(!($ucmatest)) {
          #InstallUCMA          
          Write-Verbose -Message "Starting Install of UCMA"
          Start-Process -FilePath "Z:\Executables\UcmaRuntimeSetup.exe" -ArgumentList '/passive /norestart' -NoNewWindow -Wait -Verbose
          Write-Verbose -Message "UCMA Installed, starting DSC"
        } else {
          Write-Verbose -Message "UCMA Already installed, moving on to DSC"
        }
      }
      
      #Imports the DSC certificate on the server running the script so it can encrypt the DSC configuration
      Log-Write -LogPath $xLogFile -LineValue "Importing PFX certificate"
      Write-Verbose -Message "Importing PFX certificate"
      Import-PfxCertificate -FilePath "$baseDir\Cert\cert.pfx" -CertStoreLocation Cert:\LocalMachine\My\ -Password $CertPW -Verbose
      
      Log-Write -LogPath $xLogFile -LineValue "Running DSC configuration on $ComputerName"
      Log-Write -LogPath $xLogFile -LineValue "With Thumb = $CertThumb"
      Write-Verbose -Message "Running DSC configuration on $ComputerName"
      Write-Verbose -Message "CertThumb = $CertThumb"
      
      #Gets the certificate path on the local server
      $CertPath = Join-Path -Path Cert:\LocalMachine\My -ChildPath $CertThumb
      
      Log-Write -LogPath $xLogFile -LineValue "$CertPath is the target certificate"
      Write-Verbose -Message "$CertPath is the target certificate"
      Export-Certificate -Cert $CertPath -FilePath $CertExportPath -Type CERT -Verbose

      #Install modules
      Log-Write -LogPath $xLogFile -LineValue "Installing xExchange and xPending DSC modules"
      Write-Verbose -Message "Installing xExchange and xPending DSC modules"
      Install-Module -Name xPendingReboot -Force -Verbose
      
      #Dot source InstallExchange DSC configuration
      $DSC = (Join-Path -Path $PSScriptRoot -ChildPath InstallExchange.ps1)
      . $DSC
      "$DSC"
      
      #Configuration data for DSC
      $ConfigData=@{
        AllNodes = @(
          @{
            NodeName = '*'
            CertificateFile = "C:\Cert\dsccert.cer"
          }

          @{
            NodeName = $ComputerName
            Thumbprint = $CertThumb
            PSDscAllowDomainUser = $true
          }
        )
      }
      
      Log-Write -LogPath $xLogFile -LineValue "Starting DSC"
      Write-Verbose -Message "Starting DSC"
      
      #Starts a transcript of the console output, which is used as a DSC log
      Start-Transcript -Path ( Join-Path -Path $xLogPath -ChildPath dsclog-$xlogDate.txt )
      
      #Sets the location to the script root, so that the InstallExchange DSC resources creates the .mof files in the correct directory.
      Set-Location $PSScriptRoot
      
      #Gets the drive letter for the Exchange ISO
      $ExchangeBinary = Get-Content -Path ( Join-Path $baseDir -ChildPath Executables\ExchangeBinary.txt )
      "$ExchangeBinary before compiling DSC script"
      
      Log-Write -LogPath $xLogFile -LineValue "Compiling DSC Script"            
      Write-Verbose -Message "Compiling DSC script"
      #Compiles DSC Script
      InstallExchange -ConfigurationData $ConfigData -DomainCredential $DomainCredential -ExchangeBinary $ExchangeBinary -Verbose

      Log-Write -LogPath $xLogFile -LineValue "Setting up LCM on target computer"
      Write-Verbose -Message "Setting up LCM on target computer"
      #Sets up LCM on target comp
      Set-DscLocalConfigurationManager -Path $PSScriptRoot\InstallExchange -Force -Verbose

      Log-Write -LogPath $xLogFile -LineValue "Pushing DSC script to target computer"
      Write-Verbose -Message "Pushing DSC script to target computer"
      #Pushes DSC script to target
      Start-DscConfiguration -Path $PSScriptRoot\InstallExchange -Force -Verbose -Wait
          
      Stop-Transcript
    }
       
    Catch {
      Log-Error -LogPath $xLogFile -ErrorDesc $_.Exception -ExitGracefully $True      
      Write-Verbose -Message "Removing remote session $InstallSession"
      $InstallSession | Remove-PSSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $xLogFile -LineValue "Installed prerequisites successfully."
      Log-Write -LogPath $xLogFile -LineValue "-------------------- Function Install-Prerequisite Finished --------------------"
      Write-Verbose -Message "Installed prerequisites successfully."
    }
  }
}