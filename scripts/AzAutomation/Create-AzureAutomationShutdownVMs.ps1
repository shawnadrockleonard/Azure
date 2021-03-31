# Creates and configures an Azure Automation account
# Creates and exports the Azure Automation/Management certificate
# Configures the Automation certificate and connection assets
# Creates the Stop-AllVMs and Connect-Azure runbooks (must be in local files)
# Creates the EveryNight schedule and associates it with the Stop-AllVMs runbook

# Note the following:
# - It does not update the management certificate. That must be done in the portal
# - It requires the two runbooks to be in files in the current directory

CLS

Add-AzureAccount

# Name of Azure Automation account
$automationAccountName = '[YOUR-AZURE-AUTOMATION-ACCOUNT-NAME]'

# Location for Automation Account (seems to be a PS bug - since it actually goes in East US 2)
$location = 'East US'

# Name of Azure Automation and Management certificate
$certificateName = 'AzureAutomationPS'

$stopRunbook = 'Stop-AllVMs'
$connectRunbook = 'Connect-Azure'

$scheduleName = 'EveryNight'

$startTime = '9:00:00 PM'

# Set a base path to use for uploading the runbooks
$scriptPath = $MyInvocation.MyCommand.Path
$scriptPath = Split-Path $scriptPath

# Select the appropriate subscription
$subscriptionName = (Get-AzureSubscription).SubscriptionName | Out-GridView -Title "Select Azure Subscription" -PassThru
Select-AzureSubscription -SubscriptionName $subscriptionName

$subscriptionId = (Get-AzureSubscription -Current).SubscriptionId


# Create the Automation/Management certificate and export it in CER and PFX formats
$thumbprint = (New-SelfSignedCertificate -DnsName "$certificateName" -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint

$cert = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)

Export-Certificate -Cert $cert -FilePath "$scriptPath\$certificateName.cer" -Type CERT

$password = Read-Host -Prompt "Please enter the certificate password." -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath "$scriptPath\$certificateName.pfx" -Password $password 



# Create the Automation account
New-AzureAutomationAccount -Name $automationAccountName -Location $location -Verbose


# Upload the Automation certificate
New-AzureAutomationCertificate -AutomationAccountName $automationAccountName -Name $certificateName -Password $password -Path "$certificateName.pfx"


# Create the Automation connection
$connectionFieldValues = @{"AutomationCertificateName" = $certificateName; "SubscriptionID" = $subscriptionId };
New-AzureAutomationConnection -AutomationAccountName $automationAccountName -Name $subscriptionName -ConnectionTypeName 'Azure' -ConnectionFieldValues $connectionFieldValues


# Create, upload and publish the Stop-AllVMs runbook
New-AzureAutomationRunbook -AutomationAccountName $automationAccountName -Path "$scriptPath\$stopRunbook.ps1"
Publish-AzureAutomationRunbook -AutomationAccountName $automationAccountName -Name $stopRunbook


# Create, upload and publish the Connect-Azure runbook
New-AzureAutomationRunbook -AutomationAccountName $automationAccountName -Path "$scriptPath\$connectRunbook.ps1"
Publish-AzureAutomationRunbook -AutomationAccountName $automationAccountName -Name $connectRunbook


# Create the schedule
New-AzureAutomationSchedule -AutomationAccountName $automationAccountName -Name $scheduleName -StartTime $startTime -DayInterval 1

# Connect the schedule to the runbook
Register-AzureAutomationScheduledRunbook -AutomationAccountName $automationAccountName -RunbookName $stopRunbook -ScheduleName $scheduleName
