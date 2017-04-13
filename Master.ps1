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

#Set Error Action to stop so that exceptions can be caught
$ErrorActionPreference = "Stop"

$VerbosePreference = "Continue"

#Dot source dsc, functions, scripts and libraries
$functions = @("Support\Get-GredentialObject.ps1", "Libraries\Log-Functions.ps1", "Support\Start-RebootCheck.ps1", "Support\DSC\InstallADDC.ps1")
$functions | % {
    Try {
        $path = Join-Path -Path $PSScriptRoot -ChildPath $_
        . $path
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

$module = @("ADDC\ADDC-Migration.psm1", "MSSQL\MSSQL-Migration.psm1", "File-Share\FSS-Migration.psm1", "Exchange\Exchange-Migration.psm1")

$module | % {
    Try {
        Import-Module (Join-Path -Path $PSScriptRoot -ChildPath $_) -Force
        $m = "Successfully imported $($_)"
        Log-Write -LogPath $sLogFile -LineValue $m
        Write-Verbose $m
    } Catch {
        Write-Verbose $_.Exception
        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $False
    }
}
#Install PSGET
#(new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex

Function Migrate-AD {
    Param($Credentials)
    
    $target = "192.168.58.114"
    Invoke-Command -ComputerName $target -Credential $cred -ScriptBlock {Install-Module xDSCDomainjoin, xPendingReboot, xActiveDirectory }

    $cd = @{
        AllNodes = @(
            @{
                NodeName = "192.168.58.114"
                PSDscAllowDomainUser = $true
                PSDscAllowPlainTextPassword = $true
            }
        )        
    }

    InstallADDC -ConfigurationData $cd -DNS 192.168.58.113 -DomainName AMSTEL -DomainCredentials $Credentials -SafeModeCredentials $Credentials
}
Migrate-AD -Credentials $cred