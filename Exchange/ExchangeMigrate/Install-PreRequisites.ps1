Function Install-PreRequisites{
  Param()
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }
  
  Process{
    Try{
      if (Test-path(!("\\$fileshare\ExchangeInstall"))) {
        mkdir \\$fileshare\ExchangeInstall
        "Path not found, created required path"
      } else {
        "Path found, continuing migration"
        }
      
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}