#requires -version 2

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

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
  )
  
  Begin{
    $ComputeAdmin = "C:\Users\AzureStackAdmin\Desktop\AzureStack-Tools-master\ComputeAdmin\AzureStack.ComputeAdmin.psm1"
    $Connect = "C:\Users\AzureStackAdmin\Desktop\AzureStack-Tools-master\Connect\AzureStack.Connect.psm1"
    Import-Module AzureStack, AzureRM
    Import-Module $ComputeAdmin
    Import-Module $Connect

    Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

    $res = "sma-vm-provisioning"
    $exists = Get-AzureRmResourceGroup -Name $res

    if(!$exists){
        New-AzureRmResourceGroup -Name $res -Location local
        Log-Write -LogPath $sLogFile -LineValue "Created Azure Resource Group $res."
    } else {
        Log-Write -LogPath $sLogFile -LineValue "Resource Group already exists."
    }
    
  }
  
  Process{
    Try{

        # Prerequisites
        $vnetExists = Get-AzureRmVirtualNetwork -ResourceGroupName "sma-vm-provisioning" -Name amstelvnet
        $subnetExists = Get-AzureRmVirtualNetworkSubnetConfig -Name default -VirtualNetwork $vnetExists
        $nsgExists = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $res -Name myNetworkSecurityGroup
        $nsRuleExists = Get-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsgExists
        $nicExists = Get-AzureRmNetworkInterface -ResourceGroupName $res -Name NetworkConnection

        # Create a subnet configuration
        if(!$subnetExists){
            $subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name default -AddressPrefix 192.168.58.0/24
            Log-Write -LogPath $sLogFile -LineValue "Created the subnet configuration."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The subnet configuration already exists."
        }

        # Create a vNet
        if(!$vnetExists){
            $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $res -Location local -Name amstelvnet -AddressPrefix 192.168.58.0/24 -Subnet $subnetConfig
            Log-Write -LogPath $sLogFile -LineValue "Created the virtual network."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The virtual network already exists."
        }

        # Check if subnet configuration exists
        if(!$subnetExists){
            Log-Write -LogPath $sLogFile -LineValue "Could not get the subnet configuration."
        }

        # Create an inbound network security group rule for port 3389
        if(!$nsgRuleExists){
            $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name InboundRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
            Log-Write -LogPath $sLogFile -LineValue "Created network security group rule for RDP."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The network security group rule for RDP already exists."
        }

        # Create a network security group
        if(!$nsgExists){
            $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $res -Location local -Name myNetworkSecurityGroup -SecurityRules $nsgRuleRDP
            Log-Write -LogPath $sLogFile -LineValue "Created network security group with RDP rules."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The network security group already exists."
        }


      
        # Create a virtual network card and associate with public IP address and NSG
        if(!$nicExists){
            $nic = New-AzureRmNetworkInterface -ResourceGroupName $res -Location local -Name NetworkConnection -Subnet $subnetExists -NetworkSecurityGroup $nsg -PrivateIpAddress 192.168.58.113
            Log-Write -LogPath $sLogFile -LineValue "Created the network interface."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The network interface already exists."
        }
        

        # Get the VM Image Offer
        $offer = Get-AzureRmVMImageOffer -Location local -PublisherName MicrosoftWindowsServer

        # Get the VM Image SKU
        $sku = Get-AzureRMVMImageSku -Location local -PublisherName $offer.PublisherName -Offer $offer.Offer

        # Define a credential object
        $cred = Get-Credential

        # Create a virtual machine configuration
        $vmConfig = New-AzureRmVMConfig -VMName ProvisionVMtest -VMSize Standard_D1 | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName VirtualTest -Credential $cred | `
        Set-AzureRmVMSourceImage -PublisherName $offer.PublisherName -Offer $offer.Offer -Skus $sku.Skus -Version latest | `
        Add-AzureRmVMNetworkInterface -Id $nic.Id

        New-AzureRmVM -ResourceGroupName $res -Location local -VM $vmConfig

    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
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