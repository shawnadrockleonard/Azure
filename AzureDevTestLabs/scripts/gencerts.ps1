$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature -Subject "CN=DevTestLabsRoot" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

New-SelfSignedCertificate -Type Custom -DnsName DevTestLabsClient -KeySpec Signature -Subject "CN=DevTestLabsClient" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" -Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

$rootcertificate = get-childitem -path Cert:\CurrentUser\My\ | Where-Object Subject -like '*DevTestLabsRoot*'
Export-Certificate -FilePath '.\DevTestLabsRoot.cer' -Type CERT -Cert $rootcertificate -Force | Out-Null
certutil -encode DevTestLabsRoot.cer DevTestLabsRootBase64.cer


$clientcertificate = get-childitem -path Cert:\CurrentUser\My\ | Where-Object Subject -like '*DevTestLabsClient*'
Export-Certificate -FilePath '.\DevTestLabsClient.cer' -Type CERT -Cert $clientcertificate -Force | Out-Null
certutil -encode DevTestLabsClient.cer DevTestLabsClientBase64.cer


"" | Out-File '.\DevTestLabsRootBase64.txt' -Force
$base64txt = (Get-Content '.\DevTestLabsRootBase64.cer' ) 
$arraybase64 = $base64txt -split "\n"
$base64SingleLineText = (($arraybase64 | Where-Object { $_ -notmatch "CERTIFICATE" }) -join '').trim()
[System.IO.File]::WriteAllText('D:\source\shawniq\azure-devtestlab\scripts\DevTestLabsRootBase64.txt', $base64SingleLineText, [System.Text.Encoding]::ASCII)