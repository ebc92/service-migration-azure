<# 
        One script to rule them all 

               Three::modules
          for:::the::Elven-Kings
       under:the:sky,:Seven:for:the
     Dwarf-Lords::in::their::halls:of
    stone,:Nine             for:Mortal
    :::Men:::     ________     doomed::to
    die.:One   _,-'...:... `-.    for:::the
    ::Dark::  ,- .:::::::::::. `.   Lord::on
    his:dark ,'  .:::::zzz:::::.  `.  :throne::
    In:::the/    ::::dMMMMMb::::    \ Land::of:
    :Mordor:\    ::::dMMmgJP::::    / :where::::
    ::the::: '.  '::::YMMMP::::'  ,'   Shadows:
    lie.::One `. ``:::::::::'' ,'    :Script:
    to:rule:    `-._```:'''_,-'     ::them::
    all,::One      `-----'        Script:to
    ::find:::                  them,:One
    Script:::to            bring::them
      all::and::in:the:darkness:bind
        them:In:the:Land:of:Mordor
           where:::the::Shadows
                :::lie.:::

    Credential-list
    *AzureLocalCredential
    *AzureTenantCredential
    *DomainCredential
    *LocalCredential (VMCredential)

#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Prefer verbose output
$VerbosePreference = "Continue"

#Dot source dsc, functions, scripts and libraries
$functions = @("Support\Get-GredentialObject.ps1", "Libraries\Manage-Configuration.ps1", "Libraries\Log-Functions.ps1", "MSSQL\DesiredStateSQL.ps1", "ADDC\DesiredStateAD.ps1")
$functions | % {
    Try {
        $path = Join-Path -Path $PSScriptRoot -ChildPath $_
        . $path -ErrorAction Stop
        $m = "Successfully sourced $($_)"
        Write-Verbose $m
    } Catch {
        Write-Verbose $_.Exception
    }
}
if(!$DomainCredential){
    $DomainCredential = (Get-Credential -Message "Please insert your domain administrator credentials")
}
if(!$DomainCredential){
    $SqlCredential = (Get-Credential -Message "Please insert a password for SQL Authentication")
}
#$AzureLocalCredential = (Get-Credential -Message "Please insert your Local AzureStack Credentials")
#$AzureTenantCredential = (Get-Credential -Message "Please insert your Azure Tenant Credentials")

#$LocalCredential = (Get-Credential -Message "Please insert a password for the local administrator on the new VMs")


#----------------------------------------------------------[Global Declarations]----------------------------------------------------------

$global:SMAConfig = Get-IniContent -FilePath (Join-Path -Path $PSScriptRoot -ChildPath "Configuration.ini")

$sLogPath = $SMAConfig.Global.logpath
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$sLogName = "SMA-Master-$($xLogDate).log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

$environmentname = $SMAConfig.Global.environmentname
$CIDR = "/$($SMAConfig.Global.network.Split("/")[1])"

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion "1.0"

$m = "Starting service migration execution.."
Log-Write -LogPath $sLogFile -LineValue $m
Write-Verbose $m

$module = @("ADDC\ADDC-Migration.psm1", "MSSQL\MSSQL-Migration.psm1", "Support\SMA-Provisioning.psm1", "File-Share\FSS-Migration.psm1")

$module | % {
    Try {
        Import-Module (Join-Path -Path $PSScriptRoot -ChildPath $_) -Force -ErrorAction Stop
        $m = "Successfully imported $($_)"
        Log-Write -LogPath $sLogFile -LineValue $m
        Write-Verbose $m
    } Catch {
        Write-Verbose $_.Exception
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
}
#-----------------------------------------------------------[Azure Stack]---------------------------------------------------------
<# Create the Azure Stack PSSession
$AzureStackSession = New-PSSession -ComputerName $SMAConfig.Global.Get_Item('azurestacknat') -Credential $AzureLocalCredential -Port 13389

#Pass the config to the azure stack session
Invoke-Command -Session $AzureStackSession -ScriptBlock {param($SMAConfig)$global:SMAConfig} -ArgumentList $SMAConfig

# Authenticate the session with Azure AD
$Authenticator = Join-Path -Path $PSScriptRoot -ChildPath "\Support\Remote-ARM\Set-ArmCredential.ps1"
& $Authenticator -ARMSession $AzureStackSession -ArmCredential $AzureTenantCredential
#>

#-----------------------------------------------------------[Active Directory]---------------------------------------------------------

#& (Join-Path -Path $PSScriptRoot -ChildPath "\ADDC\ADDC-Migration.ps1")
#Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName "TEST2" -IPAddress "192.168.59.14/24" -DomainCredential $DomainCredential}

#-----------------------------------------------------------[SQL Server]---------------------------------------------------------------
$Name = "$($environmentname)-$($SMAConfig.MSSQL.hostname)"
$Destination = $SMAConfig.MSSQL.destination + $CIDR

#Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName $using:Name -IPAddress $using:Destination -DomainCredential $using:DomainCredential}
& (Join-Path -Path $PSScriptRoot -ChildPath "\MSSQL\MSSQL-Migration.ps1")

#-----------------------------------------------------------[File and sharing]---------------------------------------------------------

#& (Join-Path -Path $PSScriptRoot -ChildPath "\File-Share\FSS-Migration.ps1")

#-----------------------------------------------------------[Exchange]-----------------------------------------------------------------
$ExchName = "$($environmentname)-$($SMAConfig.Exchange.hostname)"

#Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName $using:ExchName -IPAddress "192.168.59.116/24" -DomainCredential $using:DomainCredential}
#& (Join-Path -Path $PSScriptRoot -ChildPath "\Exchange\Migrate-Exchange.ps1 $DomainCredential")

#Close the azure stack session & log file
#Remove-PSSession $AzureStackSession
Log-Finish -LogPath $sLogFile -NoExit $true
