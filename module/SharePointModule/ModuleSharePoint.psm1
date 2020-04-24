
function Add-PowershellSnapIn {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    begin {
        Write-Verbose "..  Loading SharePoint PowerShell Snapin"
    }
    process {

        $PSSnapIn = Get-PSSnapin | Where-Object { $_.Name -like "*sharepoint*" }

        if (!($PSSnapIn.Name -like "*sharepoint*")) {
            Add-PSSnapin Microsoft.SharePoint.PowerShell
        }

    }
    end {
        Write-Verbose ".. Microsoft SharePoint PowerShell snapin loaded"
    }
}

function Get-WorkingPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
    )
    process {
        # get running path
        $myScriptPath = (Split-Path -Parent $MyInvocation.MyCommand.Path) 
        return $myScriptPath
    }
    end {
    }
}

function Select-Random {
    param(
        [int]$count = 1, [switch]$collectionMethod, [array]$inputObject = $null
    ) 
    BEGIN {
        if ($args -eq '-?') {
            @"
        Usage: Select-Random [[-Count] <int>] [-inputObject] <array> (from pipeline) [-?]

        Parameters:
        -Count            : The number of elements to select.
        -inputObject      : The collection from which to select a random element.
        -collectionMethod : Collect the pipeline input instead of using reservoir
        -?                : Display this usage information and exit

        Examples:
        PS> $arr = 1..5; Select-Random $arr
        PS> 1..10 | Select-Random -Count 2

"@
            exit
        } 
        else {
            $rand = new-object Random
            if ($inputObject) {
                # Write-Output $inputObject | &($MyInvocation.InvocationName) -Count $count
            }
            elseif ($collectionMethod) {
                Write-Verbose "Collecting from the pipeline "
                [Collections.ArrayList]$inputObject = new-object Collections.ArrayList
            }
            else {
                $seen = 0
                $selected = new-object object[] $count
            }
        }
    }
    PROCESS {
        if ($_) {
            if ($collectionMethod) {
                $inputObject.Add($_) | out-null
            }
            else {
                $seen++
                if ($seen -lt $count) {
                    $selected[$seen - 1] = $_
                } ## For each input element $n there is a $count/$n chance that it becomes part of the result.
                elseif ($rand.NextDouble() -lt ($count / $seen)) {
                    ## For the ones previously selected, there's a 1/$n chance of it being replaced
                    $selected[$rand.Next(0, $count)] = $_
                }
            }
        }
    }
    END {
        if (-not $inputObject) {
            ## DO ONCE: (only on the re-invoke, not when using -inputObject)
            Write-Verbose "Selected $count of $seen elements."
            Write-Output $selected
            # foreach($el in $selected) { Write-Output $el }
        } 
        else {
            Write-Verbose ("{0} elements, selecting {1}." -f $inputObject.Count, $Count)
            foreach ($i in 1..$Count) {
                Write-Output $inputObject[$rand.Next(0, $inputObject.Count)]
            }   
        }
    }
}

function Restart-Services {
    <#
	Stops and Starts SharePoint Services
#>    
    param(
    )
    process {

        net stop sptimerv4
        net stop spadminv4
        net stop sptracev4
        net stop w3svc


        net start sptimerv4
        net start spadminv4
        net start sptracev4
        net start w3svc
    }
}

function Export-SPFarmSolution {
    param(
        [string]$solutionName, #EX Identity.wsp

        [string]$exportPath
    )
    process {
	
        $farm = Get-SPFarm
        $wsp = $farm.Solutions.Item($solutionName).SolutionFile
        $wsp.SaveAs($exportPath)

    }
}

function Set-MaintenanceWindow {
    [cmdletbinding()]
    param(
        [string]$webappurl,

        [ValidateSet("MaintenancePlanned", "MaintenanceWarning")]
        $maintenanceType,

        # Date when the maintenance will start
        [string]$maintenanceStartDate = "12/4/2014 05:00:00 PM", 
        
        # Date when the maintenance will stop
        [string]$maintenanceEndDate = "12/4/2014 10:00:00 PM", 
        
        # Default aggregate for hours to notify the users
        [int]$hoursToNotify = 6,
        
        # Read-Only Hours for which the content database will be unresponsive
        [int]$readOnlyHours = 5,

        [switch]$removeWindow
    )
    begin {
        Write-Debug ("Start >> Set-MaintenanceWindow -WebAppUrl {0}" -f $webappurl)
    }
    process {
        # Date when the message will start being displayed
        $notificationStartDate = ([string]([datetime]$maintenanceStartDate).addHours(0 - $hoursToNotify))
        # Date when the message will stop being displayed
        $notificationEndDate = ([string]([datetime]$maintenanceEndDate).AddHours($hoursToNotify)) 
        $readOnlyDays = 0   # duration days
        $readOnlyMinutes = 0   # duration minutes only appears if days and minutes are both zero

        $maintenanceWindow = New-Object Microsoft.SharePoint.Administration.SPMaintenanceWindow
        $maintenanceWindow.MaintenanceEndDate = $maintenanceEndDate
        $maintenanceWindow.MaintenanceStartDate = $maintenanceStartDate
        $maintenanceWindow.NotificationEndDate = $notificationEndDate
        $maintenanceWindow.NotificationStartDate = $notificationStartDate
        $maintenanceWindow.MaintenanceType = $maintenanceType
        $maintenanceWindow.Duration = New-Object System.TimeSpan( $readOnlyDays, $readOnlyHours, $readOnlyMinutes, 0)
        #$maintenanceWindow.MaintenanceLink       = $maintenanceLink


        Get-SPContentDatabase | Where-Object { $_.WebApplication -like "*$($webappurl)*" } | 
        Foreach-Object {
            write-host "Now setting Maintenance Window for $($maintenanceStartDate) on $($webappurl)"
            $_.MaintenanceWindows.Clear()
            if ($removeWindow -eq $false) {
                $_.MaintenanceWindows.Add($maintenanceWindow)
            }
            $_.Update()
        }
    }
    end {
        Write-Debug ("End << Set-MaintenanceWindow")
    }
}

