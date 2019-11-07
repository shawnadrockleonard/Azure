function Deploy-AzureDevTestLabsEnvironment {
    <#
    .SYNOPSIS
    #
    
    .DESCRIPTION
    Long description
    
    .PARAMETER SubscriptionId
    Parameter description
    
    .PARAMETER LabName
    Parameter description
    
    .PARAMETER RepositoryName
    Parameter description
    
    .PARAMETER TemplateName
    Parameter description
    
    .PARAMETER EnvironmentName
    Parameter description
    
    .PARAMETER Params
    Parameter description
    
    .EXAMPLE
    $subId =  19cb51a1-c197-4d60-bfc2-66978d73c51e
    $labname = "DevTestLab1"
    $resourcegroupname = "DevTestLab"
    $repositoryname = "shawnadrockleonard-azure-devtestlab"
    $TemplateName = "Web App with a hybrid vnet connection"
    $EnvironmentName = "ShawnsEnvTest"
    Deploy-Environment -SubscriptionId $subid -LabName $labname -RepositoryName $repositoryname -TemplateName -param_environment "dev" -param_purpose "ShawnsEnvTestPurpose" -param_virtualNetworkName "shared-vnet" -param_vnetSegmentPrefix "172.10"

    
    .NOTES
    Requires -Module Az.Resources
    #>
    [CmdletBinding()]
    param (
        # ID of the Azure Subscription for the lab
        [string] [Parameter(Mandatory = $true)] $SubscriptionId,

        # Name of the existing lab in which to create the environment
        [string] [Parameter(Mandatory = $true)] $LabName,

        # Name of the connected repository in the lab 
        [string] [Parameter(Mandatory = $true)] $RepositoryName,

        # Name of the template (folder name in the Git repository)
        [string] [Parameter(Mandatory = $true)] $TemplateName,

        # Name of the environment to be created in the lab
        [string] [Parameter(Mandatory = $true)] $EnvironmentName,

        # The parameters to be passed to the template. Each parameter is prefixed with "-param_". 
        # For example, if the template has a parameter named "TestVMName" with a value of "MyVMName", 
        # the string in $Params will have the form: -param_TestVMName MyVMName. 
        # This convention allows the script to dynamically handle different templates.
        [Parameter(ValueFromRemainingArguments = $true)]
        $Params
    )
    PROCESS {
        # Sign in to Azure. 
        # Comment out the following statement to completely automate the environment creation. 
        Connect-AzAccount

        # Select the subscription that has the lab.  
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

        # Get information about the user, specifically the user ID, which is used later in the script.  
        $UserName = (Get-AzContext).Account
        $UserId = $(Get-AzADUser -UserPrincipalName $UserName.Id)

        # Get information about the lab, such as lab location. 
        $lab = Get-AzResource -ResourceType "Microsoft.DevTestLab/labs" -Name $LabName -ResourceGroupName $ResourceGroupName 
        if ($lab -eq $null) { throw "Unable to find lab $LabName in subscription $SubscriptionId." } 

        # Get information about the repository in the lab. 
        $repository = Get-AzResource -ResourceGroupName $lab.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/artifactsources' -ResourceName $LabName -ApiVersion 2016-05-15 `
        | Where-Object { $RepositoryName -in ($_.Name, $_.Properties.displayName) } `
        | Select-Object -First 1

        if ($repository -eq $null) { 
            throw "Unable to find repository $RepositoryName in lab $LabName." 
        } 

        # Get information about the Resource Manager template base for the environment. 
        $template = Get-AzResource -ResourceGroupName $lab.ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs/artifactSources/armTemplates" -ResourceName "$LabName/$($repository.Name)" -ApiVersion 2016-05-15 `
        | Where-Object { $TemplateName -in ($_.Name, $_.Properties.displayName) } `
        | Select-Object -First 1
        if ($template -eq $null) { throw "Unable to find template $TemplateName in lab $LabName." } 

        # Build the template parameters with parameter name and values.  
        $parameters = Get-Member -InputObject $template.Properties.contents.parameters -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $templateParameters = @()

        # Extract the custom parameters from $Params and format as name/value pairs.
        $Params | ForEach-Object {
            if ($_ -match '^-param_(.*)' -and $Matches[1] -in $parameters) {
                $name = $Matches[1]                
            }
            elseif ( $name ) {
                $templateParameters += @{ "name" = "$name"; "value" = "$_" }
                $name = $null #reset name variable
            }
        }

        # Once name/value pairs are isolated, create an object to hold the necessary template properties.
        $templateProperties = @{ "deploymentProperties" = @{ "armTemplateId" = "$($template.ResourceId)"; "parameters" = $templateParameters }; } 

        # Now, create or deploy the environment in the lab by using the New-AzResource command. 
        New-AzResource -Location $Lab.Location `
            -ResourceGroupName $lab.ResourceGroupName `
            -Properties $templateProperties `
            -ResourceType 'Microsoft.DevTestLab/labs/users/environments' `
            -ResourceName "$LabName/$UserId/$EnvironmentName" `
            -ApiVersion '2016-05-15' -Force 

        Write-Output "Environment $EnvironmentName completed."

    }
    END {

    }
}


