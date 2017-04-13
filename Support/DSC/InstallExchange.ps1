Configuration InstallExchange
{
param
(
  [Parameter(Mandatory=$true)]   
  [PSCredential]$Creds,
  [Parameter(Mandatory=$true)]
  [String]$ComputerName,
  [Parameter(Mandatory=$true)]
  [String]$Binary,
  [Parameter(Mandatory=$true)]
  [String]$SourceFile
)

Import-DscResource -Module xExchange
Import-DscResource -Module xPendingReboot

Node $AllNodes.NodeName
{
  LocalConfigurationManager
  {
    CertificateId      = $Node.Thumbprint
    RebootNodeIfNeeded = $true
  }

  #Mounts Exchange 2016 image from share	
  Function ExchangeBinaries
  {
    Try {          
      $Binary = (Mount-DiskImage -ImagePath $SourceFile\ExchangeServer2016-x64-cu5.iso `
      -PassThru | Get-Volume).Driveletter + ":"
      Return $Binary
    }
    Catch {
    }
  }
  
    #Check if a reboot is needed before installing Exchange
    xPendingReboot BeforeExchangeInstall
    {
      Name      = "BeforeExchangeInstall"

      DependsOn  = '[Function]ExchangeBinaries'
    }

    #Do the Exchange install
    xExchInstall InstallExchange
    {
      Path       = $Binary
      Arguments  = "/mode:Install /role:Mailbox /Iacceptexchangeserverlicenseterms"
      Credential = $Creds

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

if ($null -eq $Creds)
{
  $Creds = Get-Credential -Message "Enter credentials for establishing Remote Powershell sessions to Exchange"
}

###Compiles the example
InstallExchange -ConfigurationData $PSScriptRoot\InstallExchange-Config.psd1 -Creds $Creds

###Sets up LCM on target computers to decrypt credentials, and to allow reboot during resource execution
Set-DscLocalConfigurationManager -Path .\InstallExchange -Verbose

###Pushes configuration and waits for execution
Start-DscConfiguration -Path .\InstallExchange -Verbose -Wait