function GetUserName {
    <#
	Parse the true identity from the principal string value
#>    
    param(
        [string]$username
    )
    process {
        $loc = $username.IndexOf("#")
        $len = $username.Length
        $userValue = $username.SubString($loc + 1, $len - $loc - 1)
        return $userValue
    }
}

function Migrate-SpUser {
    <#
	Parse the true identity from the principal string value
#>    
    param(
        [string]$oldIdentity,

        [string]$newIdentity,

        [string]$webUrl
    )
    process {
        $user = Get-SPUser -Identity $oldIdentity -Web $webUrl
        Write-Host $user.Name
        Write-Host "-------- Name $user.LoginName --------"
        Move-SPUser -Identity $user -NewAlias $newIdentity -IgnoreSID
    }
}

Function Get-SpUsersFromGroups {
    <#
	My Function
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$WebUrl = $(Read-Host -prompt "SharePoint Web Url"),

        [Parameter(Mandatory = $True)]
        [string]$wgroup = $(Read-Host -prompt "SharePoint Group Name")
    )
    begin {

    }
    process {
        $w = [microsoft.sharepoint.spweb](Get-SPWeb $weburl)
        if ($w) {
     
            try {
                $outhash = @()

                $w.Groups | Where-Object { $_.loginname -like "*$($wgroup)*" } | ForEach-Object {
                    Write-Host $_.loginname #$_.owner
                    $webobj = New-Object psobject -Property @{
                        GroupName = $_.loginname
                        GroupUser = @()
                    }

                    $_.Users | ForEach-Object {

                        $huser = $_
                        $hash = New-Object psobject -Property @{
                            UserLogin = $huser.UserLogin
                        }

                        $webobj.GroupUser += $hash
                    }

                    $outhash += $webobj
                    $webobj.GroupUser | Export-Csv -Path "Output\$($_.loginname)users.csv"
                }
            }
            catch [Exception] {
            }
            finally {
                $w.Dispose()
            }
        }
    }
    end {
        Write-Verbose "<< End Get-SpUsersFromGroups"
    }
}

function Get-SpGroup {
    <#
    Extends the SiteGroups from the SpWeb and returns the Group
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$WebUrl,
        
        [Parameter(Mandatory = $True)]
        [string]$GroupName
    )
    process {
        $SPWeb = Get-SPWeb $WebUrl
        $SPGroup = $SPWeb.SiteGroups[$GroupName]
        $SPWeb.Dispose()
        return $SPGroup
    }
}

function Get-SpGroupUsers {
    <#
    Extends the SiteGroups from the SpWeb and returns the users in the Group
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$WebUrl,
        
        [Parameter(Mandatory = $True)]
        [string]$GroupName
    )
    process {
        $sgroup = Get-SpGroup -WebUrl $WebUrl -GroupName $GroupName
        $sgroup.users | select userlogin
    }
}

function Remove-SpGroups {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$WebUrl,
        
        [Parameter(Mandatory = $True)]
        [string]$GroupName,
        
        [Parameter(Mandatory = $False)]
        [switch]$recursive
    )
    begin {
    }
    process {
        try {

            $web = Get-SPWeb -Identity $WebUrl
            if ($web -ne $null) {

                Write-Verbose ("Found weburl {0} and beginning user enumeration...." -f $WebUrl)
                
                if ($web.HasUniquePerm -or $web.HasUniqueRoleAssignments) {
                    $SPGroup = Get-SpUser -Identity $GroupName -Web $web -ErrorAction SilentlyContinue
                    if ($SPGroup -ne $null) {
                        Write-Verbose ("Found group {0} in web {1}" -f $GroupName, $WebUrl)
                        Remove-SpUser -Identity $SPGroup -Web $web -Confirm:$false
                    }
                }
                
                if ($recursive -eq $true) {
                    #enumerate webs and delete alerts
                    $web.Webs | Foreach-Object {
                        Remove-SpGroups -WebUrl $_.Url -GroupName $GroupName -recursive:$recursive
                    }
                }
            }
        }
        catch [Exception] {

        }
        finally {
            if ($web -ne $null) {
                $web.Dispose()
            }
        }  
    }
    end {

    }
}

