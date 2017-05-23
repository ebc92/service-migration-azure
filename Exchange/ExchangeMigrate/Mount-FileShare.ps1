Function Mount-FileShare {
  Param(
    [Parameter(Mandatory=$true)]
    [pscredential]$DomainCredential,
    [Parameter(Mandatory=$true)]
    [String]$ComputerName,
    [Parameter(Mandatory=$true)]
    [String]$baseDir
  )
  
  Process{
    Try{
      #Mounting fileshare to local so that it can be accessed in remote sessions
      #Normally I would set first free driveletter as path, but due to time restriction I went with the last used one.
      
      Log-Write -LogPath $xLogFile -LineValue "Mounting fileshare on $ComputerName"
      Write-Verbose -Message "Mounting fileshare on $ComputerName"      
      Invoke-Command -Session $SourceInstall -ScriptBlock { 
        Write-Verbose -Message "Mounting new PSDrive"
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $using:baseDir -Persist -Credential $using:DomainCredential -Scope Global -ErrorAction SilentlyContinue -Verbose
      }
      
      #Mounts the PSDrive on the target computer
      Invoke-Command -Session $InstallSession -ScriptBlock { 
        Write-Verbose -Message "Mounting new PSDrive"
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $using:baseDir -Persist -Credential $using:DomainCredential -Scope Global -ErrorAction SilentlyContinue -Verbose
      }
    }
    Catch {
      Log-Error -LogPath $xLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      
      #Removes active sessions in case of crash
      $SourceInstall | Remove-PSSession
      $InstallSession | Remove-PSSession
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $xLogFile -LineValue "Mounted file share successfully."
      Log-Write -LogPath $xLogFile -LineValue "-------------------- Function Mount-FileShare Finished --------------------"
      Write-Verbose -Message "Installed prerequisites successfully."
    }
  }
}
