Param(
[string]$filePath
)

Function RenameDirectory() {

Param(
[string]$fullpath
)
#*.jpg,*.png
    $files = Get-ChildItem $str -include *.3g2 | %{
        
        $s = [System.IO.FileInfo]($_)
        $sname = $s.Name
        $sext = $s.Extension
        $mon = $sname.Substring(0, 2)
        $day = $sname.Substring(2, 2)
        $year = $sname.Substring(4, 2)
        $prm = $sname.Length - 6
        $endfile = $sname.Substring(6, $prm)
        $filename = "2009_$($mon)$($day)_$($endfile)"
        write-host "Renaming $($_.FullName) to $($filename)"
        Rename-Item $_ $filename
    }
}


$str = "$($filePath)\*"
write-host "Now renaming file path $($str) files"
RenameDirectory -fullpath $str