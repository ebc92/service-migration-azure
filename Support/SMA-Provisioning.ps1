#requires -version 2

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Declaring the service-migration azure path from relative path
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")

#Dot Source required Function Libraries
$LogLib = Join-Path -Path $SMARoot -ChildPath "Libraries\Log-Functions.ps1"
. $LogLib

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$sScriptVersion = "0.1"
$sLogPath = "C:\Logs\service-migration-azure"
$sLogName = "SMA-Provisioning.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function New-AzureStackWindowsVM {
  Param(
  [String]$ADDS
  )
  
  Begin{
    Import-Module AzureStack, AzureRM

    $res = "sma-vm-provisioning"

    New-AzureRmResourceGroup -Name $res -Location local
    Log-Write -LogPath $sLogFile -LineValue "Created Azure Resource Group $res."
  }
  
  Process{
    Try{

        # Create a subnet configuration
        $subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name default -AddressPrefix 192.168.58.0/24

        # Create a virtual network
        $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $res -Location local -Name amstelvnet -AddressPrefix 192.168.58.0/24 -Subnet $subnetConfig

        # Create a public IP address and specify a DNS name
        $pip = New-AzureRmPublicIpAddress -ResourceGroupName $res -Location local -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $ADDS

        # Get subnet object
        $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetConfig.Name -VirtualNetwork $vnet

        # Create a virtual network card and associate with public IP address and NSG
        $nic = New-AzureRmNetworkInterface -ResourceGroupName $res -Location local -Name NetworkConnection -Subnet $subnet -NetworkSecurityGroup $nsg -PublicIpAddress $pip

    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here
#Log-Finish -LogPath $sLogFile