 param (
    $NetBiosDomainName,
    $AdminUser,
    $FqDomainName,
    $GmsaName,
    $FederationName,
    $Description
 )

 #the domain admin and adfs service passwords are encrypted and stored in a local folder
 $LocalPath = "C:\Program Files\WindowsPowerShell\Modules\Certificates\"
 $Key = (7,4,2,3,56,35,254,252,1,9,2,32,42,45,33,233,1,34,123,7,6,53,35,143)

 #decrypt passwords
 $AdminPassword = Convertto-SecureString -String (Get-Content -Path $($LocalPath+"adminpass.key")) -key $key
              
 $Credential = New-Object System.Management.Automation.PSCredential ("$NetBiosDomainName\$AdminUser", $AdminPassword)

 #install the certificate that will be used for ADFS Service
 Import-PfxCertificate -Exportable -Password $AdminPassword -CertStoreLocation cert:\localmachine\my -FilePath $($LocalPath+"adfs_certificate.pfx")
            
 #get thumbprint of certificate
 $cert = Get-ChildItem -Path Cert:\LocalMachine\my | Where-Object{$_.Subject -eq "CN=adfs.contoso.com, OU=Free SSL, OU=Domain Control Validated"}

 #Configure ADFS Farm
 Import-Module ADFS
 
 # Install a new ADFS Farm
 Install-AdfsFarm -CertificateThumbprint $cert.thumbprint -FederationServiceDisplayName $Description -FederationServiceName $FederationName -GroupServiceAccountIdentifier "$NetBiosDomainName\$GmsaName`$" -Credential $Credential -OverwriteConfiguration

 # Initialize device registration service for workplace join 
Initialize-ADDeviceRegistration -ServiceAccountName "$NetBiosDomainName\$GmsaName`$" -DeviceLocation $FqDomainName -RegistrationQuota 10 -MaximumRegistrationInactivityPeriod 90 -Credential $Credential -Force
Enable-AdfsDeviceRegistration -Credential $Credential -Force