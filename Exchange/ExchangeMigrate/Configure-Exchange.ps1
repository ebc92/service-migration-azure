Function Configure-Exchange {
  <#
      .SYNOPSIS
      Configures Exchange URLs, moves mailboxes and imports an exported certificate.
      .DESCRIPTION
      First creates a session to Exchange Management Shell on target server. It then imports a previously exported exchange certificate, this one is gotten from the path Z:\Cert\Exchcert.pfx
      which is a mounted file share on the server. The function then sets all Exchange URLs to this format: http://www.example.com/exchangeurl. Note that http is used because of this being a
      proof of concept, in an actual live environment https:// would be used.

      The last thing that happens, is the migration of the mailbox database. This is done by getting the existing databases, then using New-MoveRequest to move them.
      .PARAMETER ComputerName
      Name of the server you are targeting, do not use IP as it will break the script because of WinRM authentication. Name can be amstel-mail, or the FQDN amstel-mail.amstel.local
      .PARAMETER SourceComputer
      Name of the server you are using as migration source, do not use IP as it will break the script because of WinRM authentication. Name can be amstel-mail, or the FQDN amstel-mail.amstel.local
      .PARAMETER Newfqdn
      The fully qualified domain name of the new Exchange server, for example amstel-exch.amstel.local
      .PARAMETER Password
      The password used for the Exchange certificate for import
      .PARAMETER DomainCredential
      A credential object, for example created by running Get-Credential
      .PARAMETER Hostname
      The hostname of the Exchange organization. Format is wwww.example.com
      .PARAMETER BaseDir
      The base directory for the Temporary Exchange folder on the fileshare. \\share\TempExchange
      .EXAMPLE
      COnfigure-Exchange -ComputerName amstel-exch -SourceComputer amstel-mail - amstel-exch.amstel.local -Password password -DomainCredential CredObject -Hostname www.nikolaitl.no
  #>
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [String]$ComputerName,
    [Parameter(Mandatory=$true)]
    [String]$SourceComputer,
    [Parameter(Mandatory=$true)]
    [String]$Newfqdn,
    [Parameter(Mandatory=$true)]
    [securestring]$Password,
    [Parameter(Mandatory=$true)]
    [pscredential]$DomainCredential,
    [Parameter(Mandatory=$true)]
    [String]$Hostname,
    [Parameter(Mandatory=$true)]
    [String]$BaseDir
  )   
  Begin{
    Log-Write -LogPath $xLogFile -LineValue 'Configuring new Exchange Install...'
  }
  
  Process{
    Try{    
      #Creates a session to the Exchange Remote Management Shell so that we can run Exchange commands
      "The newfqdn is $Newfqdn, the domain cred is $DomainCredential"
      
      $ConfigSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$newfqdn/powershell `
      -Credential $DomainCredential -Authentication Kerberos
      
      #Imports the module that exists in the session, in this case, Exchange Management -AllowClobber gives the imported commands presedence.
      Import-Module (Import-PSSession $ConfigSession -AllowClobber)
            
      $ExchCert = Get-ExchangeCertificate
      
      $ExchCert = ($ExchCert | Where-Object {$_.Subject -eq "CN=$SourceComputer"}).Thumbprint
      
      $CertPath = (Join-Path $Basedir -ChildPath Cert\exchcert.pfx )
      
      Import-ExchangeCertificate -FileName $CertPath -PrivateKeyExportable $true -Password $Password -Server $ComputerName | `
      Enable-ExchangeCertificate -Services POP,IMAP,SMTP,IIS -DoNotRequireSsl
      
      #Now starting with setting up Exchange Virtual Directory URLs, using http:// because it is a test enviroment
      
      #Set OutlookAnywhere URLs
      Get-OutlookAnywhere -Server $ComputerName | Set-OutlookAnywhere -InternalHostname $hostname `
      -InternalClientAuthenticationMethod Ntlm -InternalClientsRequireSsl $false  `
      -ExternalHostname $hostname -ExternalClientAuthenticationMethod Basic `
      -ExternalClientsRequireSsl $false -IISAuthenticationMethods Negotiate,NTLM,Basic
      
      #Set ECP URLs
      Get-EcpVirtualDirectory -Server $newfqdn | Set-EcpVirtualDirectory -InternalURL http://$hostname/ecp `
      -ExternalURL http://$hostname/ecp
      
      #Set OWA URLs
      Get-OwaVirtualDirectory -Server $ComputerName| Set-OwaVirtualDirectory -InternalUrl http://$hostname.com/owa `
      -ExternalUrl http://$hostname/owa
      
      #Set EWS URLs
      Get-WebServicesVirtualDirectory -Server $newfqdn | Set-WebServicesVirtualDirectory -InternalUrl http://$hostname/EWS/Exchange.asmx `
      -ExternalUrl http://$hostname/EWS/Exchange.asmx
      
      #Set ActiveSync URLs      
      Get-ActiveSyncVirtualDirectory -Server $newfqdn | Set-ActiveSyncVirtualDirectory `
      -InternalUrl http://$hostname/Microsoft-Server-ActiveSync -ExternalUrl http://$hostname/Microsoft-Server-ActiveSync
      
      #Set OAB URLs
      Get-OabVirtualDirectory -Server $newfqdn | Set-OabVirtualDirectory -InternalUrl http://$hostname/OAB -ExternalUrl http://$hostname/OAB
      
      #Set MAPI URLs
      Get-MapiVirtualDirectory -Server $newfqdn | Set-MapiVirtualDirectory -InternalUrl http://$hostname/mapi -ExternalUrl http://$hostname/mapi
      
      #URLs are set, starting migration of data
      #Gets the name of the new Exchange Database
      $NewMailDatabase = (Get-MailboxDatabase -Server $ComputerName).Name
      $OldMailDatabase = (Get-MailboxDatabase -Server $SourceComputer).Name
      
      #Starts a move request for the mailboxes to the new Exchange server
      Get-Mailbox -Arbitration | Where-Object {$_.Servername -eq "$SourceComputer"} | New-MoveRequest -TargetDatabase $NewMailDatabase
      
      #Starts a move request for the public folders
      Get-Mailbox -Server $SourceComputer -PublicFolder | New-MoveRequest -TargetDatabase $NewMailDatabase
      
      #Moves the user mailboxes
      Get-Mailbox -Database $OldMailDatabase | New-MoveRequest -TargetDatabase $NewMailDatabase      
    }      
    Catch {
      Log-Error -LogPath $xLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      $ConfigSession | Remove-PSSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $xLogFile -LineValue "Successfully configured the new Exchange Server"
      Log-Write -LogPath $xLogFile -LineValue "-------------------- Function Configure-Exchange Finished --------------------"
      Write-Verbose -Message "Successfully configured the new Exchange Server"
      $ConfigSession | Remove-PSSession
    }
  }
}