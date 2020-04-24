# Source Storage Account  
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$jsonDefinition
)
begin
{
	Write-Verbose $PSScriptRoot
	Import-Module -Name AzureCM.Module -NoClobber

# Variables to Seed
    Write-Verbose -Message "[BEGIN] Storage Blob Copy"
}
process
{  
	Start-AzureCMCopyStorageBlobs -jsonDefinition $jsonDefinition
}
end
{
# Variables to Seed
    Write-Verbose -Message "[END] Storage Blob Copy"
	Remove-Module -Name AzureCM.Module
}