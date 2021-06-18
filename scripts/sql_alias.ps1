# ---------------------------------------------------------------------------------
# Setup for a SQL alias to be used by application connection pool
# $AliasName = Unique Name to be used in web.configs
# $NamedOrTCP = Pass in Named pipes or TCP
# $ServerName = Computer name hosting the SQL instance or a CNAME
# (optional) $InstancePort = SQL Instance port, optional when using named pipes otherwise required
# (optional) $InstanceName = SQL Instance name, if empty will use the default named instance
#
#  e.g. .\sql_alias -AliasName "customdb" -NamedOrTCP "TCP" -ServerName "shtestsql1"
#
# ---------------------------------------------------------------------------------
[cmdletbinding(SupportsShouldProcess = $true)]
Param(
    [string]
    $AliasName,

    [ValidateSet("NAMEDPIPES", "TCP")]
    [string]
    $NamedOrTCP,

    [string]
    $ServerName,

    [string]
    $InstancePort = "",

    [string]
    $InstanceName = ""
)

#Registry KEYS for SQL Configuration
$x86 = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
$x64 = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"


Function TestAndWriteRegistryKeyProperty { 
    Param( 
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [ValidateScript( { Test-Path $_ -PathType 'Container' })] 
        [String] 
        $RegistryKey,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [String] 
        $RegistryName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [String] 
        $RegistryValue   
    ) 
    Process { 
        $returnvalue = $false

        Try { 
            
            $hlkm = Get-ItemProperty -Path $RegistryKey -Name $RegistryName -EA 'Stop' 
            write-host "$hlkm exists."
            $returnvalue = $true
        } 
        Catch { 
            write-warning "Error accessing $RegistryKey : $($_.Exception.Message)"  
        } 

        if ($returnvalue -eq $false) {

            Try {
                write-host "$RegistryKey RKEY $RegistryName doesn't exist"
                write-host "now writing RKEY $RegistryName"
                New-ItemProperty -Path $RegistryKey -Name $RegistryName -PropertyType String -Value $RegistryValue
                $returnvalue = $true
            }
            Catch {
                write-warning "Error writing $RegistryKey : $($_.Exception.Message)" 
            }
        }

        return $returnvalue
    } 
}

Function TestAndWriteRegistryKey { 
    Param( 
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)] 
        [String] 
        $RegistryKey 
    ) 
    Process { 
        $returnvalue = $false

        Try { 
            #[ValidateScript({Test-Path $_ -PathType 'Container'})] 
            $hlkm = Get-Item -Path $RegistryKey -EA 'Stop' 
            write-host "$hlkm exists."
            $returnvalue = $true
        } 
        Catch { 
            write-warning "Error accessing $RegistryKey : $($_.Exception.Message)"   
        } 

        if ($returnvalue -eq $false) {

            Try {
                write-host "now writing RKEY $RegistryKey"
                New-Item $RegistryKey
                $returnvalue = $true
            }
            Catch {
                write-warning "Error writing $RegistryKey : $($_.Exception.Message)" 
            }
        }

        return $returnvalue
    } 
}


Function AddOrUpdateSQLAlias {
    Param(
        [String] 
        $RegistryKey,
        [String] 
        $ServerName,
        [String] 
        $AliasName,
        [String] 
        $NamedOrTCP,
        [String] 
        $InstanceName,
        [String]
        $InstancePort
    ) 
    Process { 

        #tell the machine what type of alias it is
        if ($NamedOrTCP -eq "TCP") {

            $ConstructedAlias = "DBMSSOCN,$ServerName,$InstancePort"
        }
        else {

            if ($InstanceName -eq $null -xor $InstanceName -eq "") {
                $ConstructedAlias = "DBNMPNTW,\\$ServerName\PIPE\sql\query"
            }
            else {
                $ConstructedAlias = "DBNMPNTW,\\$ServerName\PIPE\MSSQL$" + $InstanceName + "\sql\query"
            }
        }

        #Creating Aliases
        $doesalasexist = TestAndWriteRegistryKeyProperty -RegistryKey $RegistryKey -RegistryName $AliasName -RegistryValue $ConstructedAlias
        Write-Host "RKEY Path: $RegistryKey"
        Write-Host "RKEY Name: $AliasName"
        Write-Host "RKEY Value: $ConstructedAlias"
        Write-Host "RKEY Write result = $doesalasexist"
        return $doesalasexist

    } 
}



Write-Host
Write-Host "Register new SQL ALIAS or ensure existing SQL Alias..." -ForegroundColor White
Write-Host " Script Steps:" -ForegroundColor White
Write-Host
 
# -----------------------------------------------
# verify parameters passed in

Write-Host " (1 of 3) Validating Parameters ..." -ForegroundColor White
if ($AliasName -eq $null -xor $AliasName -eq "") {
    Write-Error '$AliasName is required'
    Exit
}
if ($ServerName -eq $null -xor $ServerName -eq "") {
    Write-Error '$ServerName is required'
    Exit
}
if ($NamedOrTCP -eq "TCP" -and ($InstancePort -eq $null -xor $InstancePort -eq "")) {
    Write-Error '$InstancePort is required for a TCP setting (default to 1433)'
    Exit
}
Write-Host "    All parameters valid" -ForegroundColor Gray


# -----------------------------------------------
#These are the two Registry locations for the SQL Alias locations
#We're going to see if the ConnectTo key already exists, and create it if it doesn't.

Write-Host " (2 of 3) Validating x86 and x64 ..." -ForegroundColor White

$does86exist = TestAndWriteRegistryKey -RegistryKey $x86 
Write-Host "32bit RKEY check returned with result: $does86exist"

$does64exist = TestAndWriteRegistryKey -RegistryKey $x64
Write-Host "64bit RKEY check returned with result: $does64exist"

if ($does86exist -eq $false -xor $does64exist -eq $false) {
    Write-Error 'The appropriate RKEYs do not exist.  Please confirm and rerun.'
    Exit  
}
Write-Host "    Registry keys are valid" -ForegroundColor Gray



# -----------------------------------------------
#Add registry keys for sql aliases

Write-Host " (3 of 3) Add Alias" -ForegroundColor White
AddOrUpdateSQLAlias -RegistryKey $x86 -ServerName $ServerName -AliasName $AliasName -NamedOrTCP $NamedOrTCP -InstanceName $InstanceName -InstancePort $InstancePort
AddOrUpdateSQLAlias -RegistryKey $x64 -ServerName $ServerName -AliasName $AliasName -NamedOrTCP $NamedOrTCP -InstanceName $InstanceName -InstancePort $InstancePort

#New-ItemProperty -Path $x86 -Name $AliasName -PropertyType String -Value $TCPAlias

