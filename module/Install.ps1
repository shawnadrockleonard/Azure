[cmdletbinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateScript( { Test-Path $_ -PathType 'Container' })]
	[string]$SourceDir
)
begin {
	Write-Output ("Starting the post build script for {0}" -f $SourceDir)
}
process {

	$source = $PSScriptRoot;
	$programFilesFolder = ("{0}\Documents\PowerShell\Modules" -f (Get-ChildItem Env:\USERPROFILE).Value)
	if ($PSEdition -eq "Desktop") {
		$programFilesFolder = ("{0}\Documents\WindowsPowerShell\Modules" -f (Get-ChildItem Env:\USERPROFILE).Value)
	}
	$PSModuleHome = "$programFilesFolder\AzureCMCore";

	# Module folder there?
	if (Test-Path $PSModuleHome) {
		# Yes, empty it but first unblock the files
		Remove-Item $PSModuleHome\* -Force -Recurse
	} 
	else {
		# No, create it
		New-Item -Path $PSModuleHome -ItemType Directory -Force >$null # Suppress output
	}


	Write-Host "Copying files from $source to $PSModuleHome"
	Copy-Item "$SourceDir\*.dll" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*.pdb" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*help.xml" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*.psd1" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*.ps1xml" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*.psm1" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*.resx" -Destination "$PSModuleHome"
	Copy-Item "$SourceDir\*.json" -Destination "$PSModuleHome"

}
end {
	Write-Host "Restart PowerShell to make the commands available."
}