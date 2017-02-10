<#

#>

param(
)

Function Deploy-FileShare {
Process {
Install-WindowsFeature -Name "FileAndStorage-Services" -IncludeAllSubFeature
}
End {
}
}