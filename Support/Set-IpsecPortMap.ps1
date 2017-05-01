Param(
    $ExternalIP, 
    $InternalIP
)

Add-NetNatExternalAddress -NatName BGPNAT -IPAddress $ExternalIP -PortStart 500 -PortEnd 4500
Add-NetNatStaticMapping -NatName BGPNAT -ExternalIPAddress $ExternalIP -ExternalPort 500 -InternalIPAddress $InternalIP -InternalPort 500 -Protocol UDP
Add-NetNatStaticMapping -NatName BGPNAT -ExternalIPAddress $ExternalIP -ExternalPort 4500 -InternalIPAddress $InternalIP -InternalPort 4500 -Protocol UDP