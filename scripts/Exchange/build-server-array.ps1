$servers = @(
    @{region = 'east'; servername = 'server1' },
    @{region = 'east'; servername = 'server2' },
    @{region = 'west'; servername = 'server3' }
)

$exchange = New-Object 'System.Collections.Generic.Dictionary[string,string[]]'
$items = @(
    @{region = 'east'; adsite = 'hello' },
    @{region = 'east'; adsite = 'world' },
    @{region = 'west'; adsite = 'wvalue1' },
    @{region = 'north'; adsite = 'wy' },
    @{region = 'east'; adsite = 'eway' }
)


foreach ($item in $items) {
    if (-not ($exchange.ContainsKey($item.region))) {
        $exchange.Add($item.region, $item.adsite) 
    }
    else {
        $exchange[$item.region] += $item.adsite
    }
}

foreach ($region in $exchange.Keys) {
    $keyValues = $exchange[$region] -join ","

    if (($servers | where region -eq $region | measure-object).count -gt 0) {
        Write-Host ("Invoke commands for Region {0}" -f $region)
        foreach ($server in $servers | Where-Object region -eq $region) {
            Write-Warning ("`$session = Invoke-Command -ComputerName {0} -ADSites {1}" -f $server.servername, $keyValues)
        }
    }
}