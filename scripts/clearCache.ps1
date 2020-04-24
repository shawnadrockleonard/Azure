$t_path_7 = "C:\Users\$env:username\AppData\Local\Microsoft\Windows\Temporary Internet Files"
$c_path_7 = "C:\Users\$env:username\AppData\Local\Microsoft\Windows\Caches"
$d_path_7 = "C:\Users\$env:username\Downloads"

$temporary_path = Test-Path $t_path_7
$check_cashe = Test-Path $c_path_7
$check_download = Test-Path $d_path_7

if ($temporary_path -eq $True -And $check_cashe -eq $True -And $check_download -eq $True) {
    Write-Host "Clean history"
    RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1

    Write-Host "Clean Temporary internet files"
    RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8
    (Remove-Item $t_path_7\* -Force -Recurse) 2> $null
    RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2

    Write-Host "Clean Cashe"
    (Remove-Item $c_path_7\* -Force -Recurse) 2> $null

    Write-Host "Clean Downloads"
    (Remove-Item $d_path_7\* -Force -Recurse) 2> $null

    Write-Host "Done"
}
