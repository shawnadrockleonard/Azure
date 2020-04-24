Import-Module MSOnline

$curService = Connect-Msolservice 


$adminRole = Get-MsolRole -RoleName "Company Administrator"
$members = Get-MsolRoleMember -RoleObjectId $adminRole.objectId
$members