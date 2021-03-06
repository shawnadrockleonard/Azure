Param(
[string]$filePath,
[string]$filenameprefix
)



$str = "$($filePath)\$($filenameprefix)*"
write-host "Now renaming file path $($str) files"

    $files = Get-ChildItem $str -include *.jpg,*.png |
        where-object { $_.Name -like '*(*' } | %{
        
        $s = [System.IO.FileInfo]($_)
        $start = $s.Name.IndexOf("(")
        $end = $s.Name.IndexOf(")")
        $numlen = ($end - $start) - 1 #remove number for Character
        $name = $s.Name.Substring($start+1, $numlen)
        $cname = ([System.Int32]($name) + 1).ToString()
        $paddedNum = $cname.PadLeft(3, '0')
        $newname = $s.Name.Substring(0, $start)
        $filename = $newname.Replace('_00', "_$($paddedNum)").Replace(' ','')
        $filename = $filename + $s.Extension
        write-host "Renaming $($_.FullName) to $($filename)"
        Rename-Item $_ $filename
    }