Function Get-PathAlex()
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $SetPathDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $SetPathDialog.ShowDialog() | Out-Null
    $SetPathDialog.SelectedPath
}

$filePath = Get-PathAlex
$fileList = Get-ChildItem -Path $filePath | Select BaseName #get a list of all files in the set path and strip out extension
foreach ($file in $fileList) { $filename = $file.BaseName; ffmpeg -i $filePath\\$filename.mp3 $filePath\\$filename.m4a} # for every file, output copy of mp3 to m4a to its own file in the same directory