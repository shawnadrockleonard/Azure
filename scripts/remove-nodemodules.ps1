[CmdletBinding()]
Param()
PROCESS {

    $nodemod = Get-ChildItem -Path "C:\source" -Filter "*node_modules*" -Recurse -Depth 20

    $nodemod | ForEach-Object {
        rimraf $_.FullName
    }


}