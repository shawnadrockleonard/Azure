<# 
    Upload-VirtualDisk
    .SYNOPSIS
        Source Storage Account    
    .DESCRIPTION
        Uploads a VHD file into a storage URI container
    .EXAMPLE
        UPload-VirtualDisk -StorageName "storage" -DiskName "disk.vhd" -LiteralPath "c:\temp\temp.vhd"

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StorageName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$DiskName,

    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$LiteralPath,
    
    [ValidateSet("AzureUSGovernment", "AzureCloud")]
    [string]$environmentName = "AzureCloud"
)
begin
{
    Write-Verbose ("[BEGIN] Upload virtual disk to Azure Storage blob {0}" -f $StorageName)
    $azureEnvironment = Get-AzureEnvironment -Name $environmentName
}
process
{
    $account = Get-AzureStorageKey -StorageAccountName $StorageName -ErrorAction SilentlyContinue
    if($account -eq $null) {
        Write-Error ("The storage account {0} or key could not be discovered" -f $StorageName)
    }
    else {
        $storageContext = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $account.Primary -Endpoint $azureEnvironment.StorageEndpointSuffix

		$storageContainer = Get-AzureStorageContainer -Context $storageContext -Name vhds -ErrorAction Continue
		if($storageContainer -eq $null) {
			New-AzureStorageContainer -Context $storageContext -Name vhds -Permission Off
            $storageContainer = Get-AzureStorageContainer -Context $storageContext -Name vhds
		}

        $storageUri = $storageContainer.CloudBlobContainer.Uri
        $Destination = ("{0}/{1}" -f $storageUri, $DiskName)
        Add-AzureVhd  -Destination $Destination -LocalFilePath $LiteralPath 
    }
}
end
{
    Write-Verbose ("[END] Upload virtual disk to Azure Storage blob {0}" -f $StorageName)
}