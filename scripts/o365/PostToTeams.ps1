<# 

I recently put together the attached script which would meet this need with a little tweak.  
It checks for O365 groups with one or no owner.  
If the group has a Microsoft Teams team, it posts a message to the team’s conversation on the General channel (different messages for one and no owner).  
If the O365 group doesn’t have a team, it just writes that there isn’t a team but it would be straightforward to have the script send an email to the group’s email address instead (just add it to the last ‘else’ block).

Microsoft provides programming examples for illustration only, without warranty either expressed or
 implied, including, but not limited to, the implied warranties of merchantability and/or fitness 
 for a particular purpose. 
 
 This sample assumes that you are familiar with the programming language being demonstrated and the 
 tools used to create and debug procedures. Microsoft support professionals can help explain the 
 functionality of a particular procedure, but they will not modify these examples to provide added 
 functionality or construct procedures to meet your specific needs. if you have limited programming 
 experience, you may want to contact a Microsoft Certified Partner or the Microsoft fee-based consulting 
 line at (800) 936-5200. 
#>

#Connect Graph, use the client ID from Azure AD under app registrations - reference https://msunified.net/2018/12/12/post-at-microsoftteams-channel-chat-message-from-powershell-using-graph-api/
$AdminUserName = "admin@[TENANTNAME].OnMicrosoft.com"
$clientId = "90437265-b3e8-4e6e-b0d4-04ae53e4caa8"
$redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
$resourceURI = "https://graph.microsoft.com"
$authority = "https://login.microsoftonline.com/common"
$AadModule = Import-Module -Name AzureADpreview -ErrorAction Stop -PassThru
$adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
$authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
# Get token by prompting login window.
$platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Always"
$authResult = $authContext.AcquireTokenAsync($resourceURI, $ClientID, $RedirectUri, $platformParameters)
$accessToken = $authResult.result.AccessToken

# CONNECT TO TEAMS AND EXCHANGE
$cred = Get-Credential
Connect-MicrosoftTeams -Credential $cred
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $cred -Authentication Basic -AllowRedirection
Import-PSSession $Session -DisableNameChecking

# GET O365 GROUPS WITH NO OR ONE OWNER
$Groups = Get-UnifiedGroup | Where-Object { ([array](Get-UnifiedGroupLinks -Identity $_.Id -LinkType Owners)).Count -le 1 } | Select Id, DisplayName, ManagedBy, WhenCreated

ForEach ($Group in $Groups) {
	$UserAlreadyMember = "No"
	$TeamGroup = Get-Team | Where-Object { $_.displayname -eq $Group.DisplayName }
	$TeamGroupID = $TeamGroup.GroupId
	
	# PROCEED IF A TEAM FOR THE GROUP EXISTS
	if ($TeamGroupID) {
		$NumberOfOwners = ([array](Get-UnifiedGroupLinks -Identity $TeamGroupID -LinkType Owners)).Count
		write-host "Posting a message to group " $Group.DisplayName " with " $NumberOfOwners " owner(s)" -foregroundcolor green
		$TeamChannelID = (Get-TeamChannel -GroupId $TeamGroupID | Where-Object { $_.displayname -match "general" }).Id

		# CONNECT TO TEAMS GENERAL CHANNEL AND POST A MESSAGE
		$apiUrl = "https://graph.microsoft.com/beta/teams/$TeamGroupID/channels/$TeamChannelID/chatThreads"
		
		# IF NECESSARY, ADD ADMIN USER AS MEMBER OF TEAM SO IT CAN POST A MESSAGE
		$members = Get-TeamUser -GroupId $TeamGroupID
		ForEach ($member in $members) {
			if ($member.User -eq $AdminUserName) {
				$UserAlreadyMember = "Yes"
			}
		}
		if ($UserAlreadyMember -eq "No") {
			Write-host "Adding " $AdminUserName " as a member" -foregroundcolor yellow
			Add-TeamUser -User $AdminUserName -GroupId $TeamGroupID -Role Member
		}
		# CREATE DIFFERENT POSTS FOR ONE OWNER OR NO OWNERS
		if ($NumberOfOwners -eq 1) {
			$body = @{
				"rootMessage" = @{
					"body" = @{
						"contentType" = 1;
						"content"     = '<h1>This team has only one owner.  Per company policy, please add a second owner.</h1>'
					}
				}
			}
		}
		else {
			$body = @{
				"rootMessage" = @{
					"body" = @{
						"contentType" = 1;
						"content"     = '<h1>This team has no owner.  Per company policy, please contact [CONTACT EMAIL] to add owners.</h1>'
					}
				}
			}
		}
		$bodyJSON = $body | ConvertTo-Json
		$Data = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken" } -Uri $apiUrl -Method Post -Body $bodyJSON -ContentType 'application/json'
		# REMOVE ADMIN USER FROM TEAM MEMBERS IF IT WASN'T ALREADY THERE
		if ($UserAlreadyMember -eq "No") {
			Remove-TeamUser -User $AdminUserName -GroupId $TeamGroupID -Role Member
		}
	}
	else {
		write-host "Group " $Group.DisplayName " does not have an associated team" -foregroundcolor blue
	}
}
# CLEAN UP THE PSSESSION TO EXO
Remove-PSSession $Session