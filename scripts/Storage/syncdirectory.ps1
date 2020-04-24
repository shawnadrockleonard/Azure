[cmdletbinding()]
param(        
    [ValidateScript( { Test-Path $_ -PathType 'Container' })] 
    [string]$directory,

    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureChinaCloud")]
    [string]$storageEnvironment = "AzureCloud",

    [string]$storageAccountName = "splshare",

    [string]$storageAccountKey = ""
)
begin {

}
process {

    # Get Environment
    $azureEnvironment = Get-AzureEnvironment -Name $storageEnvironment

    # create a context for account and key
    $ctx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey -Endpoint $azureEnvironment.StorageEndpointSuffix
    $s = Get-AzureStorageShare -Context $ctx -Name fshare
    # top level directory
    $topdirectory = Get-Item -Path $directory 
    $topDirectoryName = $topdirectory.Name
    # create a directory in the test share just created
    $dir = Get-AzureStorageFile -Share $s -Path $topdirectory -Verbose -ErrorAction SilentlyContinue
    if ($dir -eq $null) {
        New-AzureStorageDirectory -Share $s -Path $topDirectoryName
    }

    $folders = Get-ChildItem -LiteralPath $directory -Recurse | ? { $_.PSIsContainer }
    $folders | ForEach-Object {

        $folder = $_
        $folderRelative = $folder.FullName.Replace($directory, "")
        $dirIndex = $folderRelative.IndexOf("\")
        if ($dirIndex -eq 0) {
            $folderRelative = $folderRelative.Substring($dirIndex + 1)
        }
        $folderRelative = ("{0}\{1}" -f $topDirectoryName, $folderRelative)
        Write-Verbose ("Directory {0} to be written as {1}" -f $folder.FullName, $folderRelative)

        # create a directory in the test share just created
        $dir = Get-AzureStorageFile -Share $s -Path $folderRelative -Verbose -ErrorAction SilentlyContinue
        if ($dir -eq $null) {
            New-AzureStorageDirectory -Share $s -Path $folderRelative
        }

        $files = Get-ChildItem -LiteralPath $folder.FullName | Where-Object PSIsContainer -ne $true
        Write-Verbose ("Directory {0} has {1} files" -f $folderRelative, $files.Count)
        $files | ForEach-Object {

            $file = $_
            $fileRelative = $file.FullName.Replace($folder.FullName, "")
            $fileIndex = $fileRelative.IndexOf("\")
            if ($fileIndex -eq 0) {
                $fileRelative = $fileRelative.Substring($fileIndex + 1)
            }

            # upload a local file to the testdir directory just created
            $fileRelativeWithDir = ("{0}\{1}" -f $folderRelative, $fileRelative)
            $azfile = Get-AzureStorageFile -Share $s -Path $fileRelativeWithDir -ErrorAction SilentlyContinue
            if ($azfile -eq $null) {
                Set-AzureStorageFileContent -Share $s -Path $fileRelativeWithDir -Source $file.FullName
            }
        }

        # list out the files and subdirectories in a directory
        Get-AzureStorageFile -Share $s -Path $folderRelative
    }
}