<#
.NOTES

.EXAMPLE
    $credentials = Get-Credential
    $ResourceGroup = "<automation resource group name>"
    $AutomationAccountName = "<automation name>"
    $SubscriptionId = "<subscription id>"
    $ApplicationDisplayName = "<app name>"
    $EnterpriseCertPathForRunAsAccount = '.\san-client-automation.pfx'

    .\Reservation\createrunas.ps1 -ResourceGroup $ResourceGroup `
        -AutomationAccountName $AutomationAccountName `
        -SubscriptionId $SubscriptionId `
        -ApplicationDisplayName $ApplicationDisplayName  `
        -EnterpriseCertPathForRunAsAccount $EnterpriseCertPathForRunAsAccount  `
        -EnterpriseCertPlainPasswordForRunAsAccount $credentials.Password

    
#>
Param (
    [Parameter(Mandatory = $false, ParameterSetName = "cacert")]
    [Parameter(Mandatory = $false, ParameterSetName = "selfcert")]
    [ValidateSet("AzureCloud", "AzureUSGovernment")]
    [string]$EnvironmentName = "AzureUSGovernment",

    [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
    [Parameter(Mandatory = $true, ParameterSetName = "selfcert")]
    [String] $ResourceGroup,

    [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
    [Parameter(Mandatory = $true, ParameterSetName = "selfcert")]
    [String] $AutomationAccountName,

    [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
    [Parameter(Mandatory = $true, ParameterSetName = "selfcert")]
    [String] $ApplicationDisplayName,

    [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
    [Parameter(Mandatory = $true, ParameterSetName = "selfcert")]
    [String] $SubscriptionId,

    [Parameter(Mandatory = $false, ParameterSetName = "cacert")]
    [Parameter(Mandatory = $false, ParameterSetName = "selfcert")]
    [Switch] $CreateClassicRunAsAccount,

    [Parameter(Mandatory = $true, ParameterSetName = "selfcert")]
    [SecureString] $SelfSignedCertPlainPassword,

    [Parameter(Mandatory = $true, ParameterSetName = "selfcert")]
    [int] $SelfSignedCertNoOfMonthsUntilExpired = 12,

    [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
    [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
    [string] $EnterpriseCertPathForRunAsAccount,

    [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
    [SecureString] $EnterpriseCertPlainPasswordForRunAsAccount,

    [Parameter(Mandatory = $false, ParameterSetName = "cacert")]
    [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
    [String] $EnterpriseCertPathForClassicRunAsAccount,

    [Parameter(Mandatory = $false, ParameterSetName = "cacert")]
    [SecureString] $EnterpriseCertPlainPasswordForClassicRunAsAccount
)
BEGIN
{
    function CreateSelfSignedCertificate(
        [string] $certificateName, 
        [SecureString] $selfSignedCertPlainPassword,
        [string] $certPath, 
        [string] $certPathCer, 
        [string] $selfSignedCertNoOfMonthsUntilExpired 
    )
    {
        $Cert = New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation cert:\LocalMachine\My -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter (Get-Date).AddMonths($selfSignedCertNoOfMonthsUntilExpired) -HashAlgorithm SHA256
        Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPath -Password $selfSignedCertPlainPassword -Force | Write-Verbose
        Export-Certificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPathCer -Type CERT | Write-Verbose
    }	

    function CreateServicePrincipal 
    {
        [cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/AzAutomation/readme.md")]
        param(
            [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
            [System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert, 
            [Parameter(Mandatory = $true, ParameterSetName = "cacert")]
            [string] $applicationDisplayName
        )
        PROCESS
        {
            $Application = Get-AzADApplication -DisplayName $ApplicationDisplayName -ErrorAction SilentlyContinue
            if ($null -eq $ApplicationDisplayName)
            {

                $keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
                $keyId = (New-Guid).Guid
                # Create an Azure AD application, AD App Credential, AD ServicePrincipal
                # Requires Application Developer Role, but works with Application administrator or GLOBAL ADMIN
                $Application = New-AzADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $applicationDisplayName) -IdentifierUris ("http://" + $keyId)
                # Requires Application administrator or GLOBAL ADMIN
                $ApplicationCredential = New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $keyValue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter
                # Requires Application administrator or GLOBAL ADMIN
                $ServicePrincipal = New-AzADServicePrincipal -ApplicationId $Application.ApplicationId
                $GetServicePrincipal = Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id
                if ($null -eq $GetServicePrincipal)
                {
                    throw "Failed to create service principal for $($Application.ApplicationId)"
                }
            }  

            $AzRole = Get-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
            if ($null -eq $AzRole)
            {
                # Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
                Start-Sleep -s 15
                # Requires User Access Administrator or Owner.
                $NewRole = New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
                $Retries = 0;
                While ($null -eq $NewRole -and $Retries -le 6)
                {
                    Start-Sleep -s 10
                    New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
                    $NewRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
                    $Retries++;
                }
            }
        }
        END
        {
            return $Application.ApplicationId.ToString();
        }
    }

    function CreateAutomationCertificateAsset ([string] $resourceGroup, [string] $AutomationAccountName, [string] $certifcateAssetName, [string] $certPath, [SecureString] $CertPassword, [Boolean] $Exportable)
    {
        Remove-AzAutomationCertificate -ResourceGroupName $resourceGroup -AutomationAccountName $AutomationAccountName -Name $certifcateAssetName -ErrorAction SilentlyContinue
        New-AzAutomationCertificate -ResourceGroupName $resourceGroup -AutomationAccountName $AutomationAccountName -Path $certPath -Name $certifcateAssetName -Password $CertPassword -Exportable:$Exportable | write-verbose
    }	
    
    function CreateAutomationConnectionAsset ([string] $resourceGroup, [string] $AutomationAccountName, [string] $connectionAssetName, [string] $connectionTypeName, [System.Collections.Hashtable] $connectionFieldValues )
    {
        Remove-AzAutomationConnection -ResourceGroupName $resourceGroup -AutomationAccountName $AutomationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
        New-AzAutomationConnection -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues
    }	
}
PROCESS
{
    #To install the latest version of Azure PowerShell, see https://docs.microsoft.com/powershell/azure/install-az-ps. 
    #To learn about about using Az modules in your Automation account see https://docs.microsoft.com/azure/automation/shared-resources/modules.

    Import-Module Az.Automation
    Enable-AzureRmAlias
    Connect-AzAccount -Environment $EnvironmentName
    $Subscription = Get-AzSubscription -SubscriptionId $SubscriptionId | Set-AzContext 

    # Create a Run As account by using a service principal
    $CertifcateAssetName = "AzureRunAsCertificate"
    $ConnectionAssetName = "AzureRunAsConnection"
    $ConnectionTypeName = "AzureServicePrincipal"
    if ($EnterpriseCertPathForRunAsAccount -and $EnterpriseCertPlainPasswordForRunAsAccount)
    {
        $PfxCertPathForRunAsAccount = $EnterpriseCertPathForRunAsAccount
        $PfxCertPlainPasswordForRunAsAccount = $EnterpriseCertPlainPasswordForRunAsAccount
    }
    else
    {
        $CertificateName = $AutomationAccountName + $CertifcateAssetName
        $PfxCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".pfx")
        $PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
        $CerCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".cer")
        CreateSelfSignedCertificate $CertificateName $PfxCertPlainPasswordForRunAsAccount $PfxCertPathForRunAsAccount $CerCertPathForRunAsAccount  $SelfSignedCertNoOfMonthsUntilExpired
    }

    # Create a service principal
    $PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)
    $ApplicationId = CreateServicePrincipal $PfxCert $ApplicationDisplayName

    # Create the Automation certificate asset
    CreateAutomationCertificateAsset $ResourceGroup $AutomationAccountName $CertifcateAssetName $PfxCertPathForRunAsAccount  $PfxCertPlainPasswordForRunAsAccount $true

    # Populate the ConnectionFieldValues
    $SubscriptionInfo = Get-AzSubscription -SubscriptionId $SubscriptionId
    $TenantID = $SubscriptionInfo | Select TenantId -First 1
    $Thumbprint = $PfxCert.Thumbprint
    $ConnectionFieldValues = @{"ApplicationId" = $ApplicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId }

    # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
    CreateAutomationConnectionAsset $ResourceGroup $AutomationAccountName $ConnectionAssetName $ConnectionTypeName $ConnectionFieldValues	
    if ($CreateClassicRunAsAccount)
    {
        # Create a Run As account by using a service principal
        $ClassicRunAsAccountCertifcateAssetName = "AzureClassicRunAsCertificate"
        $ClassicRunAsAccountConnectionAssetName = "AzureClassicRunAsConnection"
        $ClassicRunAsAccountConnectionTypeName = "AzureClassicCertificate "
        $UploadMessage = "Please upload the .cer format of #CERT# to the Management store by following the steps below." + [Environment]::NewLine +	
        "Log in to the Microsoft Azure portal (https://portal.azure.com) and select Subscriptions -> Management Certificates." + [Environment]::NewLine +
        "Then click Upload and upload the .cer format of #CERT#"
        if ($EnterpriseCertPathForClassicRunAsAccount -and $EnterpriseCertPlainPasswordForClassicRunAsAccount )
        {
            $PfxCertPathForClassicRunAsAccount = $EnterpriseCertPathForClassicRunAsAccount
            $PfxCertPlainPasswordForClassicRunAsAccount = $EnterpriseCertPlainPasswordForClassicRunAsAccount
            $UploadMessage = $UploadMessage.Replace("#CERT#", $PfxCertPathForClassicRunAsAccount)
        }
        else
        {
            $ClassicRunAsAccountCertificateName = $AutomationAccountName + $ClassicRunAsAccountCertifcateAssetName
            $PfxCertPathForClassicRunAsAccount = Join-Path $env:TEMP ($ClassicRunAsAccountCertificateName + ".pfx")
            $PfxCertPlainPasswordForClassicRunAsAccount = $SelfSignedCertPlainPassword
            $CerCertPathForClassicRunAsAccount = Join-Path $env:TEMP ($ClassicRunAsAccountCertificateName + ".cer")
            $UploadMessage = $UploadMessage.Replace("#CERT#", $CerCertPathForClassicRunAsAccount)
            CreateSelfSignedCertificate $ClassicRunAsAccountCertificateName $PfxCertPlainPasswordForClassicRunAsAccount  $PfxCertPathForClassicRunAsAccount $CerCertPathForClassicRunAsAccount $SelfSignedCertNoOfMonthsUntilExpired
        }	

        # Create the Automation certificate asset
        CreateAutomationCertificateAsset $ResourceGroup $AutomationAccountName $ClassicRunAsAccountCertifcateAssetName $PfxCertPathForClassicRunAsAccount $PfxCertPlainPasswordForClassicRunAsAccount $false
    
        # Populate the ConnectionFieldValues
        $SubscriptionName = $subscription.Name
        $ClassicRunAsAccountConnectionFieldValues = @{"SubscriptionName" = $SubscriptionName; "SubscriptionId" = $SubscriptionId; "CertificateAssetName" = $ClassicRunAsAccountCertifcateAssetName }
    
        # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
        CreateAutomationConnectionAsset $ResourceGroup $AutomationAccountName $ClassicRunAsAccountConnectionAssetName $ClassicRunAsAccountConnectionTypeName $ClassicRunAsAccountConnectionFieldValues
        Write-Host -ForegroundColor red $UploadMessage
    }
}