Set-ExecutionPolicy Bypass -Scope Process -Force; 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$installedSoftwareTxt = "C:\installtools\InstalledJmeter.txt"

# Validate running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )  
if (-not($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))) { 
	clear-host 
	Write-Error "Warning: PowerShell is NOT running as an Administrator.`n" 
	Exit 1
}

#check for existence of the readme file to determine if this script has already run (prevents re-running on re-deployments)
if (!(Test-Path $installedSoftwareTxt)) {

	# install data tools
    $CurrentPath = (Get-Location)
    
    
    choco install jre8 -y;

	# Install jMeter
	$jmeteruri = "https://mirrors.koehn.com/apache/jmeter/binaries/apache-jmeter-5.2.1.zip"
	$zipFile = ("{0}\apache-jmeter-5.2.1.zip" -f $CurrentPath)

	$installJmeter = 'C:\installtools\jmeter'
	Invoke-WebRequest $jmeteruri -OutFile $zipFile
	Expand-Archive -Path $zipFile -DestinationPath $installJmeter -Force -Verbose:$VerbosePreference
	Add-Content -Path $installedSoftwareTxt -Value ("{0}--jmeter" -f (get-date).ToString("o"))

	$jmeterInstance = Get-ChildItem -Path $installJmeter -Filter "*bin" -Recurse | sort-object LastWriteTime -Descending | Select-Object -First 1
	if (($jmeterInstance | Measure-Object).Count -gt 0) {
		$jmeterDirectoryFull = $jmeterInstance[0].Parent.FullName
		[System.Environment]::SetEnvironmentVariable('JMETER_HOME', $jmeterDirectoryFull, [System.EnvironmentVariableTarget]::Machine)
		$pluginsPath = Join-Path -Path $jmeterDirectoryFull -ChildPath "lib\ext" -Resolve
		$Exclude = Get-ChildItem -recurse $pluginsPath

		# Assumes the DSC package has placed the jmeter-plugins.zip file in the current directory
		Expand-Archive -Path '.\jmeter-plugins.zip' -DestinationPath ("{0}\jmeter-plugins\" -f $CurrentPath)
		Copy-Item -Path ("{0}\jmeter-plugins\*.jar" -f $CurrentPath) -Destination $pluginsPath -Exclude $Exclude -ErrorAction:SilentlyContinue
	}

	Add-Content -Path $installedSoftwareTxt -Value ("{0}--jmeter" -f (get-date).ToString("o"))
}