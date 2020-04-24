[cmdletbinding()]
param(
	[ValidateScript( { Test-Path $_ -PathType 'Container' })] 
	[string]$DestPath = $(Read-Host -prompt "destination path"),
	[string]$DestFolder = $(Read-Host -prompt "destination folder"),
	[string]$ActualFile = $(Read-Host -prompt "CSV file")
)
begin {


	Import-Module BitsTransfer

	## Get the current location in which this cmdlet is running
	$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path
	$ScriptDirectory = $scriptDir

	$destination = "$($DestPath)\$($DestFolder)"

	## Check that the path entered is valid
	If (!(Test-Path $destination -Verbose)) {
		## If destination path is valid, create folder if it doesn't already exist
		New-Item -ItemType Directory $destination -ErrorAction SilentlyContinue
	}
}
process {


	$configDocument = Import-Csv -LiteralPath $ActualFile

	## We use the hard-coded URL below, so that we can extract the filename (and use it to get destination filename $DestFileName)
	## Note: These URLs are subject to change at Microsoft's discretion - check the permalink next to each if you have trouble downloading.

	ForEach ($node in $configDocument) {
		## Get the URL from the XML Document
		$Url = $node.File

		## Get the file name based on the portion of the URL after the last slash
		$DestFileName = $Url.Split('/')[-1]

		Try {
			## Check if destination file already exists
			If (!(Test-Path "$destination\$DestFileName")) {
				## Begin download
				Start-BitsTransfer -Source $Url -Destination $destination\$DestFileName -DisplayName "Downloading `'$DestFileName`' to $DestFolder" -Priority High -Description "From $Url..." -ErrorVariable err
				If ($err) { Throw "" }
			}
			Else {
				Write-Host " - File $DestFileName already exists, skipping..."
			}
		}
		Catch {
			Write-Warning " - An error occurred downloading `'$DestFileName`'"
			break
		}
	}

	## View the downloaded files in Windows Explorer
	Invoke-Item $destination
}
end {
	## Pause
	Write-Host "- Downloads completed."
}