function Deploy-AzureDevTestLabsCertificates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Provide the literal path to the script directory.")]
        [ValidateScript( { Test-Path $_ -PathType Container })]
        [string]$outputDirectory,

        [Parameter(Mandatory = $false, HelpMessage = "Provide a prefix name for the certificates.")]
        [string]$CertificatePrefix = "DevTestLabs"
    )
    BEGIN {
        # Move to running directory
        $scriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
        if (!(Test-Path -Path $scriptDirectory -PathType 'Container' -ErrorAction SilentlyContinue)) {
            $scriptDirectory = $outputDirectory
        }
        Set-Location $scriptDirectory

        $CertificateRootName = ("{0}Root" -f $CertificatePrefix)
        $CertificateClientName = ("{0}Client" -f $CertificatePrefix)
    }
    PROCESS {

        $cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature -Subject ("CN={0}" -f $CertificateRootName) -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 `
            -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

        New-SelfSignedCertificate -Type Custom -DnsName $CertificateClientName -KeySpec Signature -Subject ("CN={0}" -f $CertificateClientName) -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 `
            -CertStoreLocation "Cert:\CurrentUser\My" -Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

        # Generate Root Certificates
        $rootcertificate = get-childitem -path Cert:\CurrentUser\My\ | Where-Object Subject -like ('*{0}*' -f $CertificateRootName)
        Export-Certificate -FilePath (".\{0}.cer" -f $CertificateRootName) -Type CERT -Cert $rootcertificate -Force | Out-Null
        $CertificateRootBaseName = ("{0}Base64.cer" -f $CertificateRootName)
        certutil -encode (".\{0}.cer" -f $CertificateRootName) $CertificateRootBaseName

        # Generate Client Certificates from Root
        $clientcertificate = get-childitem -path Cert:\CurrentUser\My\ | Where-Object Subject -like ('*{0}*' -f $CertificateClientName)
        Export-Certificate -FilePath (".\{0}.cer" -f $CertificateClientName) -Type CERT -Cert $clientcertificate -Force | Out-Null
        $CertificateClientBaseName = ("{0}Base64.cer" -f $CertificateClientName)
        certutil -encode (".\{0}.cer" -f $CertificateClientName) $CertificateClientBaseName

        # Export Base64 to use in Azure Portal
        $CertificateRootBaseNameTxt = ("{0}Base64.txt" -f $CertificateRootName)
        $outputbase64 = Join-Path -Path $scriptDirectory -ChildPath ('{0}Base64.txt' -f $CertificateRootName)
        "" | Out-File ('.\{0}' -f $CertificateRootBaseNameTxt) -Force
        $base64txt = (Get-Content ('.\{0}' -f $CertificateRootBaseName)) 
        $arraybase64 = $base64txt -split "\n"
        $base64SingleLineText = (($arraybase64 | Where-Object { $_ -notmatch "CERTIFICATE" }) -join '').trim()
        [System.IO.File]::WriteAllText($outputbase64, $base64SingleLineText, [System.Text.Encoding]::ASCII)


    }
}