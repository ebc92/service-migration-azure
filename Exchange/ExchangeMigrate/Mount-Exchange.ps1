Function Mount-Exchange {
  Param(
    [Parameter(Mandatory=$true)]
    [String]$FileShare,
    [Parameter(Mandatory=$true)]
    [String]$ComputerName,
    [Parameter(Mandatory=$true)]
    [String]$baseDir,
    [Parameter(Mandatory=$true)]
    [pscredential]$DomainCredential
  )
  
  Process{
    Try{  
      $er = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      "$FileShare in local session supposed to be used for mounting image"
      
      Log-Write -LogPath $xLogFile -LineValue "Entering $InstallSession to mount Exchange Disk Image"      
      $ExchangeBinary = Invoke-Command -Session $InstallSession -ScriptBlock {
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $using:baseDir -Persist -Credential $using:DomainCredential -Scope Global -ErrorAction SilentlyContinue -Verbose | Out-Null
        #Do while to make sure correct file is mounted
        $SourceFile = "Z:\executables"
        #Makes sure $ExchangeBinary variable is emtpy       
        $ExchangeBinary = $null
        $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name
        if ($ExchangeBinary -eq $null)
        {    
          Mount-DiskImage -ImagePath (Join-Path -Path $SourceFile -ChildPath ExchangeServer2016-x64-cu5.iso)
          $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name
          $finished = $true
          $ErrorActionPreference = $er
          Return $ExchangeBinary
        }else{
          #donothing
        }
        "$ExchangeBinary after getting diskimage finished"
        $ExchLetter = ( Join-Path -Path $SourceFile -ChildPath ExchangeBinary.txt )
        New-Item -ItemType File -Path $ExchLetter -ErrorAction Ignore
        $ExchangeBinary > $ExchLetter
      }
      Log-Write -LogPath $xLogFile -LineValue "Got Drive Letter $ExchangeBinary"
    }
  
    Catch {
      Log-Error -LogPath $xLogFile -ErrorDesc $_.Exception -ExitGracefully $True      
      Write-Verbose -Message "Removing remote session $InstallSession"
      $InstallSession | Remove-PSSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $xLogFile -LineValue "Mounted ISO successfully."
      Log-Write -LogPath $xLogFile -LineValue "-------------------- Function Mount-Exchange Finished --------------------"
      Write-Verbose -Message "Mounted ISO successfully."
    }
  }
}