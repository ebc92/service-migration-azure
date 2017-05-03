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
Configuration InstallExchange
{
param
(
  [PSCredential]$DomainCredential
)

Import-DscResource -ModuleName xExchange
Import-DscResource -ModuleName xPendingReboot

Node $AllNodes.NodeName
{
  LocalConfigurationManager
  {
    CertificateId      = $Node.Thumbprint
    RebootNodeIfNeeded = $true
    ActionAfterReboot  = 'ContinueConfiguration'
    ConfigurationMode  = 'ApplyOnly'
  }

  #Check if a reboot is needed before installing Server Roles
  xPendingReboot BeforeServerRoles
  {
    Name      = "BeforeServerRoles"
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
    DependsOn = '[xPendingReboot]BeforeServerRoles'
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
  }    #Check if a reboot is needed before installing Exchange
  
  xPendingReboot BeforeExchangeInstall
  {
    Name      = "BeforeExchangeInstall"

    DependsOn  = '[WindowsFeature]RSATADDS'
  }
  

  Script MountExchange {
    GetScript = {
    }
    SetScript = { 
      $ExchangeBinary = $null

      $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name

      if ($ExchangeBinary -eq $null)
      {        
        Mount-DiskImage -ImagePath "C:\TempExchange\ExchangeServer2016-x64-cu5.iso"
        $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name
      }
    }
    TestScript = {
      Return $false
    }
  }


  #Do the Exchange install
  xExchInstall InstallExchange
  {
    Path       = "C:\TempExchange\setup.exe"
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



###Sets up LCM on target computers to decrypt credentials, and to allow reboot during resource execution
#Set-DscLocalConfigurationManager -Path .\InstallExchange -Verbose

###Pushes configuration and waits for execution
#Start-DscConfiguration -Path .\InstallExchange -Verbose -Wait