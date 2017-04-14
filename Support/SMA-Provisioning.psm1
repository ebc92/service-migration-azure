#requires -version 2

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Declaring the service-migration azure path from relative path
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")

#Dot Source required Function Libraries
$LogLib = Join-Path -Path $SMARoot -ChildPath "Libraries\Log-Functions.ps1"
. $LogLib

$IpCalc = Join-Path -Path $SMARoot -ChildPath "Libraries\ipcalculator.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$sScriptVersion = "0.1"
$sLogPath = "C:\Logs\service-migration-azure"
$sLogName = "SMA-Provisioning.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function New-AzureStackTenantDeployment {
    Param(
        [String]$ResourceGroupName = "sma-vm-provisioning",
        [Parameter(Mandatory=$true)]
        [String]$VMName,
        [String]$IPAddress
    )
    $Connect = "C:\Users\AzureStackAdmin\Desktop\AzureStack-Tools-master\Connect\AzureStack.Connect.psm1"
    $ComputeAdmin = "C:\Users\AzureStackAdmin\Desktop\AzureStack-Tools-master\ComputeAdmin\AzureStack.ComputeAdmin.psm1"

    Import-Module AzureStack, AzureRM
    Import-Module $Connect
    Import-Module $ComputeAdmin

    Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

    Try{ 
        $context = Get-AzureRmContext -ErrorAction Stop
    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "Azure Resource Manager context could not be retrieved. Verify that you are logged in."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }

    $exists = Get-AzureRmResourceGroup -Name $ResourceGroupName

    if(!$exists){
        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
        Log-Write -LogPath $sLogFile -LineValue "Created Azure Resource Group $ResourceGroupName."
    } else {
        Log-Write -LogPath $sLogFile -LineValue "Resource Group already exists."
    }

    Try {
        $VMNic = New-AzureStackVnet -NetworkIP $IPAddress -ResourceGroupName $ResourceGroupName -VNetName "AMSTEL-vnet" -VMName $VMName -ErrorAction Stop
    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "The VM deployment failed because no NIC was returned."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
    New-AzureStackWindowsVM -VMName $VMName -VMNic $VMNic -ErrorAction Stop
}

Function New-AzureStackVnet{
    [CmdletBinding()]
    Param(
    $NetworkIP,
    $ResourceGroupName,
    $VNetName,
    $VMName,
    $Location = "local"
    )

    $Network = & $IpCalc $NetworkIP

    $res = $ResourceGroupName

    # Prerequisites
    $ErrorActionPreference = "SilentlyContinue"
    $VMNicName = $VMName + "-NIC"
    $nsgName = $VNetName + "-NSG"

    $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name default -VirtualNetwork $vnet
    $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $res -Name $nsgName
    $nsRules = Get-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $res -Name $VMNicName
    
    Try {

        # Create a subnet configuration
        if(!$subnet){
            $subnet = New-AzureRmVirtualNetworkSubnetConfig -Name default -AddressPrefix $Network.Network
            Log-Write -LogPath $sLogFile -LineValue "Created the subnet configuration."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The subnet configuration already exists."
        }

        # Create a vNet
        if(!$vnet){
            $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $res -Location $Location -Name $VNetName -AddressPrefix $Network.Network -Subnet $subnet
            Log-Write -LogPath $sLogFile -LineValue "Created the virtual network."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The virtual network already exists."
        }

        # Check if subnet configuration exists
        if(!$subnet){
            Log-Write -LogPath $sLogFile -LineValue "Could not get the subnet configuration."
        }

        # Create an inbound network security group rule for port 3389
        if(!$nsgRules){
            $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name InboundRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
            Log-Write -LogPath $sLogFile -LineValue "Created network security group rule for RDP."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The network security group rule for RDP already exists."
        }

        # Create a network security group
        if(!$nsg){
            $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $res -Location $Location -Name $nsgName -SecurityRules $nsgRuleRDP
            Log-Write -LogPath $sLogFile -LineValue "Created network security group with RDP rules."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The network security group already exists."
        }

        # Create a virtual network card and associate with public IP address and NSG
        if(!$nic){
            $nic = New-AzureRmNetworkInterface -ResourceGroupName $res -Location $Location -Name $VMNicName -Subnet $subnet -NetworkSecurityGroup $nsg -PrivateIpAddress $Network.Address
            Log-Write -LogPath $sLogFile -LineValue "Created the network interface."
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The network interface already exists."
        }

    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }

    return $nic
}

Function New-AzureStackWindowsVM {
    [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [String]$VMName,
    [String]$ComputerName = $VMName,
    [Parameter(Mandatory=$true)]
    [Microsoft.Azure.Commands.Network.Models.PSNetworkInterface]
    $VMNic,
    [String]$ResourceGroup = "sma-vm-provisioning",
    [String]$VMSize = "Standard_A1",
    [String]$StorageAccountName = "vhdstorage",
    [String]$Location = "local"
  )
  
  Process{
    Try{

        # Get the VM Image Offer
        $offer = Get-AzureRmVMImageOffer -Location $Location -PublisherName MicrosoftWindowsServer

        # Get the VM Image SKU
        $sku = Get-AzureRMVMImageSku -Location $Location -PublisherName $offer.PublisherName -Offer $offer.Offer

        # Define a credential object
        $cred = Get-Credential

        $StorageAccount = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName}

        #If the storage account does not exist it will be created.
        if(!$StorageAccount){
                New-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName -Type Standard_LRS -Location $Location
        }

        $OSDiskName = $VMName + "OSDisk"
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"

        # Create a virtual machine configuration
        $vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName $ComputerName -Credential $cred | `
        Set-AzureRmVMSourceImage -PublisherName $offer.PublisherName -Offer $offer.Offer -Skus $sku.Skus -Version latest | `
        Set-AzureRmVMOSDisk -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage | `
        Add-AzureRmVMNetworkInterface -Id $VMNic.Id

        New-AzureRmVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig -Verbose

    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "VM provisioning completed successfully."
    }
  }
}

#Function New-RDPortMap must be run on MAS-BGPNAT
Function New-RDPortMap {
    Param(
    [Integer]$PortNumber = "13389",
    [String]$ExternalIP = "158.38.57.109",
    [String]$InternalIP
    )
    Try {
        $NatInstance = Get-NetNat
        Add-NetNatStaticMapping -NatName $NatInstance.Name -ExternalIPAddress $ExternalIP -ExternalPort $PortNumber -InternalIPAddress $InternalIP
  
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Log-Write -LogPath $sLogFile -LineValue "Port mapping failed."
    }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here
#Log-Finish -LogPath $sLogFile