$dir = Read-Host "file directory"

$a = Get-ChildItem $dir -recurse | Where-Object {$_.PSIsContainer -eq $True}

$collection = $a | Where-Object {$_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0 } | Select-Object FullName

write-host $collection

ForEach ($dirname in $collection) {
 write-host $dirname.FullName
 Remove-Item -Path $dirname.FullName
}