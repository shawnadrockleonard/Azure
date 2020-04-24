[cmdletbinding()]
param(        
    [ValidateScript({Test-Path $_ -PathType 'Container'})] 
    [string]$directory,

    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureChinaCloud")]
    [string]$storageEnvironment = "AzureCloud",

    [string]$storageAccountName = "",

    [string]$storageAccountKey = ""
)
begin
{

}
process
{

# Get Environment
    $azureEnvironment = Get-AzureEnvironment -Name $storageEnvironment

# create a context for account and key
    $ctx=New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey -Endpoint $azureEnvironment.StorageEndpointSuffix
    $s = Get-AzureStorageContainer -Context $ctx -Name "dbbackup" -ErrorAction SilentlyContinue
    if(!$s) {
        $s = new-azurestoragecontainer -Name "dbbackup" -Context $ctx
    }

# top level directory
	$topdirectory = Get-Item -Path $directory 
    $topDirectoryName = $topdirectory.Name

# get all files regardless of folder location
    $files = Get-ChildItem -LiteralPath $directory -Recurse | ?{ !$_.PSIsContainer }

# enumerate files in this folder
    Write-Verbose ("Directory {0} has {1} files" -f $topDirectoryName,$files.Count)

    $files | ForEach-Object {

        $file = $_
        $fileRelative = $file.FullName.Replace($directory, "")

        $fileIndex = $fileRelative.IndexOf("\")
        if($fileIndex -eq 0) {
            $fileRelative = $fileRelative.Substring($fileIndex+1) # remove the first slash from the relative path
        }

    # upload a local file to the testdir directory just created
        $azfile = Get-AzureStorageBlob -Container "dbbackup" -context $ctx -Blob $fileRelative -Verbose -ErrorAction SilentlyContinue
        if($azfile -eq $null) {
            Set-AzureStorageBlobContent -Container "dbbackup" -Context $ctx -BlobType Block -File $file.FullName -Blob $fileRelative
        }
    }

# list out the files and subdirectories in a directory
    Get-AzureStorageBlob -Container "dbbackup" -context $ctx | ft BlobType,Length,LastModified,Name

}