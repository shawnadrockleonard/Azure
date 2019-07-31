#MAKE SURE YOU ARE CONNECTED TO OFFICE 365 BEFORE RUNNING THIS SCRIPT
#If you don't know how check out: http://powershell.office.com/script-samples/connect-to-Azure-AD 
#If you want to learn more about PowerShell for Office 365 and make your own awesome scripts, check out my course on Pluralsight
#Find it at: http://spvlad.com/1VXll7f 

#Get All Licensed Users
$users = Get-MsolUser | Where-Object { $_.isLicensed -eq $true }

foreach ($user in $users) {
    Write-Host "Checking " $user.UserPrincipalName -foregroundcolor "Cyan"
    $CurrentSku = $user.Licenses.Accountskuid
    #If more than one SKU, Have to check them all!
    if ($currentSku.count -gt 1) {
        Write-Host $user.UserPrincipalName "Has Multiple SKU Assigned. Checking all of them" -foregroundcolor "White"
        for ($i = 0; $i -lt $currentSku.count; $i++) {
            #Loop trough Each SKU to see if one of their services has the word Yammer inside
            if ($user.Licenses[$i].ServiceStatus.ServicePlan.ServiceName -like "*Yammer*" ) {
                Write-host $user.Licenses[$i].AccountSkuid "has Yammer. Will  Disable" -foregroundcolor "Yellow"
                $NewSkU = New-MsolLicenseOptions -AccountSkuId $user.Licenses[$i].AccountSkuid -DisabledPlans YAMMER_ENTERPRISE
                Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -LicenseOptions $NewSkU
                Write-Host "Yammer disabled for " $user.UserPrincipalName " On SKU " $user.Licenses[$i].AccountSkuid -foregroundcolor "Green"
            }
            else {
                Write-host $user.Licenses[$i].AccountSkuid " doesn't have Yammer. Skip" -foregroundcolor "Magenta"
            }
        }
    }
    else {
        $NewSkU = New-MsolLicenseOptions -AccountSkuId $CurrentSku -DisabledPlans YAMMER_ENTERPRISE
        Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -LicenseOptions $NewSkU
        Write-Host "Yammer disabled for " $user.UserPrincipalName -foregroundcolor "Green"
    }
}

