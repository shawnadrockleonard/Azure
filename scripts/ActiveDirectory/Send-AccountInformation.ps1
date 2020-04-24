
[CmdletBinding(HelpURI = 'http://portal.azure.com')]
[OutputType([bool])]
param(
    [string]$displayName,
    [string]$email,
    [string]$userPrincipalName,
    [string]$password,
    [string]$smtp_username,
    [string]$smtp_password
) 


function Read-EmailTemplate {
    [OutputType([String])]
    param(
        [parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [String]$email_Template,

        [Hashtable]$email_objs
    )
    begin {
        Write-Verbose "[BEGIN] construct Email message from Template"
    }
    process {
        $contents = Get-Content $email_Template

        $pattern = '\b(\w)'
        $displayName = [RegEx]::Replace($email_objs.displayName, $pattern, { param($letter) $letter.Value.toUpper() })
        $firstname = (-split $displayName)[0]

        Write-Verbose ("Send Email Message to {0} with FirstName {1}" -f $displayName, $firstname)
        $contents = $contents.Replace("{USERNAME}", $email_objs.userName)
        $contents = $contents.Replace("{PASSWORD}", $email_objs.password)
        $contents = $contents.Replace("{FIRSTNAME}", $firstname)
        $contents = $contents.Replace("{DISPLAYNAME}", $displayName)
        return $contents
    }
    end {
        Write-Verbose "[END] Sending Smtp Email Message"
    }
}


if ($email -eq $null -or $email.length -le 0) {
    Write-Host -ForegroundColor Red "Email address not provided and cant be sent for $($displayName)"    
}
else {

    $hash = @{displayName = $displayName; Email = $email; userName = $userPrincipalName; password = $password }
    $msg_subject = "test subject for email"
    $msg_email = Read-EmailTemplate -email_Template .\tenants\email-template.html -email_objs $hash


    $passkey = ConvertTo-SecureString $smtp_password -AsPlainText -Force
    Send-SmtpSendGrid -smtp_username $smtp_username -smtp_password $passkey -msg_to $email -msg_from "emailusr@myusers.org" -msg_bcc "emailusr@myusers.org" -msg_subject $msg_subject -msg_body $msg_email
    return $true
}