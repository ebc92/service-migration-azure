#requires -version 2

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Declaring the service-migration azure path from relative path
$SMARoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\")

#Dot Source required Function Libraries
$LogLib = Join-Path -Path $SMARoot -ChildPath "Libraries\Log-Functions.ps1"
. $LogLib

$IpCalc = Join-Path -Path $SMARoot -ChildPath "Libraries\ipcalculator.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------
$sScriptVersion = "1.0"
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$sLogPath = $SMAConfig.Global.logpath
$sLogName = "SMA-VMprovisioning-$($xLogDate).log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

$LocalEndpoint = $SMAConfig.Global.localendpoint
$LocalNetwork = $SMAConfig.Global.network
$EnvironmentName = $SMAConfig.Global.environmentname
#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function New-AzureStackTenantDeployment {
    Param(
        [String]$ResourceGroupName = "service-migration-azure",
        [Parameter(Mandatory=$true)]
        [String]$VMName,
        [Parameter(Mandatory=$true)]
        [String]$IPAddress,
        [Parameter(Mandatory=$true)]
        [PSCredential]$DomainCredential,
        [String]$DomainName = "amstel.local",
        [String]$Location = "local"
    )

    $sLogName = $sLogName.Split(".")[0] + "-$($VMName)." + $sLogName.Split(".")[1]

    Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

    Try{ 
        $context = Get-AzureRmContext -ErrorAction Stop
    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "Azure Resource Manager context could not be retrieved. Verify that you are logged in."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }

    Try{ 
        Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        Log-Write -LogPath $sLogFile -LineValue "Retrieved Azure Resource Group $ResourceGroupName."
    } Catch {
        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
        Log-Write -LogPath $sLogFile -LineValue "Created Azure Resource Group $ResourceGroupName."
    }

    <#
    if(!$exists){
        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
        
    } else {
        Log-Write -LogPath $sLogFile -LineValue "Resource Group already exists."
    }#>

    Try {
        $VMNic = New-AzureStackVnet -NetworkIP $IPAddress -ResourceGroupName $ResourceGroupName -VNetName "$($EnvironmentName)-VNET" -VMName $VMName
        Log-Write -LogPath $sLogFile -LineValue "VM Network interface was created."
    } Catch {
        Log-Write -LogPath $sLogFile -LineValue "The VM deployment failed because no NIC was returned."
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }

    Log-Write -LogPath $sLogFile -LineValue "Starting VM provisioning..."

    $VMNic | % {if($_.GetType().Name -eq "PSNetworkInterface"){$result = $_}}



    $ProvisionedIP = New-AzureStackWindowsVM -VMName $VMName -VMNic $result -VMCredential $DomainCredential -ErrorAction Stop

    Log-Finish -LogPath $sLogFile -NoExit $true
}

