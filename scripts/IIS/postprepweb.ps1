<#
    .SYNOPSIS
        Preps Windows Machine
#>

Param (
)

# Firewall
netsh advfirewall firewall add rule name="http" dir=in action=allow protocol=TCP localport=80

# Folders
New-Item -ItemType Directory c:\temp -ErrorAction SilentlyContinue
New-Item -ItemType Directory c:\temp\wwwroot -ErrorAction SilentlyContinue
"<html><title>hello</title><body>something</body></html>" | Out-File -FilePath "c:\temp\wwwroot\index.html"


# Install iis
Install-WindowsFeature web-server -IncludeManagementTools

# Install dot.net core sdk
Invoke-WebRequest http://go.microsoft.com/fwlink/?LinkID=615460 -outfile c:\temp\vc_redistx64.exe
Start-Process c:\temp\vc_redistx64.exe -ArgumentList '/quiet' -Wait
Invoke-WebRequest https://go.microsoft.com/fwlink/?LinkID=809122 -outfile c:\temp\DotNetCore.1.0.0-SDK.Preview2-x64.exe
Start-Process c:\temp\DotNetCore.1.0.0-SDK.Preview2-x64.exe -ArgumentList '/quiet' -Wait
Invoke-WebRequest https://go.microsoft.com/fwlink/?LinkId=817246 -outfile c:\temp\DotNetCore.WindowsHosting.exe
Start-Process c:\temp\DotNetCore.WindowsHosting.exe -ArgumentList '/quiet' -Wait

# Configure iis
New-Website -Name "HelloWorldSite" -Port 80 -PhysicalPath c:\temp\wwwroot -ApplicationPool DefaultAppPool
& iisreset