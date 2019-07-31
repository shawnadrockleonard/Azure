Function UpdateADFSMetadata {
    param(
        [Parameter(Mandatory = $true)]
        $FSUrl,
        [Parameter(Mandatory = $true)]
        $StsName,
        [switch] $DryRun
    )
	
    $metadataUrl = "https://$FSUrl/federationmetadata/2007-06/federationmetadata.xml"

    try {
        [xml]$metadataDoc = (Invoke-WebRequest $metadataUrl).Content
    }
    catch {
        Write-Error "There was an error downloading the metadata: $($_)"
        return
    }

    $adfsSTS = Get-SPTrustedIdentityTokenIssuer $StsName -ErrorAction SilentlyContinue -ErrorVariable "myErrors"
    if ($myErrors -ne $null) {
        $msg = $myErrors[0].Exception.Message
        Write-Error "Could not get the ADFS STS in SharePoint: $msg"
        return
    }

    $newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $enc = [System.Text.Encoding]::UTF8

    $sts = $metadataDoc.EntityDescriptor.RoleDescriptor | where { $_.type -eq "fed:SecurityTokenServiceType" }

    # How many signing certs?
    $signCount = ($sts.KeyDescriptor | ? { $_.use -eq "signing" } | measure).count
    if ($signCount -eq 1) {
        $certB64 = $sts.KeyDescriptor.KeyInfo.X509Data.X509Certificate
        $newCert.Import($enc.GetBytes($certB64))
        Write-Host "Only one ADFS Signing cert:" $newCert.Subject
    }
    else {
        $certB64 = $sts.KeyDescriptor[0].KeyInfo.X509Data.X509Certificate
        $certB64 = $metadataDoc.EntityDescriptor.Signature.KeyInfo.X509Data.X509Certificate
        $newCert.Import($enc.GetBytes($certB64))
        Write-Host "Primary ADFS Signing cert:" $newCert.Subject
    }

    if ($newCert.Thumbprint -ne $null -and -not $adfsSTS.SigningCertificate.Equals($newCert)) {
        # Do we need to add the new cert as CA in SharePoint?
        if ((Get-SPTrustedRootAuthority | ? { $_.Certificate.Thumbprint -eq $newCert.Thumbprint }) -eq $null) {
            Write-Host "Adding the ADFS cert" $newCert.Subject "to the SharePoint trust store"
            If ($DryRun) {
                Write-Warning "DryRun: not adding the certificate"
            }
            Else {
                New-SPTrustedRootAuthority -Name $newCert.Subject -Certificate $newCert
            }
        }
        else {
            Write-Warning "NOT adding the ADFS cert $($newCert.Subject) to the SharePoint trust store because it is already there"
        }
		
        # Set the cert in the STS
        Write-Host "Setting the certificate in the ADFS STS"
        If ($DryRun) {
            Write-Warning "DryRun: not changing the certificate in the STS"
        }
        Else {
            $adfsSTS | Set-SPTrustedIdentityTokenIssuer -ImportTrustCertificate $newCert
        }
    }
    else {
        Write-Warning "The ADFS primary certificate is already the same as in the SharePoint ADFS STS"
    }
}

# Example
# UpdateADFSMetadata -FSUrl "fs.test.local" -StsName "ADFS" -DryRun
