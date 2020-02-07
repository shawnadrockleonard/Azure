[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)]
    [ValidateSet('AzureCloud', 'AzureUSGovernment')]
    [string]$environment,

    [Parameter(Mandatory = $True)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $False)]
    [string]$KeyVaultSecretName = "UserCertificates--PEM"
)
BEGIN {
    $AzModuleVersion = "2.8.0"

    #******************************************************************************
    # Script body
    # Execution begins here
    #******************************************************************************
    $ErrorActionPreference = "Stop"

    # Verify that the Az module is installed 
    if (!(Get-InstalledModule -Name Az -MinimumVersion $AzModuleVersion -ErrorAction SilentlyContinue)) {
        Write-Host "This script requires to have Az Module version $AzModuleVersion installed..
It was not found, please install from: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
        exit
    } 

    if (!(Get-InstalledModule -name Az.KeyVault -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Az.KeyVault"
        Find-Module Az.KeyVault | Install-Module -Scope CurrentUser
    }
}
PROCESS {
    Connect-AzAccount -Environment $environment
    Get-AzKeyVault -VaultName $KeyVaultName
    $userPEM = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultSecretName

    $UTF8String = $userPEM.SecretValueText
    $Base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UTF8String))
    $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($Base64))
    $Cert.publickey.key.exportparameters($False) 
    $Cert.PrivateKey.KeyExchangeAlgorithm
    $cert.PublicKey.Key
    $cert.Subject
}