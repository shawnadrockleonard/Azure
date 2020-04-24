[CmdletBinding()]
param([string]$UserMailAddress)
begin {
    # Import Required Modules
    $FileName = "EwsManagedApi.msi"
    $defaultPath = $env:TEMP
    $ews = "http://download.microsoft.com/download/2/1/B/21BBA55F-C2C7-411D-86A2-31C0E63DE785/EwsManagedApi.msi"
    $installPath = ("{0}\{1}" -f $defaultPath, $FileName)
    $installPathLog = ("{0}\install_ewsmanagedapi.txt" -f $defaultPath)

    If ((Test-Path $installPath)) { 
        Write-Host " - File $FileName already exists, skipping..." 
    }
    else {
        Import-Module BitsTransfer 
        ## Begin download 
        Start-BitsTransfer -Source $ews -Destination $installPath -DisplayName "Downloading `'$FileName`' to $defaultPath" -Priority High -Description "From $ews..." -ErrorVariable err 
        If ($err) { Throw "" } 
        Start-Process $installPath /qn -Wait
        $proc = Start-Process -File $installPath -Arg ("/qn /l*v {0}" -f $installPathLog) -PassThru
        do { 
            Write-verboase "Pausing to install file....." 
            start-sleep -Milliseconds 100
        }
        until ($proc.HasExited)
    } 
}
process {
    $cred = Get-Credential -Message "Enter your Tenant ID"
    $dllpath = ("{0}\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll" -f ${env:ProgramFiles(x86)})
    Write-Verbose "Path to Exchange API: $dllpath"

    if (Test-Path -Path $dllpath -PathType Leaf) {
        Write-Verbose "Loading assembly..."
        [void][Reflection.Assembly]::LoadFile( $dllpath )

        Write-Verbose "Creating new Exchange service object"
        $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService 
        $service.UseDefaultCredentials = $true
        $service.Credentials = New-Object System.Net.NetworkCredential($cred.UserName, $cred.Password)

        Write-Verbose "Searching for URL"
        $service.AutodiscoverUrl( $UserMailAddress, { $true } )

    }
}
end {
    #end do cleanup

}