[CmdletBinding()]
Param(
	#This defines the account and domain.
	[Parameter(Mandatory = $true, HelpMessage = "The domain, ex: devdc\")]
	[string]$Domain,

	#This defines the account and domain.
	[Parameter(Mandatory = $true, HelpMessage = "The managed service account, ex: gsmadfssvc$")]
	[string]$GMSAAccountName,

	#This defines the samaccountname of an existing AD account that we can query to make sure the GMSA password decoded correctly.
	[Parameter(Mandatory = $true, HelpMessage = "The test ad account, ex: sleon")]
	[string]$ExistingSamAccountForTesting
)
PROCESS {

	#This collects the password blob.
	$PasswordBlob = (Get-ADServiceAccount $GMSAAccountName -properties 'MSDS-ManagedPassword').'MSDS-ManagedPassword'
	#This places the password blob in a memory stream.
	$MemoryStream = [IO.MemoryStream]$PasswordBlob
	#This uses a the .Net BinaryReader to allow integer reading of the Memory Stream.
	$Reader = new-object System.IO.BinaryReader($MemoryStream)
	#This reads the version piece of the blob
	$Version = $Reader.ReadInt16()
	#This reads the Reserved piece of the blob
	$Reserved = $Reader.ReadInt16()
	#This reads the length of the blob.
	$Length = $Reader.ReadInt32()
	#This reads the current password offset of the blob.
	$CurrentPwdOffset = $Reader.ReadInt16()
	#This creates an empty string to place the characters of the password in.
	$CurrentPassword = ""
	#This converts the password chunk of the blob into readable characters using BitCoverter, starting on the character identified by the CurrentPassword Offset, stopping at the end of the Password Blob's Length, incrementing each item by 2
	For ($I = $CurrentPwdOffset; $I -lt $PasswordBlob.Length; $I += 2) {
		[char]$Char = [System.BitConverter]::ToChar($PasswordBlob, $i)
		$CurrentPassword += $Char
	}

	#This renames the account to a format usable in PSCredential storage for internal authentication.
	$Username = $Domain + ($GMSAAccountName -replace '$', '')
	#This converts the decoded password into a secure string.
	$SecurePassword = $CurrentPassword | ConvertTo-SecureString -AsPlainText -Force
	#This stores the username and password into a credential object.
	$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword
	#This simply test that the credentials work.
	Get-ADUser $ExistingSamAccountForTesting -credential $Credentials

}