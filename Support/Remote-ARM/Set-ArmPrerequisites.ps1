$AzureToolsPath = "C:\AzureStack-Tools-master\"
$Connect = Join-Path -Path $AzureToolsPath -ChildPath "Connect\AzureStack.Connect.psm1"
$ComputeAdmin = Join-Path -Path $AzureToolsPath -ChildPath "ComputeAdmin\AzureStack.ComputeAdmin.psm1"

Import-Module AzureRM.BootStrapper
Import-Module AzureStack -RequiredVersion 1.2.9
Import-Module $Connect, $ComputeAdmin

$profile = get-azurermprofile
if($profile[0] -ne "Profile : 2017-03-09-profile"){
    Use-AzureRmProfile -Profile 2017-03-09-profile
}

Add-AzureStackAzureRmEnvironment -ArmEndpoint https://adminmanagement.local.azurestack.external -Name AzureStackAdmin
