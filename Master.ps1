<# 
        One script to rule them all                        

              Four::modules
          for:::the::Elven-Kings
       under:the:sky,:Seven:for:the
     Dwarf-Lords::in::their::halls:of
    stone,:Nine             for:Mortal
   :::Men:::     ________     doomed::to
 die.:One   _,-'...:... `-.    for:::the
 ::Dark::  ,- .:::::::::::. `.   Lord::on
his:dark ,'  .:::::zzz:::::.  `.  :throne:
In:::the/    ::::dMMMMMb::::    \ Land::of
:Mordor:\    ::::dMMmgJP::::    / :where::
::the::: '.  '::::YMMMP::::'  ,'  Shadows:
 lie.::One  `. ``:::::::::'' ,'    Ring::to
 ::rule::    `-._```:'''_,-'     ::them::
 all,::One      `-----'        ring::to
   ::find:::                  them,:One
    Ring:::::to            bring::them
      all::and::in:the:darkness:bind
        them:In:the:Land:of:Mordor
           where:::the::Shadows
                :::lie.:::



#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Prefer verbose output
$VerbosePreference = "Continue"

#Dot source dsc, functions, scripts and libraries
$functions = @("Libraries\Test-WsmanSqlConnection.ps1", "Libraries\Manage-Configuration.ps1", "Libraries\Log-Functions.ps1", "MSSQL\DesiredStateSQL.ps1", "ADDC\DesiredStateAD.ps1")
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

#---------------------------------------------------------[Load credentials]--------------------------------------------------------
#The Azure Stack Credential. Azurestack/<AdministratorAccount>
if(!$AzureLocalCredential){
  $AzureLocalCredential = (Get-Credential -Message "Please insert your Local AzureStack Credentials")
}

#The Azure AD Administrator tenant <AdministratorAccount>@<AADDomain>.onmicrosoft.com
if(!$AzureTenantCredential){
  $AzureTenantCredential = (Get-Credential -Message "Please insert your Azure Tenant Credentials")
}

#The Domain Administrator account
if(!$DomainCredential){
    $global:DomainCredential = (Get-Credential -Message "Please insert your domain administrator credentials")
}

#The Local SQL instance account for SQL authentication
if(!$SqlCredential){
    $global:SqlCredential = (Get-Credential -Message "Please insert a password for SQL Authentication")
}

#The local administartor account on the new VMs, can be set to any account
#Remember to note it down in case it is needed in the future
if(!$VMCredential){ #TODO: Pass these to vm provisioning
    $global:VMCredential = (Get-Credential -Message "Please insert a password for the local administrator on the new VMs")
}

#----------------------------------------------------------[Global Declarations]----------------------------------------------------
#Sets the global variables that are used, mostly for logging purposes. Also loads the Configuration.ini file to the $SMAConfig variable
$global:SMAConfig = Get-IniContent -FilePath (Join-Path -Path $PSScriptRoot -ChildPath "Configuration.ini")

$sLogPath = $SMAConfig.Global.logpath
$xLogDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString()
$sLogName = "SMA-Master-$($xLogDate).log"
$global:sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

$environmentname = $SMAConfig.Global.environmentname
$CIDR = "/$($SMAConfig.Global.network.Split("/")[1])"

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion "1.0"

$m = "Starting service migration execution.."
Log-Write -LogPath $sLogFile -LineValue $m
Write-Verbose $m

#Loads all the modules into an array.
$module = @("MSSQL\MSSQL-Migration.psm1", "Support\SMA-Provisioning.psm1", "File-Share\Move-File.psm1", "Exchange\ExchangeMigrate\Exchange-Module.psm1")

#Goes through each module in the array, and then imports it.
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
# Create the Azure Stack PSSession
$AzureStackSession = New-PSSession -ComputerName $SMAConfig.Global.Get_Item('azurestacknat') -Credential $AzureLocalCredential -Port 13389

#Pass the config to the azure stack session
Invoke-Command -Session $AzureStackSession -ScriptBlock {param($SMAConfig)$global:SMAConfig} -ArgumentList $SMAConfig

# Authenticate the session with Azure AD
$Authenticator = Join-Path -Path $PSScriptRoot -ChildPath "\Support\Remote-ARM\Set-ArmCredential.ps1"
& $Authenticator -ARMSession $AzureStackSession -ArmCredential $AzureTenantCredential

#-----------------------------------------------------------[Active Directory]---------------------------------------------------------
$ADDCName = "$($environmentname)-$($SMAConfig.MSSQL.hostname)"
$ADDCDestination = $SMAConfig.MSSQL.destination + $CIDR

#Runs the required script to start the migration of the service and deployment of the new VM
Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName $using:ADDCName -IPAddress $using:ADDCDestination -DomainCredential $using:DomainCredential}
& (Join-Path -Path $PSScriptRoot -ChildPath "\ADDC\ADDC-Migration.ps1")

#-----------------------------------------------------------[File and sharing]---------------------------------------------------------
$FSSName = "$($environmentname)-$($SMAConfig.FSS.hostname)"
$FSSNewIP = $SMAConfig.FSS.newip + $CIDR

#Runs the required script to start the migration of the service and deployment of the new VM
Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName $using:FSSName -IPAddress $using:FSSNewIP -DomainCredential $using:DomainCredential}
& (Join-Path -Path $PSScriptRoot -ChildPath "\File-Share\Migrate-FSS.ps1") $DomainCredential

#-----------------------------------------------------------[SQL Server]---------------------------------------------------------------
$SQLName = "$($environmentname)-$($SMAConfig.MSSQL.hostname)"
$SQLDestination = $SMAConfig.MSSQL.destination + $CIDR

#Runs the required script to start the migration of the service and deployment of the new VM
Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName $using:SQLName -IPAddress $using:SQLDestination -DomainCredential $using:DomainCredential}
& (Join-Path -Path $PSScriptRoot -ChildPath "\MSSQL\MSSQL-Migration.ps1")

#-----------------------------------------------------------[Exchange]-----------------------------------------------------------------
$ExchName = "$($environmentname)-$($SMAConfig.Exchange.hostname)"
$ExchNewIp = $SMAConfig.Exchange.newip + $CIDR

#Runs the required script to start the migration of the service and deployment of the new VM
Invoke-Command -Session $AzureStackSession -ScriptBlock {New-AzureStackTenantDeployment -VMName $using:ExchName -IPAddress $using:ExchNewIp -DomainCredential $using:DomainCredential -VMSize "D4v2"}
& (Join-Path -Path $PSScriptRoot -ChildPath "\Exchange\Migrate-Exchange.ps1") $DomainCredential

#Close the azure stack session & log file
#Remove-PSSession $AzureStackSession
Log-Finish -LogPath $sLogFile -NoExit $true
