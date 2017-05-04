#Requires -version 4.0
######################################################
#########################\O/##########################
##   ______          _                              ##
##  |  ____|        | |                             ##
##  | |__  __  _____| |__   __ _ _ __   __ _  ___   ##
##  |  __| \ \/ / __| '_ \ / _` | '_ \ / _` |/ _ \  ##
##  | |____ >  < (__| | | | (_| | | | | (_| |  __/  ##
##  |______/_/\_\___|_| |_|\__,_|_| |_|\__, |\___|  ##
##                                      __/ |       ##
##                                     |___/        ##
######################################################
######################################################

<#
    .SYNOPSIS
    <Overview of script>

    .DESCRIPTION
    <Brief description of script>

    .PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

    .INPUTS
    <Inputs if any, otherwise state None>

    .OUTPUTS
    <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

    .NOTES
    Version:        1.0
    Author:         Nikolai Thingnes Leira & Emil Claussen
    Creation Date:  24.02.2017
    Purpose/Change: Set structure of script
  
    .EXAMPLE
    <Example goes here. Repeat this attribute for more than one example>
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'

#Define all variables during testing, remove for production
$baseDir = Read-Host -Prompt "Please input the filepath for the file share: "
$ComputerName = "amstel-mail"
$fileshare = "$baseDir\executables"
$verifyPath = Test-Path -Path $fileshare
$DomainCredential = Get-Credential
$InstallSession = New-PSSession -ComputerName $ComputerName -Credential $DomainCredential
#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'
#Log File Info
$logDate = (Get-Date -Format dd_M_yyyy_HHmm).ToString() 
$sLogPath = "$baseDir\log\"
$sLogName = "Migrate-Exchange-$logDate.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#Dot Source required Function Libraries    
$DotPath = Resolve-Path "$PSScriptRoot\..\Libraries\Log-Functions.ps1"
. $DotPath

$ExchangeBinary = $null

#Checking if executables already exist
$UCMAExist = Test-Path "$fileshare\UcmaRuntimeSetup.exe"

