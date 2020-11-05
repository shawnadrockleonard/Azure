Set-ExecutionPolicy Bypass -Scope Process -Force; 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$installedSoftwareTxt = "C:\installtools\InstalledChocoPackages.txt"

# Validate running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )  
if (-not($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))) { 
    clear-host 
    Write-Error "Warning: PowerShell is NOT running as an Administrator.`n" 
    throw "Warning: PowerShell is NOT running as an Administrator."
}

#check for existence of the readme file to determine if this script has already run (prevents re-running on re-deployments)
if (!(Test-Path $installedSoftwareTxt)) {

    choco install cmder -y;

    choco install azcopy10 -y;
    $userpath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $userpath += ";C:\ProgramData\chocolatey\lib\azcopy10\tools\azcopy";
    [System.Environment]::SetEnvironmentVariable('Path', $userpath, [System.EnvironmentVariableTarget]::User)

    # Browsers
    choco install googlechrome -y;
    choco install microsoft-edge -y;
    choco install firefox -y;

    # Credentials
    choco install git -y; 

    # Engines
    choco install nodejs-lts --version 12.19.0 -y; 

    # Development / Build Tools
    choco install vscode -y; 
    choco install azure-cli -y;
    choco install powershell-core -y
    choco install azure-data-studio -y;

    # SDKs
    # https://dotnet.microsoft.com/download/dotnet-core/3.1
    
    Add-Content -Path $installedSoftwareTxt -Value ("{0}--chocopackages" -f (get-date).ToString("o"))
}