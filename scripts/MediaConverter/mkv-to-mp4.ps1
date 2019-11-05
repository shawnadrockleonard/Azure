Function Get-PathAlex()
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $SetPathDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $SetPathDialog.ShowDialog() | Out-Null
    $SetPathDialog.SelectedPath
}

$filePath = Get-PathAlex
$fileList = Get-ChildItem -Path $filePath | Select BaseName #get a list of all files in the set path and strip out extension
foreach ($file in $fileList) { $filename = $file.BaseName; ffmpeg -i $filePath\\$filename.mkv -codec copy $filePath\\$filename.mp4} # for every file, convert from mkv to mp4 in the same directory