$ExchangeExist = Test-Path -Path "$fileshare\ExchangeServer2016-x64-cu5.iso"

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function Get-Prerequisite {
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$fileShare,
    [parameter(Mandatory=$true)]
    [string]$ComputerName,
    [parameter(Mandatory=$true)]
    [PSCredential]$DomainCredential
  )
  
  Begin{
    $variableOutput = '        $fileShare ' + "= $fileShare `n"`
    +'        $tarComp ' + "= $ComputerName `n"`
    +'        $DomainCredential ' + "= $DomainCredential"
    Log-Write -LogPath $sLogFile -LineValue "Downloading prerequisites for Microsoft Exchange 2016..."
    Log-Write -LogPath $sLogFile -LineValue "The following variables are set for $MyInvocation.MyCommand.Name:"
    Log-Write -LogPath $sLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      #Checking package provider list for NuGet
      $nuget = Invoke-Command -Session $InstallSession -ScriptBlock { 
        $nuget = Get-PackageProvider | Where-Object -Property Name -eq nuget
        Return $nuget 
      }
      
     
      #Creating the required folders if they do not exist 
      if (!($verifyPath)) {
        New-Item -ItemType Directory -Path "$fileshare" > $null
        Write-Verbose -Message "Path not found, created required path on $fileshare" 
        Log-Write -LogPath $sLogFile -LineValue "Path not found, created required path on $fileshare"
      } else {
        Write-Verbose -Message "Path found on $fileshare"
        Log-Write -LogPath $sLogFile -LineValue "Path found on $fileShare"
      }
      
      #Checking if NuGet is in the package provider list, and installing it if it's not
      if (!($nuget)) {
        Write-Verbose -Message "NuGet not installed, installing now..."
        Log-Write -LogPath $sLogFile -LineValue "Nuget not installed, installing now..."
        Invoke-Command -Session $InstallSession -ScriptBlock { 
          Install-PackageProvider -Name NuGet -Force
        }
      } else {
        Write-Verbose -Message "NuGet already installed, continuing prerequisite checks"
        Log-Write -LogPath $sLogFile -LineValue "NuGet already installed, continuing prerequisite checks"
      }    
      
      if (!($UCMAExist)) {
        #Downloading UCMA 4.0 Runtime      
        Write-Verbose -Message "Starting download of UCMA Runtime 4.0"
        Log-Write -LogPath $sLogFile -LineValue "Starting download of UCMA Runtime 4.0"

        Start-BitsTransfer -Source https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe -Destination $fileshare -Description 'Downloading prerequisites'
        Write-Verbose -Message "Downloading file from https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe to $fileShare"
        Log-Write -LogPath $sLogFile -LineValue "Downloading file from https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe to $fileShare"
        Write-Verbose -Message "UCMA successfully downloaded"
        Log-Write -LogPath $sLogFile -LineValue "UCMA successfully downloaded"
      }else{
        #UCMA already exist, no need to download
        Write-Verbose -Message "UCMA already exist, no need to download"
        Log-Write -LogPath $sLogFile -LineValue "UCMA already exist, no need to download"
      }

      if (!($ExchangeExist)) {
        #Downloading Exchange 2016
        #Write-Verbose -Message "Starting download of Exchange 2016 CU5"
        Log-Write -LogPath $sLogFile -LineValue "Starting download of Exchange 2016 CU5"
        Write-Verbose -Message "Downloading file from https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso to $fileShare"
        Log-Write -LogPath $sLogFile -LineValue "Downloading file from https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso to $fileShare"
        Start-BitsTransfer -Source https://download.microsoft.com/download/A/A/7/AA7F69B2-9E25-4073-8945-E4B16E827B7A/ExchangeServer2016-x64-cu5.iso -Destination $fileshare -Description 'Downloading prerequisites'
        Write-Verbose -Message "Exchange 2016 successfully downloaded"
        Log-Write -LogPath $sLogFile -LineValue "Exchange 2016 successfully downloaded"
      }else{
        #Exchange ISO already exists, no need to download
        Write-Verbose -Message "Exchange ISO already exists, no need to download"
        Log-Write -LogPath $sLogFile -LineValue "Exchange ISO already exists, no need to download"
      }
    }
         
    Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Got all prerequisites successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
      Write-Verbose -Message 'Got all prerequisites successfully.'
    }
  }
}

