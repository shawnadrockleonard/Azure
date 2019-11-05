[CmdletBinding()]
Param(
    [string]$DBSERVERALIAS = "TfsDb",
    [string]$DBSERVER = "SQL-004.fqdn",
    [int]$DBSERVERPORT = 1433
)
PROCESS {

    Write-Verbose ("*** Setting Alias={0}" -f $DBSERVERALIAS)
    Write-Verbose ("*** Setting SQLInstance={0}" -f $DBSERVER)


    Write-Verbose "*** Changing Registry for 32 bit"
    $regAlias = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBSERVERALIAS -ErrorAction:SilentlyContinue
    if ($null -eq $regAlias) {
        New-ItemProperty -PropertyType REG_SZ -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBSERVERALIAS `
            -Value ("DBMSSOCN,{0},{1}" -f $DBServer, $DBServerPort)
    }
    
    Write-Verbose "*** Changing Registry for 64 bit"
    $architecture = get-childitem Env:\PROCESSOR_ARCHITECTURE
    $regAlias = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBSERVERALIAS -ErrorAction:SilentlyContinue
    if ($architecture.Value -ne "X86" -and $null -eq $regAlias) { 
        New-ItemProperty -PropertyType REG_SZ -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer\Client\ConnectTo\" -Name $DBSERVERALIAS `
            -Value ("DBMSSOCN,{0},{1}" -f $DBServer, $DBServerPort)        
    }
}
END {
    Write-Verbose "*** Script Complete"
}