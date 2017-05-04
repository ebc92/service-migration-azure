Param(
    $ARMSession,
    $ARMCredential
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
        -Credential $Credential `
        -ErrorAction SilentlyContinue
    }
}
invoke-command -Session $ARMSession -ScriptBlock $ScriptBlock -ArgumentList $ARMCredential

#Import SMA-Provisioning
$SMAInstaller = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "\..\Install-SMModule.ps1")
invoke-command -Session $ARMSession -FilePath $SMAInstaller