#Mounts Exchange 2016 image from share
Function Mount-Exchange {
  Param(
    [Parameter(Mandatory=$true)]
    [String]$FileShare,
    [Parameter(Mandatory=$true)]
    [String]$ComputerName
  )
  
  [bool]$finished=$false
  $er = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
    
  $ExchangeBinary = Invoke-Command -Session $InstallSession -ScriptBlock { 
    #Makes sure $ExchangeBinary variable is emtpy
    
    $ExchangeBinary = $null

    $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name

    if ($ExchangeBinary -eq $null)
    {
      Do {
        Try {          
          Mount-DiskImage -ImagePath (Join-Path -Path $using:FilesShare -ChildPath ExchangeServer2016-x64-cu5.iso)
          $finished = $true
          $ErrorActionPreference = $er
          Return $ExchangeBinary
        }
        Catch {
          $SourceFile = Read-Host(`
          "The path $FileShare does not contain the ISO file, please enter the correct path for the Exchange 2016 ISO Image folder")
          $finished = $false
        }
      }
      While ($finished -eq $false)
    }
    Return $ExchangeBinary  
  }
  "$ExchangeBinary after getting diskimage finished"
  $ExchLetter = ( Join-Path -Path $FileShare -ChildPath ExchangeBinary.txt )
  New-Item -ItemType File -Path $ExchLetter -ErrorAction Ignore
  $ExchangeBinary > $ExchLetter  
}



Function New-DSCCertificate {
  [CmdletBinding()]
  Param(
    [string]$ComputerName,
    [pscredential]$DomainCredential
  )
  Invoke-Command  -Session $InstallSession -ScriptBlock {
    [bool]$createcert = $false
    "$createcert as it is at start of running cert creation"
    #Function to create certificate gotten from 
    #https://github.com/adbertram/Random-PowerShell-Work/blob/master/Security/New-SelfSignedCertificateEx.ps1
    Function New-SelfSignedCertificateEx
    {
      [CmdletBinding(DefaultParameterSetName = 'Store')]
      param
      (
        [Parameter(Mandatory, Position = 0)]
        [string]$Subject,
		
        [Parameter(Position = 1)]
        [DateTime]$NotBefore = [DateTime]::Now.AddDays(-1),
		
        [Parameter(Position = 2)]
        [DateTime]$NotAfter = $NotBefore.AddDays(365),
		
        [string]$SerialNumber,
		
        [Alias('CSP')]
        [string]$ProviderName = 'Microsoft Enhanced Cryptographic Provider v1.0',
		
        [string]$AlgorithmName = 'RSA',
		
        [int]$KeyLength = 2048,
		
        [ValidateSet('Exchange', 'Signature')]
        [string]$KeySpec = 'Exchange',
		
        [Alias('EKU')]
        [Security.Cryptography.Oid[]]$EnhancedKeyUsage,
		
        [Alias('KU')]
        [Security.Cryptography.X509Certificates.X509KeyUsageFlags]$KeyUsage,
		
        [Alias('SAN')]
        [String[]]$SubjectAlternativeName,
		
        [bool]$IsCA,
		
        [int]$PathLength = -1,
		
        [Security.Cryptography.X509Certificates.X509ExtensionCollection]$CustomExtension,
		
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$SignatureAlgorithm = 'SHA1',
		
        [string]$FriendlyName,
		
        [Parameter(ParameterSetName = 'Store')]
        [Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation = 'CurrentUser',
		
        [Parameter(ParameterSetName = 'Store')]
        [Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',
		
        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Alias('OutFile', 'OutPath', 'Out')]
        [IO.FileInfo]$Path,
		
        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Security.SecureString]$Password,
		
        [switch]$AllowSMIME,
		
        [switch]$Exportable,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru
      )
	
      $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop;
	
      # Ensure we are running on a supported platform.
      if ([Environment]::OSVersion.Version.Major -lt 6)
      {
        throw (New-Object NotSupportedException -ArgumentList 'Windows XP and Windows Server 2003 are not supported!');
      }
	
      #region Constants
	
      #region Contexts
      New-Variable -Name UserContext -Value 0x1 -Option Constant;
      New-Variable -Name MachineContext -Value 0x2 -Option Constant;
      #endregion Contexts
	
      #region Encoding
      New-Variable -Name Base64Header -Value 0x0 -Option Constant;
      New-Variable -Name Base64 -Value 0x1 -Option Constant;
      New-Variable -Name Binary -Value 0x3 -Option Constant;
      New-Variable -Name Base64RequestHeader -Value 0x4 -Option Constant;
      #endregion Encoding
	
      #region SANs
      New-Variable -Name OtherName -Value 0x1 -Option Constant;
      New-Variable -Name RFC822Name -Value 0x2 -Option Constant;
      New-Variable -Name DNSName -Value 0x3 -Option Constant;
      New-Variable -Name DirectoryName -Value 0x5 -Option Constant;
      New-Variable -Name URL -Value 0x7 -Option Constant;
      New-Variable -Name IPAddress -Value 0x8 -Option Constant;
      New-Variable -Name RegisteredID -Value 0x9 -Option Constant;
      New-Variable -Name Guid -Value 0xa -Option Constant;
      New-Variable -Name UPN -Value 0xb -Option Constant;
      #endregion SANs
	
      #region Installation options
      New-Variable -Name AllowNone -Value 0x0 -Option Constant;
      New-Variable -Name AllowNoOutstandingRequest -Value 0x1 -Option Constant;
      New-Variable -Name AllowUntrustedCertificate -Value 0x2 -Option Constant;
      New-Variable -Name AllowUntrustedRoot -Value 0x4 -Option Constant;
      #endregion Installation options
	
      #region PFX export options
      New-Variable -Name PFXExportEEOnly -Value 0x0 -Option Constant;
      New-Variable -Name PFXExportChainNoRoot -Value 0x1 -Option Constant;
      New-Variable -Name PFXExportChainWithRoot -Value 0x2 -Option Constant;
      #endregion PFX export options
	
      #endregion Constants
	
      #region Subject processing
      # http://msdn.microsoft.com/en-us/library/aa377051(VS.85).aspx
      $subjectDN = New-Object -ComObject X509Enrollment.CX500DistinguishedName;
      $subjectDN.Encode($Subject, 0x0);
      #endregion Subject processing
	
      #region Extensions
	
      # Array of extensions to add to the certificate.
      $extensionsToAdd = @();
	
      #region Enhanced Key Usages processing
      if ($EnhancedKeyUsage)
      {
        $oIDs = New-Object -ComObject X509Enrollment.CObjectIDs;
        $EnhancedKeyUsage | ForEach-Object {
          $oID = New-Object -ComObject X509Enrollment.CObjectID;
          $oID.InitializeFromValue($_.Value);
			
          # http://msdn.microsoft.com/en-us/library/aa376785(VS.85).aspx
          $oIDs.Add($oID);
        }
		
        # http://msdn.microsoft.com/en-us/library/aa378132(VS.85).aspx
        $eku = New-Object -ComObject X509Enrollment.CX509ExtensionEnhancedKeyUsage;
        $eku.InitializeEncode($oIDs);
        $extensionsToAdd += 'EKU';
      }
      #endregion Enhanced Key Usages processing
	
      #region Key Usages processing
      if ($KeyUsage -ne $null)
      {
        $ku = New-Object -ComObject X509Enrollment.CX509ExtensionKeyUsage;
        $ku.InitializeEncode([int]$KeyUsage);
        $ku.Critical = $true;
        $extensionsToAdd += 'KU';
      }
      #endregion Key Usages processing
	
      #region Basic Constraints processing
      if ($PSBoundParameters.Keys.Contains('IsCA'))
      {
        # http://msdn.microsoft.com/en-us/library/aa378108(v=vs.85).aspx
        $basicConstraints = New-Object -ComObject X509Enrollment.CX509ExtensionBasicConstraints;
        if (!$IsCA)
        {
          $PathLength = -1;
        }
        $basicConstraints.InitializeEncode($IsCA, $PathLength);
        $basicConstraints.Critical = $IsCA;
        $extensionsToAdd += 'BasicConstraints';
      }
      #endregion Basic Constraints processing
	
      #region SAN processing
      if ($SubjectAlternativeName)
      {
        $san = New-Object -ComObject X509Enrollment.CX509ExtensionAlternativeNames;
        $names = New-Object -ComObject X509Enrollment.CAlternativeNames;
        foreach ($altName in $SubjectAlternativeName)
        {
          $name = New-Object -ComObject X509Enrollment.CAlternativeName;
          if ($altName.Contains('@'))
          {
            $name.InitializeFromString($RFC822Name, $altName);
          }
          else
          {
            try
            {
              $bytes = [Net.IPAddress]::Parse($altName).GetAddressBytes();
              $name.InitializeFromRawData($IPAddress, $Base64, [Convert]::ToBase64String($bytes));
            }
            catch
            {
              try
              {
                $bytes = [Guid]::Parse($altName).ToByteArray();
                $name.InitializeFromRawData($Guid, $Base64, [Convert]::ToBase64String($bytes));
              }
              catch
              {
                try
                {
                  $bytes = ([Security.Cryptography.X509Certificates.X500DistinguishedName]$altName).RawData;
                  $name.InitializeFromRawData($DirectoryName, $Base64, [Convert]::ToBase64String($bytes));
                }
                catch
                {
                  $name.InitializeFromString($DNSName, $altName);
                }
              }
            }
          }
          $names.Add($name);
        }
        $san.InitializeEncode($names);
        $extensionsToAdd += 'SAN';
      }
      #endregion SAN processing
	
      #region Custom Extensions
      if ($CustomExtension)
      {
        $count = 0;
        foreach ($ext in $CustomExtension)
        {
          # http://msdn.microsoft.com/en-us/library/aa378077(v=vs.85).aspx
          $extension = New-Object -ComObject X509Enrollment.CX509Extension;
          $extensionOID = New-Object -ComObject X509Enrollment.CObjectId;
          $extensionOID.InitializeFromValue($ext.Oid.Value);
          $extensionValue = [Convert]::ToBase64String($ext.RawData);
          $extension.Initialize($extensionOID, $Base64, $extensionValue);
          $extension.Critical = $ext.Critical;
          New-Variable -Name ('ext' + $count) -Value $extension;
          $extensionsToAdd += ('ext' + $count);
          $count++;
        }
      }
      #endregion Custom Extensions
	
      #endregion Extensions
	
      #region Private Key
      # http://msdn.microsoft.com/en-us/library/aa378921(VS.85).aspx
      $privateKey = New-Object -ComObject X509Enrollment.CX509PrivateKey;
      $privateKey.ProviderName = $ProviderName;
      $algorithmID = New-Object -ComObject X509Enrollment.CObjectId;
      $algorithmID.InitializeFromValue(([Security.Cryptography.Oid]$AlgorithmName).Value);
      $privateKey.Algorithm = $algorithmID;
	
      # http://msdn.microsoft.com/en-us/library/aa379409(VS.85).aspx
      $privateKey.KeySpec = switch ($KeySpec) { 'Exchange' { 1 }; 'Signature' { 2 } }
      $privateKey.Length = $KeyLength;
	
      # Key will be stored in current user certificate store.
      switch ($PSCmdlet.ParameterSetName)
      {
        'Store'
        {
          $privateKey.MachineContext = if ($StoreLocation -eq 'LocalMachine') { $true }
          else { $false }
        }
        'File'
        {
          $privateKey.MachineContext = $false;
        }
      }
	
      $privateKey.ExportPolicy = if ($Exportable) { 1 }
      else { 0 }
      $privateKey.Create();
      #endregion Private Key
	
      #region Build certificate request template
	
      # http://msdn.microsoft.com/en-us/library/aa377124(VS.85).aspx
      $cert = New-Object -ComObject X509Enrollment.CX509CertificateRequestCertificate;
	
      # Initialize private key in the proper store.
      if ($privateKey.MachineContext)
      {
        $cert.InitializeFromPrivateKey($MachineContext, $privateKey, '');
      }
      else
      {
        $cert.InitializeFromPrivateKey($UserContext, $privateKey, '');
      }
	
      $cert.Subject = $subjectDN;
      $cert.Issuer = $cert.Subject;
      $cert.NotBefore = $NotBefore;
      $cert.NotAfter = $NotAfter;
	
      #region Add extensions to the certificate
      foreach ($item in $extensionsToAdd)
      {
        $cert.X509Extensions.Add((Get-Variable -Name $item -ValueOnly));
      }
      #endregion Add extensions to the certificate
	
      if (![string]::IsNullOrEmpty($SerialNumber))
      {
        if ($SerialNumber -match '[^0-9a-fA-F]')
        {
          throw 'Invalid serial number specified.';
        }
		
        if ($SerialNumber.Length % 2)
        {
          $SerialNumber = '0' + $SerialNumber;
        }
		
        $bytes = $SerialNumber -split '(.{2})' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) }
        $byteString = [Convert]::ToBase64String($bytes);
        $cert.SerialNumber.InvokeSet($byteString, 1);
      }
	
      if ($AllowSMIME)
      {
        $cert.SmimeCapabilities = $true;
      }
	
      $signatureOID = New-Object -ComObject X509Enrollment.CObjectId;
      $signatureOID.InitializeFromValue(([Security.Cryptography.Oid]$SignatureAlgorithm).Value);
      $cert.SignatureInformation.HashAlgorithm = $signatureOID;
      #endregion Build certificate request template
	
      # Encode the certificate.
      $cert.Encode();
	
      #region Create certificate request and install certificate in the proper store
      # Interface: http://msdn.microsoft.com/en-us/library/aa377809(VS.85).aspx
      $request = New-Object -ComObject X509Enrollment.CX509enrollment;
      $request.InitializeFromRequest($cert);
      $request.CertificateFriendlyName = $FriendlyName;
      $endCert = $request.CreateRequest($Base64);
      $request.InstallResponse($AllowUntrustedCertificate, $endCert, $Base64, '');
      #endregion Create certificate request and install certificate in the proper store
	
      #region Export to PFX if specified
      if ($PSCmdlet.ParameterSetName.Equals('File'))
      {
        $PFXString = $request.CreatePFX(
          [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)),
          $PFXExportEEOnly,
          $Base64
        )
        Set-Content -Path $Path -Value ([Convert]::FromBase64String($PFXString)) -Encoding Byte;
      }
      #endregion Export to PFX if specified
	
      if ($PassThru.IsPresent)
      {
        @(Get-ChildItem -Path "Cert:\$StoreLocation\$StoreName").where({ $_.Subject -match $Subject })
      }
	
      $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue;
    }
    #Checks if the certificate used already exists
    
    $certverifypath = [bool](dir cert:\LocalMachine\My\ | Where-Object { $_.subject -like "cn=$using:ComputerName-dsccert" })
    if(!($certverifypath)) {
      New-SelfSignedCertificateEx `
      -Subject "CN=$using:ComputerName-dsccert" `
      -EKU 'Document Encryption' `
      -KeyUsage 'KeyEncipherment, DataEncipherment' `
      -SAN localhost `
      -FriendlyName 'DSC certificate' `
      -Exportable `
      -StoreLocation "LocalMachine" `
      -StoreName 'My' `
      -KeyLength 2048 `
      -ProviderName 'Microsoft Enhanced Cryptographic Provider v1.0' `
      -AlgorithmName 'RSA' `
      -SignatureAlgorithm 'SHA256' `
      -Verbose
      "Created cert and moving on CN=$using:computername-dsccert"
      $createcert = $true
    }else{
      Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.subject -like "cn=$using:ComputerName-dsccert" } | Remove-Item
      "$createcert where the cert was deleted"        
      New-SelfSignedCertificateEx `
      -Subject "CN=$using:ComputerName" `
      -EKU 'Document Encryption' `
      -KeyUsage 'KeyEncipherment, DataEncipherment' `
      -SAN localhost `
      -FriendlyName 'DSC certificate' `
      -Exportable `
      -StoreLocation "LocalMachine" `
      -StoreName 'My' `
      -KeyLength 2048 `
      -ProviderName 'Microsoft Enhanced Cryptographic Provider v1.0' `
      -AlgorithmName 'RSA' `
      -SignatureAlgorithm 'SHA256' `
      -Verbose
      "Created cert and moving on CN=$using:computername-dsccert"
      Write-Verbose -Message "Certificate already exists, moving on"
      $createcert = $false
    }     
  }
}


Function Install-Prerequisite {
  [CmdletBinding()]
  Param(
    [parameter(Mandatory=$true)]
    [string]$baseDir,
    [parameter(Mandatory=$true)]
    [string]$ComputerName,
    [parameter(Mandatory=$true)]
    [PSCredential]$DomainCredential
  )
  
  Begin{
    $variableOutput = '        $fileShare ' + "= $fileShare"
    Log-Write -LogPath $sLogFile -LineValue 'Installing prerequisites for Microsoft Exchange 2013...'
    Log-Write -LogPath $sLogFile -LineValue "The following variables are set for $MyInvocation.MyCommand.Name :"
    Log-Write -LogPath $sLogFile -LineValue "$variableOutput"
  }
  
  Process{
    Try{
      $CertPW = Read-Host -Prompt "Please input a password for the certificate: " -AsSecureString
      $VerbosePreference = "Continue"
      $Domain = "Amstel"
      $CertExportPath = "C:\Cert\dsccert.cer"
      $ExchangeBinary = (Get-WmiObject win32_volume | Where-Object -Property Label -eq "EXCHANGESERVER2016-X64-CU5").Name
      
      
      Invoke-Command -Session $InstallSession -ScriptBlock {      
        #Check to see if certificate directory exists, and creates it if not
        $VerifyCertPath = (Test-Path -Path "C:\Cert\")
        if (!($VerifyCertPath)){
          Write-Verbose -Message "Creating folder for certificate"    
          New-Item -Path "C:\Cert" -ItemType Directory -ErrorAction Ignore
        }
      }
      
      $CertThumb = Invoke-Command -Session $InstallSession -ScriptBlock { 
        Write-Verbose -Message "Getting Certificate Thumbprint"
        #Get Certificate thumbprint
        $CertThumb = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$using:ComputerName-dsccert"}).Thumbprint
        $CertThumb
      }

      $CertThumb
      Invoke-Command -Session $InstallSession -ScriptBlock {
        $VerbosePreference = 'Continue'
        #Exporting Certificate            
        Write-Verbose -Message "Exporting cert to $using:CertExportPath"
        Write-Verbose -Message "Mounting new PSDrive"
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $using:baseDir -Persist -Credential $using:DomainCredential -ErrorAction Continue -Verbose
      
        $CertTargetPath = Join-Path -Path Cert:\LocalMachine\My -ChildPath $using:CertThumb
        $CertExport = (Get-ChildItem -Path $CertTargetPath)
      
        Export-Certificate -Cert $CertExport -FilePath $using:CertExportPath -Type CERT
        $CertExport | Export-PfxCertificate -FilePath Z:\Cert\cert.pfx -Password $using:CertPW
        
        #Move Exchange install files
        New-Item -ItemType Directory -Path "C:\TempExchange" -ErrorAction Ignore
        Write-Verbose -Message "Moving Exchange ISO from share, to local storage"
        Start-BitsTransfer -Source "Z:\Executables\EXCHANGESERVER2016-X64-CU5.iso" -Destination "C:\TempExchange\" -Credential $using:DomainCredential
        Write-Verbose -Message "Exchange ISO successfully moved to C:\TempExchange\"
      
        #Check if xExchange is installed
        $DSCResource = Get-DscResource -Name xExchange
        if($DSCResource -eq $null) {
          #Install modules
          Install-Module -Name xExchange, xPendingReboot -Force -Verbose
        }
        
        #Test-path to see if UCMA is installed
        $ucmatest = Test-Path -Path "C:\Program Files\Microsoft UCMA 4.0"
        
        if(!($ucmatest)) {
          #InstallUCMA
          Write-Verbose -Message "Starting Install of UCMA"
          Start-Process -FilePath "Z:\Executables\UcmaRuntimeSetup.exe" -ArgumentList '/passive /norestart' -NoNewWindow -Wait -Verbose
          Write-Verbose -Message "UCMA Installed, starting DSC"
        }
      }
      Write-Verbose -Message "Removing remote session $InstallSession"
      $InstallSession | Remove-PSSession
      
      Write-Verbose -Message "Importing PFX certificate"
      Import-PfxCertificate -FilePath "$baseDir\Cert\cert.pfx" -CertStoreLocation Cert:\LocalMachine\My\ -Password $CertPW -Verbose
      #$CertLocalExport = (Get-ChildItem -Path "Cert:\LocalMachine\My\$CertThumb")
      
      $ComputerName
      $CertThumb
      
      $CertPath = Join-Path -Path Cert:\LocalMachine\My -ChildPath $CertThumb
      $CertPath
      Export-Certificate -Cert $CertPath -FilePath $CertExportPath -Type CERT -Verbose
      
      $DSCResource = Get-DscResource -Name xExchange
      if($DSCResource -eq $null) {
        #Install modules
        Install-Module -Name xExchange, xPendingReboot -Force -Verbose
      }
      $DSC = Resolve-Path -Path $PSScriptRoot\InstallExchange.ps1
      . $DSC
      
      $CertThumb
      $ComputerName
      #Configuration data for DSC
      $ConfigData=@{
        AllNodes = @(
          @{
            NodeName = '*'
            CertificateFile = "C:\Cert\dsccert.cer"
          }

          @{
            NodeName = $ComputerName
            Thumbprint = $CertThumb
            PSDscAllowDomainUser = $true
          }
        )
      }
      
      Start-Transcript -Path ( Join-Path -Path $sLogPath -ChildPath dsclog-$logDate.txt )
      $ExchangeBinary = Get-Content -Path ( Join-Path $baseDir -ChildPath Executables\ExchangeBinary.txt )
      "$ExchangeBinary before compiling DSC script"
                  
      Write-Verbose -Message "Compiling DSC script"
      #Compiles DSC Script
      InstallExchange -ConfigurationData $ConfigData -DomainCredential $DomainCredential -ExchangeBinary $ExchangeBinary -Verbose

      Write-Verbose -Message "Setting up LCM on target computer"
      #Sets up LCM on target comp
      Set-DscLocalConfigurationManager -Path $PSScriptRoot\InstallExchange -Force -Verbose

      Write-Verbose -Message "Pushing DSC script to target computer"
      #Pushes DSC script to target
      Start-DscConfiguration -Path $PSScriptRoot\InstallExchange -Force -Verbose -Wait
      
      Stop-Transcript
      
      <#     Foreach($element in $InstallFiles) {
          $i++
          Write-Progress -Activity 'Installing prerequisites for Exchange 2016' -Status "Currently installing file $i of $total"`
          -PercentComplete (($i / $total) * 100)          Write-Verbose -Message "Installing file $i of $total"          Write-Verbose -Message "Installing $element.name"          Log-Write -LogPath $sLogPath -LineValue "Installing file $i of $total"          Log-Write -LogPath $sLogPath -LineValue "Installing $element.name"          Invoke-Command -ComputerName $tarComp -DomainCredentialential $DomainDomainCredentialential -ScriptBlock {
          Start-Process -FilePath $element.FullName -ArgumentList '/passive /norestart' -Wait
          }
      }#>
    }
       
    Catch {
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Installed prerequisites successfully."
      Write-Verbose -Message "Installed prerequisites successfully."
    }
  }
}
<#Function Migrate-Transport {
    [CmdletBinding()]
    Param(
    )
  
    Begin{
    Log-Write -LogPath $sLogFile -LineValue '<Write what happens>...'
    }
  
    Process{
    Try{
     
    }      
    Catch {
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
} #>

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
$i = 0

#Temporary to run commands during test environment

Get-Prerequisite -fileShare $fileshare -ComputerName amstel-mail -DomainCredential $DomainCredential -Verbose

Mount-Exchange -FileShare $fileshare -ComputerName amstel-mail -Verbose

New-DSCCertificate -ComputerName amstel-mail -Verbose

Install-Prerequisite -BaseDir $baseDir -ComputerName amstel-mail -DomainCredential $DomainCredential -Verbose

Log-Finish -LogPath $sLogFile