Function New-AzureStackVnet{
    [CmdletBinding()]
    Param(
    [String]$NetworkIP,
    [String]$ResourceGroupName,
    [String]$VNetName,
    [String]$VMName,
    [String]$Location = "local"
    )

    $Network = & $IpCalc $NetworkIP

    $res = $ResourceGroupName

    # Creating resource names
    $VMNicName = $VMName + "-NIC"
    $nsgName = $VNetName + "-NSG"

    Try {
        $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
        $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name $VMNicName -ErrorAction SilentlyContinue
        $vpn = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $ResourceGroupName -Name "AMSTEL-VPN" -ErrorAction SilentlyContinue
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
    
    Try {

        # Create a vNet
        if(!$vnet){
            $SubnetNetwork = & $IpCalc $Network.HostMin -Netmask 255.255.255.128
            $subnet = New-AzureRmVirtualNetworkSubnetConfig -Name HostSubnet -AddressPrefix $SubnetNetwork.Network
            Log-Write -LogPath $sLogFile -LineValue "Created the host subnet configuration."

            $VpnNetwork = & $IpCalc $Network.HostMax -Netmask 255.255.255.128
            $VPNSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name GatewaySubnet -AddressPrefix $VpnNetwork.Network
            Log-Write -LogPath $sLogFile -LineValue "Created the VPN subnet configuration."

            Log-Write -LogPath $sLogFile -LineValue "Creating the virtual network and its VPN gateway."           
            $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location -Name $VNetName -AddressPrefix $Network.Network -Subnet $subnet,$VPNSubnet
            Log-Write -LogPath $sLogFile -LineValue "Virtual network and VPN gateway was successfully created."

        } else {
            Log-Write -LogPath $sLogFile -LineValue "The virtual network already exists."
        }

        if (!$vpn){
            Log-Write -LogPath $sLogFile -LineValue "Starting VPN infrastucture deployment."
            $VPNSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet

            Log-Write -LogPath $sLogFile -LineValue "Provisioning public ip."
            $pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -AllocationMethod Dynamic -Name "VPNGatewayIP" -Location $Location

            Log-Write -LogPath $sLogFile -LineValue "Creating the VPN gateway ipconfig."
            $VPNIpconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "$($EnvironmentName)-VPN-CFG" -PublicIpAddress $pip -Subnet $VPNSubnet 
            
            Log-Write -LogPath $sLogFile -LineValue "Creating the VPN gateway."                 
            $VirtualGateway = New-AzureRmVirtualNetworkGateway -Name "$($EnvironmentName)-VPN" `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -IpConfigurations $VPNIpconfig `
            -GatewayType Vpn `
            -VpnType RouteBased `
            -GatewaySku Basic

            Log-Write -LogPath $sLogFile -LineValue "Creating local network gateway."
            $LocalGateway = New-AzureRmLocalNetworkGateway -Name "$($EnvironmentName)-GATE" `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -GatewayIpAddress $LocalEndpoint `
            -AddressPrefix $LocalNetwork

            Log-Write -LogPath $sLogFile -LineValue "Creating local-virtual gateway connection."
            $Connection = New-AzureRmVirtualNetworkGatewayConnection -Name "IPsec-Connection" `
            -ResourceGroupName $ResourceGroupName -Location $Location `
            -VirtualNetworkGateway1 $VirtualGateway `
            -LocalNetworkGateway2 $LocalGateway `
            -ConnectionType IPsec `
            -SharedKey "OnlyLettersAndNumbers1"
        } else {
            Log-Write -LogPath $sLogFile -LineValue "The VPN infrastructure already exists."
        }
        
        <# Create an inbound network security group rule for port 3389
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
        } #>

        # Create a virtual network card and associate with public IP address and NSG
        if(!$nic){   
            Log-Write -LogPath $sLogFile -LineValue "Updating the subnet configuration.."
            $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "HostSubnet" -VirtualNetwork $vnet
            Log-Write -LogPath $sLogFile -LineValue "Creating public ip..."
            $pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -AllocationMethod Dynamic -Location $Location -Name "$($VMNicName)-CFG"
            Log-Write -LogPath $sLogFile -LineValue "Creating interface.."
            $nic = New-AzureRmNetworkInterface -ResourceGroupName $res -Location $Location -Name $VMNicName -Subnet $subnet -PublicIpAddress $pip -PrivateIpAddress $Network.Address -ErrorAction Stop
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
    [Parameter(Mandatory=$true)]
    [PSCredential]$VMCredential,
    [String]$DomainName = "amstel.local",
    [Parameter(Mandatory=$true)]
    $VMNic,
    [String]$ResourceGroup = "service-migration-azure",
    [String]$VMSize = "Standard_A1",
    [String]$StorageAccountName = "vhdstorage",
    [String]$Location = "local"
  )
  
  Process{
    Try{

        $Username = $VMCredential.GetNetworkCredential().username
        $Password = $VMCredential.GetNetworkCredential().password
        $SecureString = ConvertTo-SecureString $Password -AsPlainText -Force
        $VMCredential = New-Object System.Management.Automation.PSCredential($Username,$SecureString)

        # Get the VM Image Offer
        $offer = Get-AzureRmVMImageOffer -Location $Location -PublisherName MicrosoftWindowsServer
        Log-Write -LogPath $sLogFile -LineValue "Retrieved the Windows Server VM Image Offer."

        # Get the VM Image SKU
        $sku = Get-AzureRMVMImageSku -Location $Location -PublisherName $offer.PublisherName -Offer $offer.Offer
        Log-Write -LogPath $sLogFile -LineValue "Retrieved the VM Image SKU."

        Try {
            $StorageAccount = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName} -ErrorAction Stop
            Log-Write -LogPath $sLogFile -LineValue "Retrieved the $($StorageAccountName) Storage Account."
        } Catch {
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        } 

        #If the storage account does not exist it will be created.
        if(!$StorageAccount){
                $StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName -Type Standard_LRS -Location $Location
                Log-Write -LogPath $sLogFile -LineValue "Created the $($StorageAccountName) Storage Account."
        }

        $OSDiskName = $VMName + "OSDisk"
        $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"

        # Create a virtual machine configuration
        $vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize | `
        Set-AzureRmVMOperatingSystem -Windows -ComputerName $VMName -Credential $VMCredential | `
        Set-AzureRmVMSourceImage -PublisherName $offer.PublisherName -Offer $offer.Offer -Skus $sku.Skus -Version latest | `
        Set-AzureRmVMOSDisk -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage | `
        Add-AzureRmVMNetworkInterface -Id $VMNic.Id

        Try {
            Log-Write -LogPath $sLogFile -LineValue "Creating the virtual machine..."
            New-AzureRmVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig -Verbose
        } Catch {
            Log-Write -LogPath $sLogFile -LineValue "Could not create VM with the specified configuration."
        }

        Try {
            Log-Write -LogPath $sLogFile -LineValue "Setting the DomainPolicy script extension..."
            Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroup `
            -VMName $VMName `
            -Location $Location `
            -FileUri "https://raw.githubusercontent.com/ebc92/service-migration-azure/develop/Support/Set-DomainPolicy.ps1" `
            -Run 'Set-DomainPolicy.ps1' `
            -Argument "$($DomainName) $($Username) $($Password)" `
            -Name DomainPolicyExtension `
            -ErrorAction Stop
            Log-Write -LogPath $sLogFile -LineValue "Successfully added DomainPolicy ScriptExtension to the provisioned VM."
        } Catch {
            Log-Write -LogPath $sLogFile -LineValue "Could not add TrustedHost DomainPolicy to the provisioned VM."
            Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        }

        do {
            $Extension = Get-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "DomainPolicyExtension"
            Log-Write -LogPath $sLogFile -LineValue "ScriptExtension provisioning state is $($Extension.ProvisioningState)"
            Log-Write -LogPath $sLogFile -LineValue "Sleeping for 60 seconds while waiting for scriptextension..."
            Start-Sleep -Seconds 60
        } while ($Extension.ProvisioningState -ne "Succeeded")

        Restart-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VMName

        $NoConnectivity = $true
        
        Get-AzureRmPublicIpAddress | % {if($_.Id -eq $nic.IpConfigurations.PublicIpAddress.Id){$PublicIP = $_}}
        do {
            try {
                Log-Write -LogPath $sLogFile -LineValue "Trying connection to $($VMName) with $($PublicIP.IpAddress) ..."
                if ($s = New-PSSession -ComputerName $PublicIP.IpAddress -Credential $RemotingCredential -ErrorAction Stop){
                Log-Write -LogPath $sLogFile -LineValue "VM successfully restarted after applying ScriptExtension." 
                Remove-PSSession $s
                $NoConnectivity = $false}
            } catch {
                $RetryTime = 30
                Log-Write -LogPath $sLogFile -LineValue "Cannot establish PowerShell connectivity to the VM. Retrying in $RetryTime seconds."
                Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
                start-sleep -s $RetryTime
            }
        } while ($NoConnectivity)

        return $VMNic.PrivateIPAddress
    
    } Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
  }
  
  End{
    If($?){

      $output = @("Successfully created the VM:",
        "VM Name: $($VMName)",
        "Resource Group: $($ResourceGroup)", 
        "VM Size: $($VMSize)",
        "IP Address: $($VMNic.IpConfigurations.PrivateIPAddress)",
        "VM provisioning script end."
      )

      $output | % {
        Log-Write -LogPath $sLogFile -LineValue $_
      }

    }
  }
}