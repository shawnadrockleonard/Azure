[CmdletBinding(HelpURI = 'http://aka.ms/automate')]
param
(
	[Parameter(Mandatory = $true)]
	[string]$subId,

	[Parameter(Mandatory = $false)]
	[ValidateSet("East US", "USGov Virginia", "USGov Iowa")]
	[string]$locationRegion = "East US",

	[Parameter(Mandatory = $false)]
	[string]$vnet = "shared-vnet",

	[Parameter(Mandatory = $false)]
	[ValidateSet("AzureUSGovernment", "AzureChinaCloud", "AzureCloud")]
	[string]$azureEnvironment = "AzureUSGovernment"
)
begin {
	Write-Verbose $PSScriptRoot
	$path = ("..\AzureCM.Automation.psm1")
	Import-Module -Name $path -NoClobber
	Import-Module -Name AzureCM.Module -NoClobber
	Import-Module -Name AzureRM.Profile -NoClobber
}
process {

	$credential = Get-Credential -Message "Provide your domain credentials" -UserName "contoso\adminleonard"

	Add-AzAccount -Environment $azureEnvironment
	Select-AzSubscription -SubscriptionId $subId

	$location = (Get-AzLocation | Where-Object DisplayName -eq ('{0}' -f $locationRegion)).Name

	$vms = Get-Content .\AzureProvisionVM.json -Raw | ConvertFrom-Json
	Foreach ($vm in $vms | Sort-Object isdc -Descending) {
		New-AzureCMVirtualMachine -vm $vm -vmLocation $location -azureEnvironment $azureEnvironment -vnet $vnet -credentials $credential -subscriptionId $subId
	}
}
end {
	Remove-Module -Name AzureCM.Automation
}