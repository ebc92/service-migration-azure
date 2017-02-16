<#$regnames = Get-ChildItem -path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ | ForEach-Object {Get-ItemProperty -propertytype multistring}
foreach($element in $regnames) {
write-host("$element")
} #>

$regnames = Get-Item -path Registry::hklm\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares\ | Select-Object -ExpandProperty Property
if ($regnames -is [System.Array]) {write-host("wrusk") } else { write-host("Nowurk")}