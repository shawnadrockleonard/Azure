Add-Type -Assembly "microsoft.office.interop.outlook"
$outl = New-Object -ComObject Outlook.Application
$outns = $outl.GetNamespace("mapi")
$outfld = $outns.GetDefaultFolder([Microsoft.Office.Interop.Outlook.OlDefaultFolders]::olFolderInbox)
$outfld.Folders.item('development').folders.item('cyberiq').folders.item('noreply').items | Select-Object -first 5 -Property Subject, To, Recipients |% {
    echo $_.Subject
    echo $_.To
    $msgto = $_.recipients | select-object -Property Address
    echo $msgto
}
 