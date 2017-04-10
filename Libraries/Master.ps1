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
write-output "running"
#Set error action to stop so that exceptions can be caught
$ErrorActionPreference = "Stop"

#Dot source external libraries and required scripts
$CredObj = Join-Path -Path $PSScriptRoot -ChildPath "Support\Get-GredentialObject.ps1"
$LogLib = Join-Path -Path $PSScriptRoot -ChildPath "Libraries\Log-Functions.ps1"
$IpCalc = Join-Path -Path $PSScriptRoot -ChildPath "Libraries\ipcalculator.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$sScriptVersion = "1.0"
$sLogPath = "C:\Logs\service-migration-azure"
$sLogName = "service-migration-azure.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Execution]------------------------------------------------------------



Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

$m = "Starting SMA master script.."
Log-Write -LogPath $sLogFile -LineValue $m
Write-Verbose -Message $m

$m = "Importing modules.."
Log-Write -LogPath $sLogFile -LineValue $m
Write-Verbose -Message $m

$m = "Failed to import "

$modules = @("ADDC\ADDC-Migration.psm1", "MSSQL\MSSQL-Migration.psm1", "File-Share\FSS-Migration.psm1", "Exchange\Exchange-Migration.psm1")
$modules | % { 
    Try { 
        Import-Module (Join-Path -Path $PSScriptRoot -ChildPath $_) -Force 
    } Catch {
        Log-Error -LogPath $sLogFile -ErrorDesc $m + $_ -ExitGracefully $False
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
        Write-Verbose -Message $m + $_
    }
} 