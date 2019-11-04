# A Powershell Script To Copy The Contacts From An Exchange Public Folder To A Mailbox Contacts Folder
#
# If you want to try it, copy the code into  a .ps1 file (e.g. CopyPFToContacts.ps1) and run it from the shell by navigating to the folder you put it in, and typing
#
# .\CopyPFToContacts.ps1 <folderPath> <userSMTPAddress> <clearFolder>
# where folderPath is the path of the Public Folder to Copy, userSMTPAddress is the email address of the user to receive the Contacts, and clearFolder is a flag to indicate whether to empty the folder first.  Here is an example:
#
# .\CopyPFToContacts.ps1 \PublicContacts\WorldWide user@domain.com $True
# If you want to copy the contacts to a folder that is not the default Contacts folder, you can supply the destination folder as the fourth positional parameter, like this
#
# .\CopyPFToContacts.ps1 \Folder\SubFolder user@domain.com $True "\Contacts\Sub Folder"
# or as a named parameter (if you are omitting the third parameter), like this
#
# .\CopyPFToContacts.ps1 \Folder\SubFolder user@domain.com -destination "\Contacts\Sub Folder"
# In either case, the destination folder is specified as a path relative to the mailbox root, not the default Contacts folder.  If you want the script to create the folder, you can supply the parameter -createFolder $True.  Remember that if you are supplying all parameters to the script, and in the correct order, you can omit the parameter names.

# CopyPFToContacts.ps1
# By Lee Derbyshire
# Parameter 0 = Public Folder Path
# Parameter 1 = Mailbox SMTP address
# Parameter 2 = Empty folder first?
# Parameter 3 = Destination folder if not default Contacts folder
# Parameter 4 = Create destination folder if absent?
# Usage examples:
# CopyPFToContacts.ps1 \Folder\SubFolder user@domain.com $False
# CopyPFToContacts.ps1 \Folder\SubFolder user@domain.com $True "\Contacts\Sub Folder"
# CopyPFToContacts.ps1 \Folder\SubFolder user@domain.com -destination "\Contacts\Sub Folder"

param([Parameter(Position = 0, Mandatory = $True, HelpMessage = "The path of the folder to copy")]
    [string]$folderPath,
    [Parameter(Position = 1, Mandatory = $True, HelpMessage = "Email Address of the target Mailbox")]
    [string]$mailbox,
    [Parameter(Position = 2, Mandatory = $False, HelpMessage = "Whether or not to empty the folder first")]
    [bool]$clearFolder,
    [Parameter(Position = 3, Mandatory = $False, HelpMessage = "The path of the destination folder")]
    [string]$destination,
    [Parameter(Position = 4, Mandatory = $False, HelpMessage = "Whether or not to create the destination folder")]
    [bool]$createFolder,
    [Parameter(Position = 5, Mandatory = $False, HelpMessage = "The customer name")]
    [string]$customer
)

# Add the snapin in case we're in the plain (i.e. non-Exchange Management) Shell

# Try the E2007 snapin first
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.Admin -ErrorAction SilentlyContinue
# Then try the E2010 snapin
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue
# This assumes you have v2.0 of the EWS Managed API
Add-Type -Path ".\Microsoft.Exchange.WebServices.dll"

# Supply the folder path, then try to locate it

$ews = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService("Exchange2007_SP1")
$ews.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $mailbox)
$ews.AutodiscoverUrl($mailbox)
$rootFolderId = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::PublicFoldersRoot)
$folder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($ews, $rootFolderId)
$arrPath = $folderPath.Split("\")
for ($i = 1; $i -lt $arrPath.length; $i++) {
    $folderView = New-Object Microsoft.Exchange.WebServices.Data.FolderView(1)
    $searchFilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName, $arrPath[$i])
    $findFolderResults = $ews.FindFolders($folder.Id, $searchFilter, $folderView)
    if ($findFolderResults.TotalCount -gt 0) {
        $folder = $findFolderResults.Folders[0]
    }
    else {
        "$folderPath Not Found"
        exit
    }
}

if ($destination) {
    $mbRootFolderId = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot)
    $mbFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($ews, $mbRootFolderId)
    $arrMbPath = $destination.Split("\")
    for ($i = 1; $i -lt $arrMbPath.length; $i++) {
        $folderName = $arrMbPath[$i]
        $mbFolderView = New-Object Microsoft.Exchange.WebServices.Data.FolderView(1)
        $mbSearchFilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName, $arrMbPath[$i])
        $mbFindFolderResults = $ews.FindFolders($mbFolder.Id, $mbSearchFilter, $mbFolderView)
        if ($mbFindFolderResults.TotalCount -gt 0) {
            $mbFolder = $mbFindFolderResults.Folders[0]
        }
        else {
            if (!$createFolder) {
                "$destination Not Found"
                exit
            }
            else {
                $newFolder = New-Object Microsoft.Exchange.WebServices.Data.Folder($ews)
                $newFolder.DisplayName = $folderName
                $newFolder.FolderClass = "IPF.Contact"
                $newFolder.Save($mbFolder.Id)
                $mbFolder = $newFolder
            }
        }
    }
    $contactsFolderId = $mbFolder.Id
}
else {
    $contactsFolderId = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts)
}

if ($clearFolder) {
    # Delete the items in the folder
    # Note that E2007 doesn't have folder.Empty()
    # Could have used just folder.Empty() in >= E2010
    $itemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(1000)
    do {
        $findItemResults = $ews.FindItems($contactsFolderId, $itemView)
        foreach ($item in $findItemResults.Items | Where-Object { $_.CompanyName -eq $customer }) {
            $item.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::HardDelete)
        }
    }
    while ($findItemResults.MoreAvailable)
}

$itemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(1000)
do {
    $findItemResults = $ews.FindItems($folder.Id, $itemView)
    foreach ($item in $findItemResults.Items) {
        $item.DisplayName
        $item.Copy($contactsFolderId)
    }
}
while ($findItemResults.MoreAvailable)
