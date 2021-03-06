Param(
[string]$fullpath,
[string]$file_prefix
)



Write-Host "Now Calling Rename Directory Function"  

    $files = Get-ChildItem "$($fullpath)\*.*" -include *.jpg,*.png 
    $files | %{
            $s = [System.IO.FileInfo]($_)
            write-host $_.FullName
            $fname = $s.Name
            $dt = $s.LastWriteTime
            $dtyear = $dt.Year
            $dateString = $dt.ToString("yyyy_MMdd_HHmm")
            $dcontain = $fname -notlike "*$($dtyear)*"
            
            $underscore = $fname.IndexOf("_")
            $tilend = $fname.length - ($underscore+1)
            $underperiod = $fname.SubString($underscore+1, $tilend)
            
            if($dcontain) {
                $value = "$($file_prefix)_$($underperiod)"
                write-host "$($value) is being renamed"
                Rename-Item $_ $value
            }
            else {
                $value = $s.Name + $s.Extension
                write-host "$($value) does not need to be changed"
            }
        }