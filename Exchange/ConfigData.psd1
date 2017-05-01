@{
  AllNodes = @(
    @{
      NodeName = '*'
      CertificateFile = "C:\tempExchange\Cert\dsccert.cer"
      Thumbprint = "A9481A9AE87145CD8D02B84BB177FF08B64448F9"
    }

    @{
      NodeName = "localhost"
      #PSDscAllowDomainUser = $true
    }
  )
}