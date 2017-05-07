Function Configure-Exchange {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [String]$ComputerName,
    [Parameter(Mandatory=$true)]
    [String]$SourceComputer,
    [Parameter(Mandatory=$true)]
    [String]$newfqdn,
    [Parameter(Mandatory=$true)]
    [String]$Password,
    [Parameter(Mandatory=$true)]
    [pscredential]$DomainCredential,
    [Parameter(Mandatory=$true)]
    [String]$hostname
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue 'Configuring new Exchange Install...'
  }
  
  Process{
    Try{   
      #Creates a session to the Exchange Remote Management Shell so that we can run Exchange commands
      $ConfigSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$newfqdn/powershell `
      -Credential $DomainCredential -Authentication Kerberos
      
      #Imports the module that exists in the session, in this case, Exchange Management -AllowClobber gives the imported commands presedence.
      Import-Module (Import-PSSession $ConfigSession -AllowClobber)
            
      $ExchCert = Get-ExchangeCertificate
      
      $ExchCert = ($ExchCert | Where-Object {$_.Subject -eq "CN=$SourceComputer"}).Thumbprint
      
      $Password = ConvertTo-SecureString $Password -AsPlainText -Force
      
      Import-ExchangeCertificate -FileName Z:\Cert\exchcert.pfx -PrivateKeyExportable $true -Password $Password -Server $ComputerName | `
      Exchange-Certificate -Services POP,IMAP,IIS,SMTP -DoNotRequireSsl
      
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
      Get-OwaVirtualDirectory -Server keshav-ex16| Set-OwaVirtualDirectory -InternalUrl http://www.$hostname.com/owa `
      -ExternalUrl http://$hostname/owa
      
      #Set EWS URLs
      Get-WebServicesVirtualDirectory -Server $newfqdn | Set-WebServicesVirtualDirectory -InternalUrl http://$hostname/EWS/Exchange.asmx `
      -ExternalUrl http://$hostname/EWS/Exchange.asmx
      
      #Set ActiveSync URLs      Get-ActiveSyncVirtualDirectory –Server $newfqdn | Set-ActiveSyncVirtualDirectory `
      -InternalUrl http://$hostname/Microsoft-Server-ActiveSync –ExternalUrl http://$hostname/Microsoft-Server-ActiveSync
      
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
      
      #Reboots server
      
      
    }      
    Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      $ConfigSession | Remove-PSSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Successfully configured the new Exchange Server"
      Log-Write -LogPath $sLogFile -LineValue "-------------------- Function Configure-Exchange Finished --------------------"
      Write-Verbose -Message "Successfully configured the new Exchange Server"
      $ConfigSession | Remove-PSSession
    }
  }
}