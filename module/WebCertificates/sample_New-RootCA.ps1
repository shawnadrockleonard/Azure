#.Synopsis
#   Generate a self-signed root certificate and then generate an SSL certificate signed by it.
#.Description
#   Generates a self-signed root certificate and an SSL certificate signed by it.
#   Puts the root public key in a .pem file for adding to PHP's CAcert.pem
param(
    # Used as the CN for the Root certificate
    $RootName = "NO LIABILITY ACCEPTED - Test Root $(get-date -f "yyyy-MM-dd")",
    # Used as the CN for the SSL certificate
    $Subject = "${Env:ComputerName}.${Env:UserDnsDomain}",
    # Where to put exported certificate files
    $OutputPath = $Pwd
)

$Certificate = @{
    Extension =[System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($true, $true, 0, $true)
    Subject =  "CN=$RootName"
    NotAfter = (Get-Date).AddYears(2)
    KeyUsage = "CertSign"
    KeyExportPolicy = "NonExportable"
}

# Note: the current defaults for New-SelfSignedCertificate are 2048 bit RSA keys with SHA256 -- if they change them, it'll be to stronger options, so let's accept the defaults for now
$Root = New-SelfSignedCertificate @Certificate
$Cert = New-SelfSignedCertificate -Signer $Root -Subject "CN=$Subject" -NotAfter ((Get-Date).AddYears(1))

# Now put the root into trusted root
Move-Item (Join-Path Cert:\LocalMachine\My $Root.Thumbprint) -Destination Cert:\LocalMachine\Root

# Output the root public key
$RootPem = Join-Path $OutputPath "TrustedRoot.pem"
"-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String( $Root.RawData, "InsertLineBreaks" ) + "-----END CERTIFICATE-----" | Out-File -FilePath $RootPem -Encoding ascii
Get-Item $RootPem

# Output the whole private key
if($Env:USERDOMAIN -eq $DomainName) {
    Export-PfxCertificate $Cert -FilePath (Join-Path $OutputPath "$Subject.pfx") -ProtectTo Administrators
} else {
    Export-PfxCertificate $Cert -FilePath (Join-Path $OutputPath "$Subject.pfx") -Password (Read-Host "Certificate Password" -AsSecureString)
}