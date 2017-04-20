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
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Prefer verbose output
$VerbosePreference = "Continue"

#Dot source dsc, functions, scripts and libraries
$functions = @("Support\Get-GredentialObject.ps1", "Libraries\Log-Functions.ps1", "Support\Start-RebootCheck.ps1", "ADDC\DesiredStateAD.ps1")
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

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$sScriptVersion = "1.0"
$sLogPath = "C:\Logs"
$sLogName = "service-migration-azure.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

$m = "Starting service migration execution.."
Log-Write -LogPath $sLogFile -LineValue $m
Write-Verbose $m

$module = @("ADDC\ADDC-Migration.psm1", "MSSQL\MSSQL-Migration.psm1", "Support\SMA-Provisioning.psm1", "File-Share\FSS-Migration.psm1", "Exchange\Exchange-Migration.psm1")

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

#-----------------------------------------------------------[Active Directory]---------------------------------------------------------

$ComputerName = "192.168.59.113"
$VMName = "AMSTEL-AD"
$DSCDocument = Join-Path -Path $PSScriptRoot -ChildPath "\DesiredStateAD"

$ADScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "\ADDC\ADDC-Migration.ps1"
& $ADScriptPath -ComputerName $ComputerName -VMName $VMName -DSCDocument $DSCDocument

#-----------------------------------------------------------[SQL Server]---------------------------------------------------------------
<#
$ComputerName = "158.38.43.114"
$Source = "158.38.43.113"
$PackagePath = "\\158.38.43.116\share\MSSQL"
$InstanceName = "AMSTELSQL"
$Credential = (Get-Credential)
$SqlCredential = (Get-Credential)

$SQLScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "\MSSQL\MSSQL-Migration.ps1"
& $SQLScriptPath -ComputerName $ComputerName -Source $Source -PackagePath $PackagePath -InstanceName $InstanceName -Credential $Credential -SqlCredential $SqlCredential
#>
#-----------------------------------------------------------[File and sharing]---------------------------------------------------------

#-----------------------------------------------------------[Exchange]-----------------------------------------------------------------