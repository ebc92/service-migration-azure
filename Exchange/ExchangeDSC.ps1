###########################################################################
####################################\O/####################################
##   ______          _                            _____   _____  _____   ##
##  |  ____|        | |                          |  __ \ / ____|/ ____|  ##
##  | |__  __  _____| |__   __ _ _ __   __ _  ___| |  | | (___ | |       ##
##  |  __| \ \/ / __| '_ \ / _` | '_ \ / _` |/ _ \ |  | |\___ \| |       ##
##  | |____ >  < (__| | | | (_| | | | | (_| |  __/ |__| |____) | |____   ##
##  |______/_/\_\___|_| |_|\__,_|_| |_|\__, |\___|_____/|_____/ \_____|  ##
##                                      __/ |                            ##
##                                     |___/                             ##
###########################################################################
###########################################################################
Configuration InstallExchange {
  param
  (
    [Parameter(Mandatory=$true)]   
    [PSCredential]$DomainCredential,
    [Parameter(Mandatory=$true)]
    [String]$ComputerName,
    [Parameter(Mandatory=$true)]
    [String]$ExchangeBinary,
    [Parameter(Mandatory=$true)]
    [String]$UCMASource,
    [Parameter(Mandatory=$true)]
    [String]$Domain
  )
  

  Import-DscResource -ModuleName xExchange, xPendingReboot, xWindowsUpdate
  
  Node $AllNodes.NodeName
  {
    #Specifies settings for the local configuration manager. Sets apply mode to apply only so it does not try to fix on eventual drift
    LocalConfigurationManager
    {
      CertificateId      = $Node.Thumbprint
      ConfigurationMode  = 'ApplyOnly'
      RebootNodeIfNeeded = $true
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
 
    #Check if a reboot is needed before installing KB3199986
    xPendingReboot "BeforeKB3199986"
    {
      Name      = "BeforeKB3199986"      
    }
    
    xHotfix KB3199986
    {
      DependsOn = "BeforeKB3199986"
      Ensure = "Present"
      Path = "http://download.windowsupdate.com/c/msdownload/update/software/crup/2016/10/windows10.0-kb3199986-x64_5d4678c30de2de2bd7475073b061d0b3b2e5c3be.msu"
      Id = "KB3199986"
    }    
    
    #Check if a reboot is needed before installing KB3206632
    xPendingReboot "BeforeKB3206632"
    {
      Name      = "BeforeKB3206632"      
    }
    
    xHotFix KB3206632
    {
      Ensure = "Present"
      Path = "http://download.windowsupdate.com/d/msdownload/update/software/secu/2016/12/windows10.0-kb3206632-x64_b2e20b7e1aa65288007de21e88cd21c3ffb05110.msu"
      Id = "KB3206632"
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
    
    #Check if a reboot is needed before installing Exchange
    xPendingReboot BeforeExchangeInstall
    {
      Name      = "BeforeExchangeInstall"
    }

    #Do the Exchange install
    xExchInstall InstallExchange
    {
      Path       = $ExchangeBinary\setup.exe
      Arguments  = "/mode:Install /role:Mailbox /OrganizationName:$Domain /IAcceptExchangeServerLicenseTerms "
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