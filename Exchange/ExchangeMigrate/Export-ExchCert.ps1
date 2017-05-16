Function Export-ExchCert {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [String]$SourceComputer,
    [Parameter(Mandatory=$true)]
    [String]$fqdn,
    [Parameter(Mandatory=$true)]
    [String]$Password,
    [Parameter(Mandatory=$true)]
    [pscredential]$DomainCredential,
    [Parameter(Mandatory=$true)]
    [String]$Basedir
  )
  <#
      .SYNOPSIS
        Gets the Exchange certificates
      .DESCRIPTION
        Exports Exchange certificate and saves it to a targeted fileshare.
      .PARAMETER SourceComputer
        Name of the server you are using as migration source, do not use IP as it will break the script because of WinRM authentication. Name can be amstel-mail, or the fqdn amstel-mail.amstel.local
      .PARAMETER fqdn
        The fully qualified domain name of the source Exchange server used for migration, for example amstel-mail.amstel.local
      .PARAMETER Password
        The password used for the Exchange certificate for import
      .PARAMETER DomainCredential
        A credential object, for example created by running Get-Credential
      .PARAMETER BaseDir
        The base directory for the Temporary Exchange folder on the fileshare. \\share\TempExchange
      .EXAMPLE
        Export-ExchCert -SourceComputer amstel-mail -fqdn wwww.example.com -Password Password -DomainCredential CredObject Basedir \\fileshare\TempExchange
  #>
  Begin{
    Log-Write -LogPath $xLogFile -LineValue 'Exporting Exchange Certificate to fileshare...'
  }
  
  Process{
    Try{
      #I found a much better, and more secure way of doing the below. Instead of actively invoke-command, I import the module from session below
      #I left the comment block in, just incase I need to do some XML editing
      <#
          $FixRemoteSess = New-PSSession -ComputerName $SourceComputer -Credential $DomainCredential
          Invoke-Command -Session $FixRemoteSess {
          #Gets Exchange Install Path, will always remain the same.
          $exchdir = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\V15\Setup).MsiInstallPath
          $PSWebPath = (Join-Path $exchdir -ChildPath ClientAccess\PowerShell\)
          $NewPSWebAppDir = (Join-Path -Path $exchdir -ChildPath ClientAccess\PSFullRemote)
        
          #Creates a new directory and copies the web.config for the new application pool we are creating
          New-Item -ItemType Directory -Path $NewPSWebAppDir -ErrorAction Ignore
          Copy-Item -Path (Join-Path -Path $PSWebPath -ChildPath web.config) -Destination $NewPSWebAppDir        
        
          #Edits the web.config XML file so that one can run EMS in FullLanguage mode.
          [xml]$FixPSRemote = (Get-content $NewPSWebAppDir\web.config)
          $UpdatePSConf = $FixPsRemote.configuration.appSettings.add | Where-Object {$_.Key -eq "PSLanguageMode"}
          $UpdatePSConf.value = 'FullLanguage'
          $xmlsavepath = (Join-Path -Path $NewPSWebAppDir -ChildPath web.config)
          $FixPSRemote.Save($xmlsavepath)
        
          Creates a new application pool
          $psapppool = New-WebAppPool -Name PSFullRemote
        
          #Sets the account which IIS runs the app pool under ( LocalSystem )
          Set-ItemProperty IIS:\AppPools\PSFullremote -Name ProcessModel -Value @{identityType=0}
        
          #Starts the new app pool
          Start-WebAppPool -Name PSFullRemote
        
          #Creates a new application ( PowerShell ) to run in the app pool, using Default Web Site because of time constraints
          $psapplication = New-WebApplication -Name PSFullRemote -Site 'Default Web Site' `
          -PhysicalPath "$NewPSWebAppDir" -ApplicationPool $psapppool.Name
        
          #Sets SSL settings
          Set-WebConfigurationProperty -Filter //security/access -Name SslFlags -Value SslNegotiateCert `
          -PSPath IIS:\ -Location 'Default Web Site/PSFullRemote'
        
          #Create endpoint which you use -URI parameter to connect to
          Register-PSSessionConfiguration -Name PSFullRemote -Force
          Set-PSSessionConfiguration -Name PSFullRemote -Force
        
          #The above should have worked in theory, but doesn't. Due to time constraints I made a "solution".
          #The change below works, but is NOT recommended, bad practice ahead:
          $HttpProxyDir = ( Join-Path -Path $exchdir -ChildPath FrontEnd\HttpProxy\Powershell)

          #Moves the items in the directory in case one has to go back to the current approach
          New-Item -ItemType Directory -Path $HttpProxyDir -Name oldfiles -Force
          Move-Item $HttpProxyDir\*.* -Destination ( Join-Path -Path $HttpProxyDir -ChildPath oldfiles ) -Force
        
          #Copies the web.config that allows for full language remoting
          Copy-Item -Path $NewPSWebAppDir\web.config -Destination ($HttpProxyDir)
          }
      Remove-PSSession $FixRemoteSess #>
      
      $CertPath = (Join-Path $Basedir -ChildPath Cert\exchcert.pfx )   
    
      #Creates a session to the Exchange Remote Management Shell so that we can run Exchange commands
      $ConfigSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$fqdn/powershell `
      -Credential $DomainCredential -Authentication Kerberos
      
      #Imports the module that exists in the session, in this case, Exchange Management -AllowClobber gives the imported commands presedence.
      Import-Module (Import-PSSession $ConfigSession -AllowClobber)
            
      $ExchCert = Get-ExchangeCertificate
      
      $ExchCert = ($ExchCert | Where-Object {$_.Subject -eq "CN=$SourceComputer"}).Thumbprint
      
      $Password = ConvertTo-SecureString $Password -AsPlainText -Force
      
      Export-ExchangeCertificate -Thumbprint $ExchCert -FileName $CertPath -Password $Password
      
    }      
    Catch {
      Log-Error -LogPath $xLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Remove-PSSession $ConfigSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $xLogFile -LineValue "Completed Exporting Exchange Certificate Successfully."
      Log-Write -LogPath $xLogFile -LineValue "-------------------- Function Export-ExchCert Finished --------------------"
      Write-Verbose "Completed Exporting Exchange Certificate Successfully."
      Remove-PSSession $ConfigSession
    }
  }
}