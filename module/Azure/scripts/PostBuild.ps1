param($ProjectDir, $ConfigurationName, $TargetDir, $TargetFileName, $TargetName, $SolutionDir, $ProjectName)
begin 
{
	Write-Output ("Starting the post build script for {0}" -f $TargetDir)
}
process
{
	$documentsFolder = [environment]::getfolderpath("mydocuments");

	Remove-Module -Name $ProjectName -ErrorAction SilentlyContinue
	$PSModuleHome = ("{0}\WindowsPowerShell\Modules\{1}" -f $documentsFolder,$TargetName)


	# Module folder there?
	if(Test-Path $PSModuleHome)
	{
		# Yes, empty it
		Remove-Item $PSModuleHome\* -Force -Recurse
	} else 
	{
		# No, create it
		New-Item -Path $PSModuleHome -ItemType Directory -Force >$null # Suppress output
	}

	Write-Host "Copying files from $TargetDir to $PSModuleHome"
	Copy-Item "$TargetDir\*.dll" -Destination "$PSModuleHome"
	#Copy-Item "$TargetDir\*.pdb" -Destination "$PSModuleHome"
	Copy-Item "$TargetDir\*.config" -Destination "$PSModuleHome"
	Copy-Item "$TargetDir\*help.xml" -Destination "$PSModuleHome"
	Copy-Item "$TargetDir\*.json" -Destination  "$PSModuleHome"
	Copy-Item "$TargetDir\*.psd1" -Destination  "$PSModuleHome"
	Copy-Item "$TargetDir\*.psm1" -Destination  "$PSModuleHome"
	Copy-Item "$TargetDir\*.ps1xml" -Destination "$PSModuleHome"
	Copy-Item "$TargetDir\*.resx" -Destination "$PSModuleHome"
	<#
    Get-ChildItem -Path "$TargetDir" -recurse | Where-Object { $_.PSIsContainer } | ForEach-Object {
        #test if the directory has files
        $subDirectories = Get-ChildItem -Path $_.FullName -Filter "*.dll"
        if($subDirectories.Count -gt 0) {
            Copy-Item $_.FullName -Destination "$PSModuleHome" -Recurse -Force
        }
	}
	#>
}
end
{
	Write-Output ("Finish the post build script for {0}" -f $TargetDir)
}
	