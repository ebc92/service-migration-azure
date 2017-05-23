# Defines a path to the AzureStack Tools
$AzureToolsPath = "C:\AzureStack-Tools-master\"
$Connect = Join-Path -Path $AzureToolsPath -ChildPath "Connect\AzureStack.Connect.psm1"
$ComputeAdmin = Join-Path -Path $AzureToolsPath -ChildPath "ComputeAdmin\AzureStack.ComputeAdmin.psm1"
# Check if present
if(!(Test-Path AzureToolsPath)){
    Write-Output "AzureStack Tools could not be found on C:\"
    break
}

# Import the modules and version specific for TP3
Import-Module AzureRM.BootStrapper
Import-Module AzureStack -RequiredVersion 1.2.9
Import-Module $Connect, $ComputeAdmin

# Load the profile
$profile = get-azurermprofile
if($profile[0] -ne "Profile : 2017-03-09-profile"){
    Use-AzureRmProfile -Profile 2017-03-09-profile
}

# Add Azure Stack environment to the context
Add-AzureStackAzureRmEnvironment -ArmEndpoint https://adminmanagement.local.azurestack.external -Name AzureStackAdmin
