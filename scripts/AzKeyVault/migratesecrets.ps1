<#
.DESCRIPTION
    Writes key vault secrets, expires to the output window.
    You can then take the output and run it in a new terminal window connected to the destination subscription.

.EXAMPLE
    .\scripts\AzKeyVault\migratesecrets.ps1 -OldKeyVaultName "spl-kv-usgov" -NewKeyVaultName "spl-kv-cus"

#>

[cmdletbinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OldKeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$NewKeyVaultName,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
)
PROCESS {
    $kv = Get-AzKeyVault -VaultName $OldKeyVaultName
    Get-AzKeyVaultSecret -VaultName $kv.VaultName | ForEach-Object {
        $keyvaultsecret = $_
        $secretname = $keyvaultsecret.Name
        $secretexpires = $keyvaultsecret.Expires
        $secretcontenttype = $keyvaultsecret.ContentType
        $secret = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name $secretname -AsPlainText

        if ($null -ne $secretexpires) {
            Write-Host "Set-AzKeyVaultSecret -VaultName ""$NewKeyVaultName"" -Name ""$secretname"" -ContentType ""$secretcontenttype"" -SecretValue (ConvertTo-SecureString -String ""$secret"" -AsPlainText) -Expires ""$secretexpires"""
        }
        else {
            Write-Host "Set-AzKeyVaultSecret -VaultName ""$NewKeyVaultName"" -Name ""$secretname"" -ContentType ""$secretcontenttype"" -SecretValue (ConvertTo-SecureString -String ""$secret"" -AsPlainText)"
        }
    }
}