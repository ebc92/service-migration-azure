Param(
    $ARMSession,
    $ARMCredentials
)

#Install modules, set profile, add AzureRmEnvironment
$SetPrerequisites = Join-Path -Path $PSScriptRoot -ChildPath "\Set-ArmPrerequisites.ps1"
invoke-command -Session $ARMSession -FilePath $SetPrerequisites

#Authenticate the session with Azure AD
$ScriptBlock = {
    param($Credential)
    $Context = Get-AzureRMContext
    if($Context.Environment -ne "AzureStackAdmin"){
        Login-AzureRmAccount -EnvironmentName AzureStackAdmin `
        -Credential $Credential
    }
}
invoke-command -Session $ARMSession -ScriptBlock $ScriptBlock -ArgumentList $ARMCredentials

#Import SMA-Provisioning
$SMAProvisioning = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "\..\SMA-Provisioning.psm1")
invoke-command -Session $ARMSession -FilePath $SMAProvisioning