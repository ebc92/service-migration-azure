﻿Configuration InstallExchange
{
  param
  (
    [PSCredential]$DomainCredential,
    [String]$FileShare,
    [String]$CertThumb,
    [String]$ExchangeBinary
  )

  Import-DscResource -Module xExchange
  Import-DscResource -Module xPendingReboot

  Node $AllNodes.NodeName
  {
    LocalConfigurationManager
    {
      CertificateId      = $Node.Thumbprint
      RebootNodeIfNeeded = $true
      ActionAfterReboot  = 'ContinueConfiguration'
    }

    #Check if a reboot is needed before installing Server Roles
    xPendingReboot BeforeServerRoles
    {
      Name      = "BeforeServerRoles"
    }
    
    WindowsFeature ASHTTP
    {
      Ensure = 'Present'
      Name = 'AS-HTTP-Activation'
      DependsOn = '[xPendingReboot]BeforeServerRoles'
    }
        
    WindowsFeature DesktopExp
    {
      Ensure = 'Present'
      Name = 'Desktop-Experience'
    }
        
    WindowsFeature NetFW45
    {
      Ensure = 'Present'
      Name = 'NET-Framework-45-Features'
    }
        
    WindowsFeature RPCProxy
    {
      Ensure = 'Present'
      Name = 'RPC-over-HTTP-proxy'
    }
        
    WindowsFeature RSATClus
    {
      Ensure = 'Present'
      Name = 'RSAT-Clustering'
    }
        
    WindowsFeature RSATClusCmd
    {
      Ensure = 'Present'
      Name = 'RSAT-Clustering-CmdInterface'
    }
        
    WindowsFeature RSATClusMgmt
    {
      Ensure = 'Present'
      Name = 'RSAT-Clustering-Mgmt'
    }
        
    WindowsFeature RSATClusPS
    {
      Ensure = 'Present'
      Name = 'RSAT-Clustering-PowerShell'
    }
        
    WindowsFeature WebConsole
    {
      Ensure = 'Present'
      Name = 'Web-Mgmt-Console'
    }
        
    WindowsFeature WAS
    {
      Ensure = 'Present'
      Name = 'WAS-Process-Model'
    }
        
    WindowsFeature WebAsp
    {
      Ensure = 'Present'
      Name = 'Web-Asp-Net45'
    }
        
    WindowsFeature WBA
    {
      Ensure = 'Present'
      Name = 'Web-Basic-Auth'
    }
        
    WindowsFeature WCA
    {
      Ensure = 'Present'
      Name = 'Web-Client-Auth'
    }
        
    WindowsFeature WDA
    {
      Ensure = 'Present'
      Name = 'Web-Digest-Auth'
    }
        
    WindowsFeature WDB
    {
      Ensure = 'Present'
      Name = 'Web-Dir-Browsing'
    }
        
    WindowsFeature WDC
    {
      Ensure = 'Present'
      Name = 'Web-Dyn-Compression'
    }
        
    WindowsFeature WebHttp
    {
      Ensure = 'Present'
      Name = 'Web-Http-Errors'
    }
        
    WindowsFeature WebHttpLog
    {
      Ensure = 'Present'
      Name = 'Web-Http-Logging'
    }
        
    WindowsFeature WebHttpRed
    {
      Ensure = 'Present'
      Name = 'Web-Http-Redirect'
    }
        
    WindowsFeature WebHttpTrac
    {
      Ensure = 'Present'
      Name = 'Web-Http-Tracing'
    }
        
    WindowsFeature WebISAPI
    {
      Ensure = 'Present'
      Name = 'Web-ISAPI-Ext'
    }
        
    WindowsFeature WebISAPIFilt
    {
      Ensure = 'Present'
      Name = 'Web-ISAPI-Filter'
    }
        
    WindowsFeature WebLgcyMgmt
    {
      Ensure = 'Present'
      Name = 'Web-Lgcy-Mgmt-Console'
    }
        
    WindowsFeature WebMetaDB
    {
      Ensure = 'Present'
      Name = 'Web-Metabase'
    }
        
    WindowsFeature WebMgmtSvc
    {
      Ensure = 'Present'
      Name = 'Web-Mgmt-Service'
    }
        
    WindowsFeature WebNet45
    {
      Ensure = 'Present'
      Name = 'Web-Net-Ext45'
    }
        
    WindowsFeature WebReq
    {
      Ensure = 'Present'
      Name = 'Web-Request-Monitor'
    }
        
    WindowsFeature WebSrv
    {
      Ensure = 'Present'
      Name = 'Web-Server'
    }
        
    WindowsFeature WebStat
    {
      Ensure = 'Present'
      Name = 'Web-Stat-Compression'
    }
        
    WindowsFeature WebStatCont
    {
      Ensure = 'Present'
      Name = 'Web-Static-Content'
    }
        
    WindowsFeature WebWindAuth
    {
      Ensure = 'Present'
      Name = 'Web-Windows-Auth'
    }
        
    WindowsFeature WebWMI
    {
      Ensure = 'Present'
      Name = 'Web-WMI'
    }
        
    WindowsFeature WebIF
    {
      Ensure = 'Present'
      Name = 'Windows-Identity-Foundation'
    }
        
    WindowsFeature RSATADDS
    {
      Ensure = 'Present'
      Name = 'RSAT-ADDS'
    }
    
    #Check if a reboot is needed before installing UCMA v4.0
    xPendingReboot BeforeUCMA
    {
      Name      = "BeforeUCMA"
    }
      
    Package UCMA
    {
      Name      = 'UCMA 4.0' 
      Ensure    = 'Present'
      Path      = "$fileshare"
      ProductID = 'ED98ABF5-B6BF-47ED-92AB-1CDCAB964447'
      Arguments = '/passive /norestart'
      Credential= "$DomainCredential"
    }

    #Copy the Exchange setup files locally
    File ExchangeBinaries
    {
      Ensure          = 'Present'
      Type            = 'Directory'
      Recurse         = $true
      SourcePath      = "$ExchangeBinary"
      DestinationPath = 'C:\Binaries\E16CU5'
    }

    #Check if a reboot is needed before installing Exchange
    xPendingReboot BeforeExchangeInstall
    {
      Name      = "BeforeExchangeInstall"

      DependsOn  = '[File]ExchangeBinaries'
    }

    #Do the Exchange install
    xExchInstall InstallExchange
    {
      Path       = "C:\Binaries\E16CU5\Setup.exe"
      Arguments  = "/mode:Install /role:Mailbox /IAcceptExchangeServerLicenseTerms /OrganizationName:Nikolaitl"
      Credential = $DomainCredential

      DependsOn  = '[xPendingReboot]BeforeExchangeInstall'
    }

    #See if a reboot is required after installing Exchange
    xPendingReboot AfterExchangeInstall
    {
      Name      = "AfterExchangeInstall"

      DependsOn = '[xExchInstall]InstallExchange'
    }
  }
}

if ($null -eq $DomainCredential)
{
  $Creds = Get-Credential -Message "Enter credentials for establishing Remote Powershell sessions to Exchange"
}

$ConfigData=@{
  AllNodes = @(
    @{
      NodeName = '*'
      CertificateFile = "C:\tempExchange\Cert\dsccert.cer"
      Thumbprint = $CertThumb
    }

    @{
      NodeName = "localhost"
      PSDscAllowDomainUser = $true
    }
  )
}

###Sets up LCM on target computers to decrypt credentials, and to allow reboot during resource execution
#Set-DscLocalConfigurationManager -Path .\InstallExchange -Verbose

###Pushes configuration and waits for execution
#Start-DscConfiguration -Path .\InstallExchange -Verbose -Wait