[cmdletbinding()]
param([string]$directory,[switch]$renameFiles)
process
{

# setup the characters that the file system does not like
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $invalidChars = $invalidChars + "–" #adding dash as winzip doesn't like it
    $invalidChars = $invalidChars + "#%" #adding sharepoint online sync characters
    $invalidCharsRegex = "[{0}]" -f [RegEx]::Escape($invalidChars)


    $items = Get-ChildItem -LiteralPath $directory -Recurse
    Write-Verbose ("Iterating {0} files...." -f $items.Count)
    $items | ForEach-Object {
        $oldFileName = $_.Name
        $isMatch = [RegEx]::IsMatch($oldFileName, $invalidCharsRegex)
        if($ismatch) {
            $newFileName = $oldFileName -replace $invalidCharsRegex
            Write-Verbose ("{0} has invalid characters..." -f $oldFileName)
            Write-Verbose ("{0} invalid characters are removed..." -f $newFileName)
            if($renameFiles) {
                Write-Verbose ("Renaming {0} to {1}" -f $oldFileName,$newFileName)
                Rename-Item -LiteralPath $_.FullName -NewName $newFileName
            }
        }
    }
}