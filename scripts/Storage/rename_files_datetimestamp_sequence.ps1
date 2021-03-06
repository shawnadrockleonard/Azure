Param(
    [ValidateScript( { Test-Path $_ -PathType 'Container' })]
    [string]$filePath,
    [bool]$checkDate = $true,
    [bool]$includeSequence = $true
)


Function Get-ExifDateTaken {
    <#
.Synopsis
Gets the DateTaken EXIF property in an image file.
.DESCRIPTION
This script cmdlet reads the EXIF DateTaken property in an image and passes is down the pipeline
attached to the PathInfo item of the image file.
.PARAMETER Path
The image file or files to process.
.EXAMPLE
Get-ExifDateTaken img3.jpg
(Reads the img3.jpg file and returns the im3.jpg PathInfo item with the EXIF DateTaken attached)
.EXAMPLE
Get-ExifDateTaken *3.jpg |ft path, exifdatetaken
(Output the EXIF DateTaken values for all matching files in the current folder)
.EXAMPLE
gci *.jpeg,*.jpg|Get-ExifDateTaken 
(Read multiple files from the pipeline)
.EXAMPLE
gci *.jpg|Get-ExifDateTaken|Rename-Item -NewName {“LeJog 2011 {0:MM-dd HH.mm.ss}.jpg” -f $_.ExifDateTaken}
(Gets the EXIF DateTaken on multiple files and renames the files based on the time)
.OUTPUTS
The scripcmdlet outputs PathInfo objects with an additional ExifDateTaken
property that can be used for later processing.
.FUNCTIONALITY
Gets the EXIF DateTaken image property on a specified image file.
#>

    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('FullName', 'FileName')]
        $Path
    )

    Begin {
        Set-StrictMode -Version Latest
        If ($PSVersionTable.PSVersion.Major -lt 3) {
            Add-Type -AssemblyName “System.Drawing”
        }
    }

    Process {
        # Cater for arrays of filenames and wild-cards by using Resolve-Path
        Write-Verbose “Processing input item ‘$Path‘”

        $ImageFile = (Get-ChildItem $Path).FullName

        Try {
            $FileStream = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read, 1024, [System.IO.FileOptions]::SequentialScan)
            $Img = [System.Drawing.Imaging.Metafile]::FromStream($FileStream)
            $ExifDT = $Img.GetPropertyItem("36867")
        }
        Catch {
            Write-Warning “Check $ImageFile is a valid image file”
            If ($Img) { $Img.Dispose() }
            If ($FileStream) { $FileStream.Close() }
            return $Null
        }

        # Convert the raw Exif data

        Try {
            $ExifDtString = [System.Text.Encoding]::ASCII.GetString($ExifDT.Value)

            # Convert the result to a [DateTime]
            # Note: This looks like a string, but it has a trailing zero (0×00) character that 
            # confuses ParseExact unless we include the zero in the ParseExact pattern….

            $OldTime = [datetime]::ParseExact($ExifDtString, "yyyy:MM:dd HH:mm:ss`0", $Null)
        }
        Catch {
            Write-Warning “Problem reading Exif DateTaken string in $ImageFile”
            Return $Null
        }
        Finally {
            If ($Img) { $Img.Dispose() }
            If ($FileStream) { $FileStream.Close() }
        }

        Write-Verbose “Extracted EXIF infomation from $ImageFile“
        Write-Verbose “Original Time is $($OldTime.ToString(‘F’))“

        # Decorate the path object with the EXIF dates and pass it on…

        return $OldTime

    } # End Process Block

    End {
        # There is no end processing…
    }

} # End Function


 
    

Write-Host "Now Calling Rename Directory Function"  
#Variables
$index = 0
$prev_date_in_filename = $null

$files = Get-ChildItem "$($filePath)\*.*" -include *.jpg, *.png, *.bmp 
$files | ForEach-Object {
    $s = [System.IO.FileInfo]($_)
    $fname = $s.Name
    $dt = $s.LastWriteTime
    $dtyear = $dt.Year
    $fExtension = $s.Extension
        
    $exifdt = Get-ExifDateTaken -Path $_.FullName
    if ($exifdt -ne $null) {
        $dt = $exifdt
    }
        
    $date_in_filename = $dt.ToString("yyyy_MMdd_HHmm_ss")
    $dcontain = ($checkDate -eq $true -and $fname -like "*$($dtyear)*")
    $underscore = $fname.LastIndexOf("_")
    if ($underscore -le 0) {
        $underscore = $fname.LastIndexOf(" ")
    }
        
    $end_of_filename = $fExtension
    if ($includeSequence -eq $true) {
        if ($underscore -gt 0) {
            $zeroscape = $underscore + 1
            $tilend = $fname.length - $zeroscape
            $end_of_filename = "_" + $fname.SubString($zeroscape, $tilend)
        }
        else {
            $end_of_filename = "_$($fname)"
        }
    }
        
    if ($dcontain -ne $true) {
        $value = "$($date_in_filename)$($end_of_filename)"
            
        $newpath = Join-Path -Path $filePath -ChildPath $value
        if (Test-Path -Path $newPath) {
            write-host "$($value) exists in the file path, adding sequence number"
            if ($prev_date_in_filename -ne $date_in_filename) {
                $index = 0
            }
            $index = $index + 1
            $indexstr = ([System.String]$index).PadLeft(3, '0')
            $value = "$($date_in_filename)_$($indexstr)$($end_of_filename)"
            $prev_date_in_filename = $date_in_filename
        }            
        elseif ($index -gt 0) {
            $index = 0
        }
            
        write-host "$($fname) is being renamed to $($value) DATE[$($dt)]"
        Rename-Item $_ $value
    }
    else {
        $value = $s.Name
        write-host "$($fname) is not being renamed to $($value) DATE[$($dt)]"
    }
}