Function Push-SpGroupUsersToDb {
    param (
        [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
        [string]$filename,
        
        [Parameter(Mandatory = $True)]
        [string]$groupnameindb,
        
        [Parameter(Mandatory = $True)]
        [string]$connString
    )
    begin {
        $webmembership = "ldapmembers"
        $windowsClaimPrefix = "i:0#.w|"
        $formsClaimPrefix = "i:0#.f|"
        $domainPrefix = "esisac\"
        $regex = new-object System.Text.RegularExpressions.Regex ('@(.*)$', [System.Text.RegularExpressions.RegexOptions]::MultiLine)
    }
    process {

        $csv = Import-Csv -LiteralPath $filename
        $csv | ForEach-Object {

            $username = $_.UserLogin
            Write-Host $username

            Try {			
                $SqlConn = new-object System.Data.SqlClient.SqlConnection
                $SqlConn.ConnectionString = $connString
			
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $SqlCmd.Connection = $SqlConn
                $SqlCmd.CommandText = "[dbo].[usp_InsertUserWithSharePointGroup]"
                $SqlCmd.CommandType = [System.Data.CommandType]::StoredProcedure
                $s = $SqlCmd.Parameters.AddWithValue("@GroupName", $groupnameindb)
                $s = $SqlCmd.Parameters.AddWithValue("@UserIdentity", $username)
                $SqlCmd.Parameters.Add("@Reason", 0) | out-null
                $SqlCmd.Parameters["@Reason"].Direction = [system.Data.ParameterDirection]::Output
                $SqlConn.Open()
                $execresult = $SqlCmd.ExecuteNonQuery()
                $result = $SqlCmd.Parameters["@Reason"].value
                $SqlConn.Close()

                Write-Host $result
            }
            catch [Exception] {            
                Write-host "ERROR" -ForegroundColor Yellow
                Write-host $t
                write-host $_.Exception.GetType().FullName; 
                write-host $_.Exception.Message; 
            }
            Finally {
            }
        }
    }
}
function Get-AdUserInfo {
    <#
	Scans the ActiveDirectory Container OU with email addresses
#>
    [CmdLetBinding()]
    [OutputType([bool])]
    param(
        [string]$containerOU = $(Read-Host -prompt "OU"),

        [string]$FilterDate = $null
    )
    begin {
        Import-Module ActiveDirectory
        Write-Verbose "Now collecting ad accounts and writing to file system."
    }
    process {

        $adUsers = Get-ADUser -SearchBase $containerOU `
            -SearchScope Subtree `
            -properties emailaddress, BadLogonCount, Created, Enabled, LastBadPasswordAttempt, LastLogonDate, LockedOut, PasswordLastSet, PasswordExpired `
            -Filter { (EmailAddress -like "*") }
        if ($adUsers -ne $null) {

            $listItems = @($adUsers)
            $listItemsCount = $listItems.Count

            if ($listItemsCount -gt 0) {

                $webhash = @()

                # get the alerts
                $listItems | Foreach-Object {
    
                    $hash = New-Object psobject -Property @{
                        SamAccountName         = $_.SamAccountName.ToString().tolower()
                        Email                  = $_.EmailAddress
                        Name                   = $_.Name
                        UserSid                = $_.SID
                        BadLogonCount          = $_.BadLogonCount
                        Created                = $_.Created
                        Enabled                = $_.Enabled
                        LastBadPasswordAttempt = $_.LastBadPasswordAttempt
                        LastLogonDate          = $_.LastLogonDate
                        LockedOut              = $_.LockedOut
                        PasswordLastSet        = $_.PasswordLastSet
                        PasswordExpired        = $_.PasswordExpired
                    }

                    $webhash += $hash
                }

                $webhash | Export-Csv -Path "CurrentUsersInTheOU.csv"
            }
        }
    }
    end {
        Write-Verbose " << End collecting ad accounts and writing to file system."
    }
}

function Test-AdObject {
    <#
    Function to test existence of AD object
#>
    [CmdletBinding(ConfirmImpact = "Low")]
    Param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = "Identity of the AD object to verify if exists or not."
        )]
        [Object] $Identity
    )
    begin {

        # Import the Active Directory Powershell Module
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    }
    process {
        try {
            $auxObject = Get-ADObject -Identity $Identity
            return $true
        }
        catch [Exception] {
            return $false
        }
    }
}

Function Check-ADUser {
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [string]$Username
    )
    process {
        $Username = ($Username.Split('\')[1])
        $ADRoot = [ADSI]""
        $ADSearch = New-Object System.DirectoryServices.DirectorySearcher($ADRoot)
        $SAMAccountName = $Username
        $ADSearch.Filter = "(&(objectClass=user)(sAMAccountName=$SAMAccountName))"
        $Result = $ADSearch.FindAll()

        If ($Result.Count -eq 0) {
            $Status = "INVALID"
        }
        Else {
            $Status = "VALID"
        }

        return $Status
    }
}

Function Translate-AdUserSidToName {
    param(
        [string]$userSid
    )
    begin {
        # Import the Active Directory Powershell Module
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    }
    process {

        $objSID = New-Object System.Security.Principal.SecurityIdentifier ($userSid) 
        $objUser = $objSID.Translate( [System.Security.Principal.NTAccount]) 
        return $objUser.Value
    }
    end {
    }
}

Function Create-SpManagedAccount {
    <#
	Provisions a Managed Account in SharePoint if it does not already exists.  will prompt for a password
#>
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$domain,

        [Parameter(Mandatory = $True)]
        [string]$username = $(throw "Provide username"),
        
        [Parameter(Mandatory = $False)]
        [string]$password = $null
    )
    begin { 
    }
    process {
        Try {
            # create credentials
            $User = "$domain\$username"

            if ( Get-SPManagedAccount | Where-Object { $_.UserName -eq $User } ) {
                Write-Warning "INFO - managed account $username exists in sharepoint"
            }
            else {
                if ($password -ne $null) {
                    $PWord = ConvertTo-SecureString �String $password �AsPlainText -Force
                    $Credential = New-Object �TypeName System.Management.Automation.PSCredential �ArgumentList $User, $PWord
                    $account = get-credential -Credential $Credential
                }
                else {
                    $account = get-credential -UserName $User -Message "Provide the service account password."
                }

                if ($account -ne $null) {
                    New-SPManagedAccount -Credential $account
                    Write-Host "managed account $username added successfully"
                }
                else {
                    Write-Host "managed account failed on credentials" -ForegroundColor Yellow
                }
            }
        }
        catch [Exception] {            
            Write-host "ERROR" -ForegroundColor Red
            Write-host $t
            write-host $_.Exception.GetType().FullName; 
            write-host $_.Exception.Message; 
        }
        Finally {
        }
    }
    end {

    }
}

function Enable-SpDeveloperConsole {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
    )
    begin {
    }
    process {
        $devConsole = [Microsoft.SharePoint.Administration.SPWebService]::ContentService.DeveloperDashboardSettings;
        $devConsole.DisplayLevel = 'On';
        $devConsole.RequiredPermissions = 'FullMask';
        $devConsole.TraceEnabled = $true;
        $devConsole.Update(); 
    }
    end {
    }
}

function Enable-SpIntranetCalls {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
    )
    begin {
    }
    process {
        $farm = get-spfarm
        $farm.properties.disableintranetcalls = $false
        $farm.properties.disableintranetcallsfromapps = $false
        $farm.Update()
    }
    end {
    }
}


function Check-SpDeploy {
    <#
# Deploys a collection of sharepoint solutions.  
#	If the solution is web application scoped a site url must be present
#	if the solution is already deployed a check will be made an no action will be taken
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [string]$WebUrl = $(throw "Provide site url"),
        [string]$wspName = $(throw "Provide wsp Filename")
    )
    begin {
    }
    process {
        $solution = Get-SPSolution -Identity $wspName -ErrorAction SilentlyContinue
        if ($solution -eq $null) {
            Write-Host -NoNewLine "[NOT DEPLOYED] $wspName is ready to deploy?"
        }
        else {
            write-host "Lets check for deployment and the specified url."
            if ($solution.Deployed -eq $true) {
                if ($solution.ContainsWebApplicationResource) {
                    $webapp = $solution.DeployedWebApplications | Where-Object { $_.Url -like "$WebUrl*" }
                    if ($webapp -ne $null) {
                        write-host "deployed on web application $webapp"
                    }
                }
            }
        }
    }
    end {
    }
}

function Wait-SpJobToFinish {
    <#
# Deploys a collection of sharepoint solutions.  
#	If the solution is web application scoped a site url must be present
#	if the solution is already deployed a check will be made an no action will be taken
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [string]$Identity,

        [int]$SleepSeconds = 10
    )
    begin {
    }
    process {
  
        $job = Get-SPTimerJob | ? { $_.Name -like "*solution-deployment*$Identity*" }
        $maxwait = 30
        $currentwait = 0
        if (!$job) {
            Write-Host -f Red '[ERROR] Timer job not found'
        }
        else {
            $jobName = $job.Name
            Write-Host -NoNewLine "[WAIT] Waiting to finish job $jobName"        
            while (($currentwait -lt $maxwait)) {
                Write-Host -f Green -NoNewLine .
                $currentwait = $currentwait + 2
                Start-Sleep -Seconds $SleepSeconds
                if (!(Get-SPTimerJob $jobName)) {
                    break;
                }
            }
            Write-Host  -f Green "...Done!"
        }
    }
}

function Retract-SpSolution {
    <#
# Deploys a sharepoint solutions.  
#	If the solution is web application scoped a site url must be present
#	if the solution is already deployed a check will be made an no action will be taken
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [Parameter(Mandatory = $True)]
        [string]$Identity
    )
    begin {
    }
    process {
        Write-Host "[RETRACT] Uninstalling $Identity"    
        Write-Host -NoNewLine "[RETRACT] Does $Identity contain any web application-specific resources to deploy?"
        $solution = Get-SPSolution | Where-Object { $_.Name -match $Identity }
        if ($solution -ne $null) {
            if ($solution.ContainsWebApplicationResource) {
                Write-Host  -f Yellow "...Yes!"        
                Write-Host -NoNewLine "[RETRACT] Uninstalling $Identity from all web applications"            
                Uninstall-SPSolution -identity $Identity  -allwebapplications -Confirm:$false
                Write-Host -f Green "...Done!"
            }
            else {
                Write-Host  -f Yellow  "...No!"        
                Uninstall-SPSolution -identity $Identity -Confirm:$false    
                Write-Host -f Green "...Done!"
            }
            Wait-SpJobToFinish
            Write-Host -NoNewLine  '[UNINSTALL] Removing solution:' $SolutionName
            Remove-SPSolution -Identity $Identity -Confirm:$false
        }
        Write-Host -f Green "...Done!"
    }
}

function Deploy-SpSolution {
    <#
# Deploys a sharepoint solutions.  
#	If the solution is web application scoped a site url must be present
#	if the solution is already deployed a check will be made an no action will be taken
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
        [string]$Path = $(throw "Provider literal path to WSP"), 

        [string]$Identity
    )
    begin {
    }
    process {

        Write-Host -NoNewLine "[DEPLOY] Adding solution:" $Identity

        $solution = Get-SPSolution -Identity $Identity -ErrorAction SilentlyContinue
        if ($solution -eq $null) {
            $solution = Add-SPSolution $Path
            Write-Host -f Green "...Done!"
            Write-Host -NoNewLine "[DEPLOY] Does $Identity contain any web application-specific resources to deploy?"
        }

        #$solution = Get-SPSolution | Where-Object { $_.Name -match $Identity }
        write-host "Lets check for deployment against the specified url."
        $deploy = $true
        if ($solution.Deployed -eq $true) {
            $deploy = $false;
            if ($solution.ContainsWebApplicationResource) {
                $webapp = $solution.DeployedWebApplications | Where-Object { $_.Url -like "$WebUrl*" }
                if ($webapp -eq $null) {
                    Write-Host -f Yellow "...Not deployed!" 
                    write-host -NoNewLine "[Configure] Deploy to web application $webapp"
                    $deploy = $true
                }

            }
        }
    
        if ($deploy) {
            if ($solution.ContainsWebApplicationResource) {
                Write-Host -f Yellow "...Yes!"        
                Write-Host -NoNewLine "[DEPLOY] Does Parameter contain URL to deploy to?"
                if ($WebUrl) {
                    Write-Host -f Yellow "...Yes!"  
                    Write-Host -NoNewLine "[DEPLOY] Installing $Identity for $WebUrl"    
                    $solution | Install-SPSolution -WebApplication $WebUrl -GACDeployment:$($solution.ContainsGlobalAssembly) -CASPolicies:$($solution.ContainsCasPolicy) -Confirm:$false
                }
                else {
                    Write-Host -f Yellow "...No!"   
                    Write-Host -NoNewLine "[DEPLOY] Installing $Identity for all web applications"    
                    $solution | Install-SPSolution -AllWebApplications -GACDeployment:$($solution.ContainsGlobalAssembly) -CASPolicies:$($solution.ContainsCasPolicy) -Confirm:$false
                }
            }
            else {
                Write-Host -f Yellow "...No!"        
                Write-Host -NoNewLine "[DEPLOY] Globally deploying $Identity"    
                $solution | Install-SPSolution -GACDeployment:$($solution.ContainsGlobalAssembly) -CASPolicies:$($solution.ContainsCasPolicy) -Confirm:$false
            }
        }

        Write-Host -f Green "...Done!"
        if ($deploy -eq $true) {
            Wait-SpJobToFinish -Identity $Identity
        }
    }
}

function Upgrade-SpDeploySolution {
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
        [string]$Path = $(throw "Provider literal path to WSP"), 

        [string]$Identity
    )
    begin {
        Write-Host -NoNewLine "[DEPLOY] Check solution installed:" $Identity
    }
    process {

        $solution = Get-SPSolution -Identity $Identity -ErrorAction SilentlyContinue
        if ($solution -ne $null) {

            Write-Host -f Yellow "...Yes!"        
            Write-Host -NoNewLine "[DEPLOY] Globally upgrading $Identity"    
            $solution | Update-SPSolution -GACDeployment:$($solution.ContainsGlobalAssembly) -FullTrustBinDeployment:$($solution.ContainsGlobalAssembly) -CASPolicies:$($solution.ContainsCasPolicy) -Confirm:$false -LiteralPath $path

            Write-Host -f Green "...Done!"
            Wait-SpJobToFinish -Identity $Identity
        }
    }
}

function Deploy-SpSolutionsFromCsv {
    <#
# Deploys a collection of sharepoint solutions.  
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [string]$WebUrl = $(throw "Provide site url"),

        [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
        [string]$csvPath = $(throw "Provider literal path"),

        [ValidateScript( { Test-Path $_ -PathType Container })]
        [string]$wspPath = $(throw "Provider directory to WSPs")
    )
    begin {

        #Write the script path and site address
        Write-Verbose "FolderName $wspPath SiteUrl $WebUrl"
    }
    process {

        #iterate the csv file and deploy
        foreach ($e in (Import-Csv -Path $csvPath)) {
            $solutionname = $e.name
            $path = "$wspPath\$solutionname"
            Write-Host "now installing sourcelist $solutionname"
            Deploy-SpSolution -Path $path -Identity $solutionname
        }
    }
}

function Upgrade-SpSolutionsFromCsv {
    <#
# Deploys a collection of sharepoint solutions.  
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param 
    (
        [string]$WebUrl = $(throw "Provide site url"),

        [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
        [string]$csvPath = $(throw "Provider literal path"),

        [ValidateScript( { Test-Path $_ -PathType Container })]
        [string]$wspPath = $(throw "Provider directory to WSPs")
    )
    begin {

        #Write the script path and site address
        Write-Verbose "FolderName $wspPath SiteUrl $WebUrl"
    }
    process {

        #iterate the csv file and deploy
        foreach ($e in (Import-Csv -Path $csvPath)) {
            $solutionname = $e.name
            $path = "$wspPath\$solutionname"
            Write-Host "now upgrading WSP $solutionname"
            Upgrade-SpDeploySolution -Path $path -Identity $solutionname
        }
    }
}


Function Disable-SpMachineKeySync {
    param(
    )
    begin {
    }
    process {
        Get-SPHealthAnalysisRule | Where-Object Name -eq ViewStateKeysAreOutOfSync | Disable-SPHealthAnalysisRule
    }
}

function Get-SpFolder {
    param(
        [Microsoft.SharePoint.SPWeb]$Web,

        [string]$FolderName
    )
    process {
        $folder = $null;
	
        [Microsoft.SharePoint.SPFolderCollection]$folders = $Web.Folders
        foreach ($f in $folders) {
            if ($f.Name -eq $FolderName) {
                $folder = $f
                break
            }
        }
	
        return $folder
    }
}

function Get-SpTheme {
    param(
        [string]$url
    )
    process {
        $spWeb = Get-SPWeb -Identity $url
        $spTheme = [Microsoft.SharePoint.Utilities.ThmxTheme]::GetThemeUrlForWeb($spWeb)
        if (-not([string]::IsNullOrEmpty($spTheme))) {
            [Microsoft.SharePoint.Utilities.ThmxTheme]::Open($spWeb.Site, $spTheme) |
            Format-List -Property @{Name = "Theme"; Expression = { $_.Name } },
            @{Name = "Type"; Expression = { $_.ThemeType } },
            @{Name = "RelativeUrl"; Expression = { $_.ServerRelativeUrl } },
            @{Name = "Description"; Expression = { $_.AccessibleDescription } }
        }
        else {
            Write-Host "Default Theme is being used by this site."
        }
        $spWeb.Dispose()
    }
}

Function Set-SharePointTheme {
    param(
        [string]$Url = $(Read-Host -prompt "Web Url"),

        [string]$SubWebUrl = $(Read-Host -prompt "Sub Web Url"),

        [string]$ThemeName = $(Read-Host -prompt "Theme name"),
	    
        [switch]$Recursive
    )
    begin {
    }
    process {

        [Microsoft.SharePoint.SPSite]$Site = New-Object Microsoft.SharePoint.SPSite($Url)
        [Microsoft.SharePoint.SPWeb]$ParentWeb = $Site.OpenWeb()

        try {

            Get-SpTheme $Url
            #Get-SPTheme $Url + $SubWebUrl

            $splist = $ParentWeb.Lists["Composed Looks"]
            if ($splist -ne $null) {
                Write-Host $splist.Title
                foreach ($splistitem in $splist.Items) {
                    if ($splistitem["Title"] -eq $ThemeName) {
                        $spfont = $splistitem["FontSchemeUrl"]
                        $spcolor = $splistitem["ThemeUrl"]
                        $masterp = $splistitem["MasterPageUrl"]
                        $imagesp = $splistitem["ImageUrl"]

                        $spfontrelative = $spfont.Split(",")[1].Trim()
                        $spcolorrelative = $spcolor.Split(",")[1].Trim()
                        $masterprelative = $masterp.Split(",")[1].Trim()
                        $imagesprelative = $imagesp.Split(",")[1].Trim()

                        Write-Host "master: "$masterp" theme: "$spcolor" image: "$imagesp" font: "$spfont


                        # Get the SPColor file. Replace with the path to your SPColor file.
                        [Microsoft.SharePoint.SPFile]$spcolorfile = $ParentWeb.GetFile($spcolorrelative)

                        # Get the SPFont file. Replace with the path to your SPFont file.
                        $colorPaletteFile = $ParentWeb.GetFile($spfont)
            

                        # Open an SPTheme with the two files. Replace NewTheme with the name for your theme.
                        # Note: If you have a background image, you can specify the following:
                        # SPTheme.Open("NewTheme", colorPaletteFile, spcolorfile, backgroundURI)$"ISACTheme", $colorPaletteFile, $spcolorfile)
                        if (($spcolorfile -ne $null) -and ($colorPaletteFile -ne $null)) {
                            # TODO: handle the error.
               
                            #$SpNewTheme = [Microsoft.SharePoint.Utilities.ThmxTheme]::Open($spcolorfile)
             
             
                            # Now apply your theme to the site.
                            # The themed CSS output files are stored in the Themed folder of the Theme Gallery of the root web
                            # of the site collection. To specify that the files should be stored in the _themes folder within the root 
                            # web, pass false to the ApplyTo method.
                            #$SpNewTheme.ApplyTo($SubWeb, $true)

                            # Parameters: (Color Palette, Font Scheme, Background Image, Share Generated)
                            # web.ApplyTheme(colorPaletteUrl, spFontUrl, bgImageUrl, false);
                            # web.Update();
                
                            [Microsoft.SharePoint.SPWeb]$SubWeb = $Site.OpenWeb($SubWebUrl)

                            $SubWeb.ApplyTheme($spcolorrelative, $spfontrelative, $imagesprelative, $false)
                            $SubWeb.Update()
                            $SubWeb.Dispose()

                
                            $tobemasterurl = $ParentWeb.Url + $masterprelative
                            Write-Host "master page: "$tobemasterurl
                            #[Microsoft.SharePoint.SPWeb]$SubWeb = $Site.OpenWeb($SubWebUrl)
                            #$SubWeb.MasterUrl = $tobemasterurl
                            #$SubWeb.CustomMasterUrl = $tobemasterurl
                            #$SubWeb.Update()
                            #$SubWeb.Dispose()


                        }


                    }
                }
            }
        }
        catch {
            Write-Error $_.ToString()
        }
        finally {
            $ParentWeb.Dispose()
            $Site.Dispose()
        }
    }
}




Function Test-WriteRegistryKeyProperty { 
    Param( 
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [ValidateScript( { Test-Path $_ -PathType 'Container' })] 
        [String]$RegistryKey,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [String]$RegistryName,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [String]$RegistryValue   
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
                ����            write-host "$RegistryKey RKEY $RegistryName doesn't exist"
                write-host "now writing RKEY $RegistryName"
                ����            New-ItemProperty -Path $RegistryKey -Name $RegistryName -PropertyType String -Value $RegistryValue
                $returnvalue = $true
            }
            Catch {
                write-warning "Error writing $RegistryKey : $($_.Exception.Message)" 
            }
        }

        return $returnvalue
    } 
}

Function Test-WriteRegistryKey { 
    Param( 
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)] 
        [String]$RegistryKey 
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
                ����            New-Item $RegistryKey
                $returnvalue = $true
            }
            Catch {
                write-warning "Error writing $RegistryKey : $($_.Exception.Message)" 
            }
        }

        return $returnvalue
    } 
}

Function Merge-SQLAlias {
    Param(
        [String]$RegistryKey,
        [String]$ServerName,
        [String]$AliasName,
        [ValidateSet("NAMEDPIPES", "TCP")]
        [String]$NamedOrTCP,
        [String]$InstanceName,
        [String]$InstancePort
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
        $doesalasexist = Test-WriteRegistryKeyProperty -RegistryKey $RegistryKey -RegistryName $AliasName -RegistryValue $ConstructedAlias
        Write-Host "RKEY Path: $RegistryKey"
        Write-Host "RKEY Name: $AliasName"
        Write-Host "RKEY Value: $ConstructedAlias"
        Write-Host "RKEY Write result = $doesalasexist"
        return $doesalasexist
    } 
}

function Set-SQLAlias {
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
    Param(
        [string]$AliasName,

        [ValidateSet("NAMEDPIPES", "TCP")]
        [string]$NamedOrTCP,

        [string]$ServerName,

        [string]$InstancePort = "",

        [string]$InstanceName = ""
    )
    begin {

        #Registry KEYS for SQL Configuration
        $x86 = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
        $x64 = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"

    }
    process {
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

        $does86exist = Test-WriteRegistryKey -RegistryKey $x86 
        Write-Host "32bit RKEY check returned with result: $does86exist"

        $does64exist = Test-WriteRegistryKey -RegistryKey $x64
        Write-Host "64bit RKEY check returned with result: $does64exist"

        if ($does86exist -eq $false -xor $does64exist -eq $false) {
            Write-Error 'The appropriate RKEYs do not exist.  Please confirm and rerun.'
            Exit  
        }
        Write-Host "    Registry keys are valid" -ForegroundColor Gray


        # -----------------------------------------------
        #Add registry keys for sql aliases

        Write-Host " (3 of 3) Add Alias" -ForegroundColor White
        Merge-SQLAlias -RegistryKey $x86 -ServerName $ServerName -AliasName $AliasName -NamedOrTCP $NamedOrTCP -InstanceName $InstanceName -InstancePort $InstancePort
        Merge-SQLAlias -RegistryKey $x64 -ServerName $ServerName -AliasName $AliasName -NamedOrTCP $NamedOrTCP -InstanceName $InstanceName -InstancePort $InstancePort

        #New-ItemProperty -Path $x86 -Name $AliasName -PropertyType String -Value $TCPAlias
    }
}


function Add-WebConfigBackupFile {
    param(
        [System.Xml.XmlDocument]$xmlDoc, 
        [string]$path
    )
    process {
        $date = Get-Date    
        $dateString = $date.ToString("yyyy MM dd H mm")
        $configWithDate = "web_$($dateString)_pre_key_.bak".Replace(" ", "_")
        $backupPath = $path.Replace("web.config", $configWithDate)
        $xmlDoc.Save($backupPath)
    }
}

function Set-WebConfigLdapRoleProvider {
    param(
        [System.Xml.XmlDocument]$xmlDoc, 
        $ldapRoleKey, 
        $ldapServer, 
        $userNameAttribute, 
        $userContainer, 
        $userFilter, 
        $groupFilter
    )
    process {
        #Check to see if it was already created, and if not, create it
        $rolesAddNode = $xmlDoc.selectSingleNode("/configuration/system.web/roleManager/providers/add[@name='$($ldapRoleKey)']")
        if (!$rolesAddNode) {
            $rolesNode = $xmlDoc.selectSingleNode("/configuration/system.web/roleManager")
            $providerNode = $null
        
            if (!$rolesNode) {
                $rolesNode = $xmlDoc.CreateNode("element", "roleManager", "")        
                $providerNode = $xmlDoc.CreateNode("element", "providers", "")
                $rolesNode.AppendChild($providerNode)
                $xmlDoc.selectSingleNode("/configuration/system.web").AppendChild($rolesNode)                
            }

            $rolesNode = $xmlDoc.selectSingleNode("/configuration/system.web/roleManager")
            $rolesEnabledAttr = $xmlDoc.CreateAttribute("enabled");
            $rolesEnabledAttr.Value = "true";
            $rolesNode.Attributes.Append($rolesEnabledAttr)
        
            $providerNode = $xmlDoc.selectSingleNode("/configuration/system.web/roleManager/providers")
            $rolesAddNode = $xmlDoc.CreateNode("element", "add", "")
        
            $roleNameAttr = $xmlDoc.CreateAttribute("name")
            $roleNameAttr.Value = $ldapRoleKey
            $rolesAddNode.Attributes.Append($roleNameAttr)
        
            $roleTypeAttr = $xmlDoc.CreateAttribute("type")
            $roleTypeAttr.Value = "Microsoft.Office.Server.Security.LdapRoleProvider, Microsoft.Office.Server, Version=15.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c"
            $rolesAddNode.Attributes.Append($roleTypeAttr)

            $rolesserverAttr = $xmlDoc.CreateAttribute("server")
            $rolesserverAttr.Value = $ldapServer
            $rolesAddNode.Attributes.Append($rolesserverAttr)

                                                                
            $providerNode.AppendChild($rolesAddNode)
        }
        return $xmlDoc
    }
}

function Set-WebConfigSPWebApplication {
    <# user and group filters
ROLES:
    "(&(ObjectClass=person))" 
    "(&(ObjectClass=group))"

MEMBERSHIP:
    "(&(ObjectClass=person))"
#>
    param(
        $path, 
        $ldapServer, 
        $userContainer, 
        $userNameAttribute, 
        $ldapUserKey, 
        $ldapRoleKey
    )
    process {
        $userFilter = "(ObjectClass=person)"
        $groupFilter = "(ObjectClass=group)"

        $content = Get-Content -Path $path
        [System.Xml.XmlDocument] $xd = new-object System.Xml.XmlDocument
        $xd.LoadXml($content)

        Add-WebConfigBackupFile -xmlDoc $xd -path $path
    
        #Add Machine Key
        $xd = Set-WebConfigRoleProvider -xmlDoc $xd -ldapRoleKey $ldapRoleKey -ldapServer $ldapServer -userNameAttribute $userNameAttribute -userContainer $userContainer -userFilter $userFilter -groupFilter $groupFilter
        $xd.Save($path)
    }
}


Export-ModuleMember *