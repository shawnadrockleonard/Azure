[CmdletBinding()]
Param(
)
PROCESS {

    Set-Location 'C:\Program Files (x86)\Microsoft SQL Server'
    $sqlproviders = Get-ChildItem -Filter "*sqlmgmproviderxpsp2up*" -Recurse

    if ($null -ne $sqlproviders -and ($sqlproviders | Measure-Object).Count -gt 0) {

        ForEach ($sqlprovider in $sqlproviders) {

            Set-Location $sqlprovider.Directory.FullName

            Invoke-Command -ScriptBlock { mofcomp.exe sqlmgmproviderxpsp2up.mof }
        }
    }
}