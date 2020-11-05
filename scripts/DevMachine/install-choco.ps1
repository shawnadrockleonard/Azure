Set-ExecutionPolicy Bypass -Scope Process -Force; 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

# Validate running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )  
if (-not($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))) { 
    clear-host 
    throw  "Warning: PowerShell is NOT running as an Administrator.`n" 
}

#check for existence of the readme file to determine if this script has already run (prevents re-running on re-deployments)
$installedSoftwareTxt = "C:\installtools\InstalledChoco.txt"
if (!(Test-Path $installedSoftwareTxt)) {
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));

    New-Item -Path "C:\installtools" -ItemType Directory -Force | Out-Null
    ("{0}--Initialized" -f (get-date).ToString("o")) | Out-File -FilePath $installedSoftwareTxt;

    $CurrentPath = (Get-Location)
    Add-Content -Path $installedSoftwareTxt -Value ("{0}--installing-from-{1}" -f (get-date).ToString("o"), $CurrentPath)
}