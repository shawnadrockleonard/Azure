<# 
.SYNOPSIS
    Build Certificates requests from GUI
    Will launch the GUI and ensure values are set then writes the results to disk

.AUTHOR
	Shawn Leonard (MSFT Engineer)

.EULA

    Microsoft provides programming examples for illustration only, without 
    warranty either expressed or implied, including, but not limited to, the
    implied warranties of merchantability and/or fitness for a particular 
    purpose.  

    This sample assumes that you are familiar with the programming language
    being demonstrated and the tools used to create and debug procedures. 
    Microsoft support professionals can help explain the functionality of a
    particular procedure, but they will not modify these examples to provide
    added functionality or construct procedures to meet your specific needs. 
    If you have limited programming  experience, you may want to contact a 
    Microsoft Certified Partner or the Microsoft fee-based consulting line 
    at (800) 936-5200. 

.SAMPLE
    .\certGen.ps1 -FriendlyName "wcf.shawniq.com" -Verbose

#>
[cmdletbinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $true)]
    [string]$FriendlyName
)
BEGIN
{

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Pattern
    $pattern = '[^a-zA-Z]'

    Import-Module .\CACert.Module -Force -Verbose:$false

    # Global Variables
    $wizstatus = $true
    $script:certfilename = ""
    $script:xmlfilename = ""
    $script:CAuthority = ""
    $script:identity = Get-CurrentIdentity -Verbose:$VerbosePreference


    # Local Variables


    # Establish the running directories
    $outputDirectory = ("{0}\temp" -f $env:HOMEDRIVE)
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
    if (!(Test-Path -Path $scriptDirectory -PathType 'Container' -ErrorAction SilentlyContinue))
    {
        $scriptDirectory = (New-Item -Path $outputDirectory -ItemType Directory -Force).FullName
    }

    $certPath = Join-Path -Path $scriptDirectory -ChildPath "issued-certs"
    if (!(Test-Path -Path $certPath -PathType 'Container' -ErrorAction SilentlyContinue))
    {
        $certPath = (New-Item -Path $certPath -ItemType Directory -Force).FullName
    }

    # Move to running directory
    Set-Location $scriptDirectory

}
PROCESS
{


    function Update-WizardProgress
    {
        <#
        .SYNOPSIS
        Adds status messages to the progress check box
        .EXAMPLE
        Update-WizardProgress
        #>
        [cmdletbinding()]
        Param( 
            [Parameter(Mandatory = $False)]
            [string]$Message,

            [Parameter(Mandatory = $False)]
            [System.Drawing.Color]$FontColor
        )
        process
        {
            $progress = $textboxWizardProgress.text + "`r`n"
            $progress = $progress + $Message
            $textboxWizardProgress.Text = $progress

            if ($null -ne $FontColor)
            {
                $textboxWizardProgress.ForeColor = $FontColor
            }
            else
            {
                $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Black
            }
            $textboxWizardProgress.SelectionStart = $textboxWizardProgress.TextLength
            $textboxWizardProgress.ScrollToCaret()
        }
    }

 


    $OnLoadFormEvent = {
        #TODO: Initialize Form Controls here
        $MainForm.Focused
    }

    $Form_FormClosing = {
        # Capture form closing event ie user clicked red X. Prompt for validation and cancel event if user has exietd by mistake
    
        If ($wizstatus -eq $false)
        {
            #Pre requisites failed so kill form
            #[environment]::exit(0)
            $MainForm.Close()
        }
        $closeme = Show-MessageBox -Msg "Do you want to close down the Wizard?" -YesNo 
    
        If ($closeme -eq "Yes")
        {
            $wizstatus = $false
        }
        Else
        {
            $_.Cancel = $true # $_.Cancel actually cancels the FormClosing Event and so FormClosed never fires
            Show-MessageBox "Carry on regardless"
        }
    }


    $buttonStart_Click = {

        $Button1.Text = "Running"
        $Button1.Enabled = $false

        
        $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Black
        $dnsError = $false

        $certsanstatus = $false
        $certtype = "generic"
        $certRequest = ("CN={0}" -f $tbCN.Text)

        if ($null -eq $tbCN.Text -or $tbCN.Text.Length -le 1)
        {
            Update-WizardProgress "-------"
            Update-WizardProgress "You must provide a CN for the request"
            $tbCN.ForeColor = [System.Drawing.Color]::Red
            $dnsError = $true
        } 
        $tbCN.ForeColor = [System.Drawing.Color]::Black
        $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Black


        $certdnsarray = New-Object -TypeName System.Collections.ArrayList
        $sanCert = ""
        if ($tbdns1.Text.Length -gt 0 -or $tbdns2.Text.Length -gt 0 -or $tbdns3.Text.Length -gt 0 -or $tbdns4.Text.Length -gt 0)
        {

            $certsanstatus = $true
            $sanCertDn = ""
            $sanCertEx = ""
            $sanCertAttr = ("dns={0}" -f $tbCN.Text)

            if ($tbdns1.Text.Length -gt 0)
            {
                if ($tbdns1ref.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns1.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $tbdns1ref.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                else
                {
                    $tbdns1ref.ForeColor = [System.Drawing.Color]::Black
                    $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns1.Text)
                    $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns1.Text, $tbdns1ref.Text)
                    $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns1.Text)

                
                    $certDns = @{
                        dn  = $tbdns1.Text
                        ref = $tbdns1ref.Text
                    }
                    $certdnsarray.Add((New-Object PSObject -Property $certDns))
                }
            }

            if ($tbdns2.Text.Length -gt 0)
            {
                if ($tbdns2ref.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns2.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns2.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns2.Text, $tbdns2ref.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns2.Text)

                $certdns = @{
                    dn  = $tbdns2.Text
                    ref = $tbdns2ref.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            if ($tbdns3.Text.Length -gt 0)
            {
                if ($tbdns3ref.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns3.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns3.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns3.Text, $tbdns3ref.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns3.Text)

                $certdns = @{
                    dn  = $tbdns3.Text
                    ref = $tbdns3ref.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            if ($tbdns4.Text.Length -gt 0)
            {
                if ($tbdns4ref.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns4.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns4.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns4.Text, $tbdns4ref.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns4.Text)

                $certdns = @{
                    dn  = $tbdns4.Text
                    ref = $tbdns4ref.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            if ($tbdns5.Text.Length -gt 0)
            {
                if ($tbdnsref5.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns5.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns5.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns5.Text, $tbdnsref5.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns5.Text)

                $certdns = @{
                    dn  = $tbdns5.Text
                    ref = $tbdnsref5.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            if ($tbdns6.Text.Length -gt 0)
            {
                if ($tbdnsref6.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns6.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns6.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns6.Text, $tbdnsref6.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns6.Text)

                $certdns = @{
                    dn  = $tbdns6.Text
                    ref = $tbdnsref6.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            if ($tbdns7.Text.Length -gt 0)
            {
                if ($tbdnsref7.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns7.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns7.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns7.Text, $tbdnsref7.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns7.Text)

                $certdns = @{
                    dn  = $tbdns7.Text
                    ref = $tbdnsref7.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            if ($tbdns8.Text.Length -gt 0)
            {
                if ($tbdnsref8.Text.length -le 1)
                {
                    Update-WizardProgress ("You must provide a DNS Ref for the DNS {0}" -f $tbdns8.Text)
                    $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
                    $dnsError = $true
                }
                $sanCertAttr = ("{0}&dns={1}" -f $sanCertAttr, $tbdns8.Text)
                $sancertDn = ("{0},CN={1},CN=Ref:{2}" -f $sancertDn, $tbdns8.Text, $tbdnsref8.Text)
                $sanCertEx += (@"
_continue_ = "dns={0}&"

"@ -f $tbdns8.Text)

                $certdns = @{
                    dn  = $tbdns8.Text
                    ref = $tbdnsref8.Text
                }
                $certdnsarray.Add((New-Object PSObject -Property $certDns))
            }

            $sanCert = @"
[Extensions]
2.5.29.17 = "`{text`}"

"@

            $sanCert += (@"
_continue_ = "dns={0}&"
{1}_continue_ = "upn={2}&""

[RequestAttributes]
SAN="{3}"


"@ -f $tbCN.Text, $sanCertEx, $script:identity.Name, $sanCertAttr)


        }


        if ($sancertDn.Length -gt 0)
        {
            $certRequest += ("{0},CN={1}" -f $sancertDn, $tbCN.Text)
        }



        
        if ($RadioButton2.Checked)
        {
            $keyUsage = @"
OID=1.3.6.1.5.5.7.3.2; Client Authentication
"@
            $certRequest += (",OU=Web Client")
            $certTemplate = "WorkstationAuthenticationCertAuth"
            $certtype = "client"
        }
        else
        {   
            $keyUsage = @"
OID=1.3.6.1.5.5.7.3.1; Server Authentication
OID=1.3.6.1.5.5.7.3.2; Client Authentication
"@          
            $certRequest += (",OU=Web Server")
            $certTemplate = "WebServerCertAuth" 
            $certtype = "server"
        }

        if ($null -eq $tbOrg.Text -or $tbOrg.Text.Length -le 1)
        {
            Update-WizardProgress "Provide an ORG"
            $tbOrg.ForeColor = [System.Drawing.Color]::Red
            $dnsError = $true
        }
        else
        {
            $certRequest += (",O={0}" -f $tbOrg.Text)
            $tbOrg.ForeColor = [System.Drawing.Color]::Black
        }

        if ($null -eq $tbOrgUnit.Text -or $tbOrgUnit.Text.Length -le 1)
        {
            Update-WizardProgress "Provide an ORG Unit"
            $tbOrgUnit.ForeColor = [System.Drawing.Color]::Red
            $dnsError = $true
        }
        else
        {
            $certRequest += (",OU={0}" -f $tbOrgUnit.Text)
            $tbOrgUnit.ForeColor = [System.Drawing.Color]::Black
        }

        if ($null -eq $tbLocation.Text -or $tbLocation.Text.Length -le 1)
        {
            Update-WizardProgress "Provide a Location"
            $tbLocation.ForeColor = [System.Drawing.Color]::Red
            $dnsError = $true
        }
        else
        {
            $certRequest += (",L={0}" -f $tbLocation.Text)
            $tbLocation.ForeColor = [System.Drawing.Color]::Black
        }

        if (-1 -ge $lboxState.SelectedIndex)
        {
            Update-WizardProgress "Select a State"
            $lboxState.ForeColor = [System.Drawing.Color]::Red
            $dnsError = $true
        }
        else
        {
            $certRequest += (",ST={0}" -f $lboxState.SelectedItem)
            $lboxState.ForeColor = [System.Drawing.Color]::Black
        }

        if (-1 -ge $lboxCountry.SelectedIndex)
        {
            Update-WizardProgress "Select a Country"
            $lboxCountry.ForeColor = [System.Drawing.Color]::Red
            $dnsError = $true
        }
        else
        {
            $certRequest += (",C={0}" -f $lboxCountry.SelectedItem)
            $lboxCountry.ForeColor = [System.Drawing.Color]::Black
        }


        if ($dnsError -eq $true)
        {
            Write-Warning -Message "Invalid request, please complete all fields...."
            Update-WizardProgress "Invalid request, please complete all fields listed above...."
            $textboxWizardProgress.ForeColor = [System.Drawing.Color]::Red
            $Button1.Text = "Generate"
            $Button1.Enabled = $true
        }
        else
        {


            $certstatusmsg = ""
            $certstatusmsg += (@"
[Version]
Signature="`$Windows NT$"

[NewRequest]
Subject = "{0}" ; Remove to use an empty Subject name. 
;Because SSL/TLS does not require a Subject name when a SAN extension is included, the certificate Subject name can be empty.
;If you are using another protocol, verify the certificate requirements. 
FriendlyName = "{1}"
Exportable = TRUE; TRUE = Private key is exportable
KeyLength = 2048; Valid key sizes: 1024, 2048, 4096, 8192, 16384
KeySpec = 1; Key Exchange Required for encryption
KeyUsage = 0xA0; Digital Signature, Key Encipherment
MachineKeySet = True
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
HashAlgorithm = SHA256

RequestType = PKCS10 ; or CMC.


[EnhancedKeyUsageExtension]
{2}

{3}

CertificateTemplate = {4}  ; Modify for your environment by using the LDAP common name of the template.
"@ -f $certRequest, $tbFriendly.Text, $keyUsage, $sanCert, $certTemplate)


            $Isboxadmin = Test-IsLocalAdmin -identity $script:identity -Verbose:$VerbosePreference
            If ($Isboxadmin -eq $false)
            {
                Update-WizardProgress "Is User Local Admin returns FALSE"
            }
            else
            {
                Update-WizardProgress "Is User Local Admin returns TRUE"
            }

            $filenameInf = ("{0}-{1}.inf" -f $certtype, ($tbFriendly.text -replace $pattern, ""))
            if ($certsanstatus -eq $true)
            {
                $filenameInf = "san-" + $filenameInf 
            }

            $script:certfilename = Join-Path -Path $certPath -ChildPath $filenameInf
            $script:xmlfilename = $script:certfilename.Replace(".inf", ".xml")

            Update-WizardProgress ("Outputting file {0}" -f $script:certfilename)
            Update-WizardProgress ("Friendly Name: {0} outputted to File => [{1}]" -f $tbFriendly.Text, $script:certfilename)
            $certstatusmsg |  Out-File -FilePath $script:certfilename -Force

            $certObj = @{
                cn             = $tbCN.Text
                ou             = $tbOrgUnit.Text
                o              = $tbOrg.Text
                l              = $tbLocation.Text
                st             = $lboxState.SelectedItem
                c              = $lboxCountry.SelectedItem
                friendlyName   = $tbFriendly.Text
                usageExtension = $keyUsage
                dns            = $certdnsarray
                template       = $certTemplate
                serialNumber   = ""
                base64         = ""
            }
            $certPsObject = New-Object PSObject -Property $certObj
            $certXml = ConvertTo-Xml -Depth 7 -as "Document" -InputObject $certPsObject
            $certXml.Save($Script:xmlfilename)

            $Button1.Text = "Generate"
            $Button1.Enabled = $true        
        }   
    }

	
    $Form_StateCorrection_Load =
    {
        #Correct the initial state of the form to prevent the .Net maximized form issue
        $MainForm.WindowState = $InitialFormWindowState
    }
	
    $Form_StoreValues_Closing =
    {

    }
	
    $Form_Cleanup_FormClosed =
    {
        #Store the control values
        Write-Verbose -Message ("# Will generate the REQ file for the Certificate authority")
        Write-Verbose -Message ""
        Write-Warning -Message ("Use this command:")
        Write-Warning -Message (">>> .\certificates\certProcess.ps1 -FriendlyName ""{0}"" -GenerateREQ -infFilename ""{1}"" -Verbose" -f $tbFriendly.Text, $script:xmlfilename.Replace(".xml", ".inf"))

                
        #Remove all event handlers from the controls
        try
        {
            $Button1.remove_Click($buttonStart_Click)
            $MainForm.remove_Load($OnLoadFormEvent)
            $MainForm.remove_Load($Form_StateCorrection_Load)
            $MainForm.remove_Closing($Form_StoreValues_Closing)
            $MainForm.remove_FormClosed($Form_Cleanup_FormClosed)
        }
        catch [Exception]
        { }
    }

    $MainForm = New-Object system.Windows.Forms.Form
    $MainForm.ClientSize = New-Object System.Drawing.Size(640, 700) #'700,700'
    $MainForm.text = "Certificate Generation Form"
    $MainForm.TopMost = $false

    $Groupbox1 = New-Object system.Windows.Forms.Groupbox
    $Groupbox1.Size = New-Object System.Drawing.Size(415, 300)
    $Groupbox1.BackColor = "#dad2d2"
    $Groupbox1.text = "Subject Details"
    $Groupbox1.location = New-Object System.Drawing.Point(3, 12)

    #region begin Group Box [Subject Details]

    $lbFriendly = New-Object system.Windows.Forms.Label
    $lbFriendly.text = "Friendly Name:"
    $lbFriendly.AutoSize = $true
    $lbFriendly.Size = New-Object System.Drawing.Size(25, 20)
    $lbFriendly.location = New-Object System.Drawing.Point(12, 25)
    $lbFriendly.Font = 'Microsoft Sans Serif,10'

    $tbFriendly = New-Object system.Windows.Forms.TextBox
    $tbFriendly.Text = $FriendlyName
    $tbFriendly.TabIndex = 2
    $tbFriendly.multiline = $false
    $tbFriendly.Size = New-Object System.Drawing.Size(200, 20)
    $tbFriendly.location = New-Object System.Drawing.Point(145, 25)
    $tbFriendly.Font = 'Microsoft Sans Serif,10'

    $lbCN = New-Object system.Windows.Forms.Label
    $lbCN.text = "CN"
    $lbCN.AutoSize = $true
    $lbCN.Size = New-Object System.Drawing.Size(25, 20)
    $lbCN.location = New-Object System.Drawing.Point(12, 65)
    $lbCN.Font = 'Microsoft Sans Serif,10'

    $tbCN = New-Object system.Windows.Forms.TextBox
    $tbCN.TabIndex = 3
    $tbCN.multiline = $false
    $tbCN.Size = New-Object System.Drawing.Size(200, 20)
    $tbCN.location = New-Object System.Drawing.Point(145, 65)
    $tbCN.Font = 'Microsoft Sans Serif,10'

    $lbOrg = New-Object system.Windows.Forms.Label
    $lbOrg.text = "Org"
    $lbOrg.AutoSize = $true
    $lbOrg.Size = New-Object System.Drawing.Size(25, 20)
    $lbOrg.location = New-Object System.Drawing.Point(12, 100)
    $lbOrg.Font = 'Microsoft Sans Serif,10'

    $tbOrg = New-Object system.Windows.Forms.TextBox
    $tbOrg.TabIndex = 4
    $tbOrg.multiline = $false
    $tbOrg.Size = New-Object System.Drawing.Size(200, 20)
    $tbOrg.location = New-Object System.Drawing.Point(145, 100)
    $tbOrg.Font = 'Microsoft Sans Serif,10'


    $lbOrgUnit = New-Object system.Windows.Forms.Label
    $lbOrgUnit.text = "Org Unit"
    $lbOrgUnit.AutoSize = $true
    $lbOrgUnit.Size = New-Object System.Drawing.Size(25, 20)
    $lbOrgUnit.location = New-Object System.Drawing.Point(12, 135)
    $lbOrgUnit.Font = 'Microsoft Sans Serif,10'

    $tbOrgUnit = New-Object system.Windows.Forms.TextBox
    $tbOrgUnit.TabIndex = 5
    $tbOrgUnit.multiline = $false
    $tbOrgUnit.Size = New-Object System.Drawing.Size(200, 20)
    $tbOrgUnit.location = New-Object System.Drawing.Point(145, 135)
    $tbOrgUnit.Font = 'Microsoft Sans Serif,10'

    $lbLocation = New-Object system.Windows.Forms.Label
    $lbLocation.text = "Location"
    $lbLocation.AutoSize = $true
    $lbLocation.Size = New-Object System.Drawing.Size(25, 20)
    $lbLocation.location = New-Object System.Drawing.Point(12, 175)
    $lbLocation.Font = 'Microsoft Sans Serif,10'

    $tbLocation = New-Object system.Windows.Forms.TextBox
    $tbLocation.TabIndex = 6
    $tbLocation.multiline = $false
    $tbLocation.Size = New-Object System.Drawing.Size(200, 20)
    $tbLocation.location = New-Object System.Drawing.Point(145, 175)
    $tbLocation.Font = 'Microsoft Sans Serif,10'

    $lbState = New-Object system.Windows.Forms.Label
    $lbState.text = "State"
    $lbState.AutoSize = $true
    $lbState.Size = New-Object System.Drawing.Size(25, 20)
    $lbState.location = New-Object System.Drawing.Point(12, 210)
    $lbState.Font = 'Microsoft Sans Serif,10'

    $lboxState = New-Object system.Windows.Forms.ListBox
    $lboxState.TabIndex = 7
    $lboxState.text = "State"
    $lboxState.Size = New-Object System.Drawing.Size(200, 45)
    @('Maryland', 'Virginia', 'District of Columbia') | ForEach-Object { [void] $lboxState.Items.Add($_) }
    $lboxState.location = New-Object System.Drawing.Point(145, 210)

    $lbCountry = New-Object system.Windows.Forms.Label
    $lbCountry.text = "Country"
    $lbCountry.AutoSize = $true
    $lbCountry.Size = New-Object System.Drawing.Size(25, 20)
    $lbCountry.location = New-Object System.Drawing.Point(12, 260)
    $lbCountry.Font = 'Microsoft Sans Serif,10'

    $lboxCountry = New-Object system.Windows.Forms.ListBox
    $lboxCountry.TabIndex = 8
    $lboxCountry.text = "listBox"
    $lboxCountry.Size = New-Object System.Drawing.Size(75, 35)
    @('US') | ForEach-Object { [void] $lboxCountry.Items.Add($_) }
    $lboxCountry.location = New-Object System.Drawing.Point(145, 260)

    #endregion Group Box

        
    $GroupPurpose = New-Object system.Windows.Forms.Groupbox
    $GroupPurpose.BackColor = "#dad2d2"
    $GroupPurpose.Size = New-Object System.Drawing.Size(215, 300)
    $GroupPurpose.text = "Purpose:"
    $GroupPurpose.location = New-Object System.Drawing.Point(425, 12)


    $lbRadioButton2 = New-Object System.Windows.Forms.Label
    $lbRadioButton2.size = New-Object System.Drawing.Size(175, 40)
    $lbRadioButton2.location = New-Object System.Drawing.Point(13, 40)
    $lbRadioButton2.text = "Click the radio button to generate a certificate for client authentication"
    $lbRadioButton2.Font = 'Microsoft Sans Serif,8'
    $lbRadioButton2.TabIndex = 9
    $lbRadioButton2.AutoSize = $false

    $RadioButton2 = New-Object System.Windows.Forms.RadioButton
    $RadioButton2.size = New-Object System.Drawing.Size(104, 20)
    $RadioButton2.location = New-Object System.Drawing.Point(13, 80)
    $RadioButton2.text = "Client Auth"
    $RadioButton2.TabIndex = 9
    $RadioButton2.AutoSize = $true
    $RadioButton3 = New-Object System.Windows.Forms.RadioButton
    $RadioButton3.size = New-Object System.Drawing.Size(104, 20)
    $RadioButton3.location = New-Object System.Drawing.Point(13, 120)
    $RadioButton3.text = "<none>"
    $RadioButton3.TabIndex = 9
    $RadioButton3.AutoSize = $true



    $GroupDNS = New-Object system.Windows.Forms.Groupbox
    $GroupDNS.BackColor = "#CCD6DD"
    $GroupDNS.text = "DNS:"
    $GroupDNS.Size = New-Object System.Drawing.Size(637, 250)
    $GroupDNS.location = New-Object System.Drawing.Point(3, 315)

    #region begin Group Box [DNS]

    $dns1 = New-Object system.Windows.Forms.Label
    $dns1.text = "DNS 1"
    $dns1.AutoSize = $true
    $dns1.Size = New-Object System.Drawing.Size(20, 20)
    $dns1.location = New-Object System.Drawing.Point(20, 15)
    $dns1.Font = 'Microsoft Sans Serif,10'
    $tbdns1 = New-Object system.Windows.Forms.TextBox
    $tbdns1.TabIndex = 11
    $tbdns1.multiline = $false
    $tbdns1.size = New-Object System.Drawing.Size(196, 20)
    $tbdns1.location = New-Object System.Drawing.Point(100, 15)
    $tbdns1.Font = 'Microsoft Sans Serif,10'
    $Lbdns1ref = New-Object system.Windows.Forms.Label
    $Lbdns1ref.text = "DNS 1 Ref:"
    $Lbdns1ref.AutoSize = $true
    $Lbdns1ref.Size = New-Object System.Drawing.Size(20, 20)
    $Lbdns1ref.location = New-Object System.Drawing.Point(320, 15)
    $Lbdns1ref.Font = 'Microsoft Sans Serif,10'
    $tbdns1ref = New-Object system.Windows.Forms.TextBox
    $tbdns1ref.TabIndex = 12
    $tbdns1ref.multiline = $false
    $tbdns1ref.Size = New-Object System.Drawing.Size(140, 20)
    $tbdns1ref.location = New-Object System.Drawing.Point(428, 15)
    $tbdns1ref.Font = 'Microsoft Sans Serif,10'


    $dns2 = New-Object system.Windows.Forms.Label
    $dns2.text = "DNS 2"
    $dns2.AutoSize = $true
    $dns2.Size = New-Object System.Drawing.Size(20, 20)
    $dns2.location = New-Object System.Drawing.Point(20, 42)
    $dns2.Font = 'Microsoft Sans Serif,10'
    $tbdns2 = New-Object system.Windows.Forms.TextBox
    $tbdns2.TabIndex = 13
    $tbdns2.multiline = $false
    $tbdns2.size = New-Object System.Drawing.Size(196, 20)
    $tbdns2.location = New-Object System.Drawing.Point(100, 42)
    $tbdns2.Font = 'Microsoft Sans Serif,10'
    $Lbdns2ref = New-Object system.Windows.Forms.Label
    $Lbdns2ref.text = "DNS 2 Ref:"
    $Lbdns2ref.AutoSize = $true
    $Lbdns2ref.Size = New-Object System.Drawing.Size(20, 20)
    $Lbdns2ref.location = New-Object System.Drawing.Point(320, 42)
    $Lbdns2ref.Font = 'Microsoft Sans Serif,10'
    $tbdns2ref = New-Object system.Windows.Forms.TextBox
    $tbdns2ref.TabIndex = 14
    $tbdns2ref.multiline = $false
    $tbdns2ref.Size = New-Object System.Drawing.Size(140, 20)
    $tbdns2ref.location = New-Object System.Drawing.Point(428, 42)
    $tbdns2ref.Font = 'Microsoft Sans Serif,10'


    $dns3 = New-Object system.Windows.Forms.Label
    $dns3.text = "DNS 3"
    $dns3.AutoSize = $true
    $dns3.Size = New-Object System.Drawing.Size(20, 20)
    $dns3.location = New-Object System.Drawing.Point(20, 69)
    $dns3.Font = 'Microsoft Sans Serif,10'
    $tbdns3 = New-Object system.Windows.Forms.TextBox
    $tbdns3.TabIndex = 15
    $tbdns3.multiline = $false
    $tbdns3.size = New-Object System.Drawing.Size(196, 20)
    $tbdns3.location = New-Object System.Drawing.Point(100, 69)
    $tbdns3.Font = 'Microsoft Sans Serif,10'
    $Lbdns3ref = New-Object system.Windows.Forms.Label
    $Lbdns3ref.text = "DNS 3 Ref:"
    $Lbdns3ref.AutoSize = $true
    $Lbdns3ref.Size = New-Object System.Drawing.Size(20, 20)
    $Lbdns3ref.location = New-Object System.Drawing.Point(320, 69)
    $Lbdns3ref.Font = 'Microsoft Sans Serif,10'
    $tbdns3ref = New-Object system.Windows.Forms.TextBox
    $tbdns3ref.TabIndex = 16
    $tbdns3ref.multiline = $false
    $tbdns3ref.Size = New-Object System.Drawing.Size(140, 20)
    $tbdns3ref.location = New-Object System.Drawing.Point(428, 69)
    $tbdns3ref.Font = 'Microsoft Sans Serif,10'


    $dns4 = New-Object system.Windows.Forms.Label
    $dns4.text = "DNS 4"
    $dns4.AutoSize = $true
    $dns4.Size = New-Object System.Drawing.Size(20, 20)
    $dns4.location = New-Object System.Drawing.Point(20, 96)
    $dns4.Font = 'Microsoft Sans Serif,10'
    $tbdns4 = New-Object system.Windows.Forms.TextBox
    $tbdns4.TabIndex = 17
    $tbdns4.multiline = $false
    $tbdns4.size = New-Object System.Drawing.Size(196, 20)
    $tbdns4.location = New-Object System.Drawing.Point(100, 96)
    $tbdns4.Font = 'Microsoft Sans Serif,10'
    $Lbdns4ref = New-Object system.Windows.Forms.Label
    $Lbdns4ref.text = "DNS 4 Ref:"
    $Lbdns4ref.AutoSize = $true
    $Lbdns4ref.Size = New-Object System.Drawing.Size(20, 20)
    $Lbdns4ref.location = New-Object System.Drawing.Point(320, 96)
    $Lbdns4ref.Font = 'Microsoft Sans Serif,10'
    $tbdns4ref = New-Object system.Windows.Forms.TextBox
    $tbdns4ref.TabIndex = 18
    $tbdns4ref.multiline = $false
    $tbdns4ref.Size = New-Object System.Drawing.Size(140, 20)
    $tbdns4ref.location = New-Object System.Drawing.Point(428, 96)
    $tbdns4ref.Font = 'Microsoft Sans Serif,10'
    

    $dns5 = New-Object system.Windows.Forms.Label
    $dns5.text = "DNS 5"
    $dns5.AutoSize = $true
    $dns5.Size = New-Object System.Drawing.Size(20, 20)
    $dns5.location = New-Object System.Drawing.Point(20, 123)
    $dns5.Font = 'Microsoft Sans Serif,10'
    $tbdns5 = New-Object system.Windows.Forms.TextBox
    $tbdns5.TabIndex = 19
    $tbdns5.multiline = $false
    $tbdns5.size = New-Object System.Drawing.Size(196, 20)
    $tbdns5.location = New-Object System.Drawing.Point(100, 123)
    $tbdns5.Font = 'Microsoft Sans Serif,10'
    $lbdnsref5 = New-Object system.Windows.Forms.Label
    $lbdnsref5.text = "DNS 5 Ref:"
    $lbdnsref5.AutoSize = $true
    $lbdnsref5.Size = New-Object System.Drawing.Size(20, 20)
    $lbdnsref5.location = New-Object System.Drawing.Point(320, 123)
    $lbdnsref5.Font = 'Microsoft Sans Serif,10'
    $tbdnsref5 = New-Object system.Windows.Forms.TextBox
    $tbdnsref5.TabIndex = 20
    $tbdnsref5.multiline = $false
    $tbdnsref5.Size = New-Object System.Drawing.Size(140, 20)
    $tbdnsref5.location = New-Object System.Drawing.Point(428, 123)
    $tbdnsref5.Font = 'Microsoft Sans Serif,10'

    $dns6 = New-Object system.Windows.Forms.Label
    $dns6.text = "DNS 6"
    $dns6.AutoSize = $true
    $dns6.Size = New-Object System.Drawing.Size(20, 20)
    $dns6.location = New-Object System.Drawing.Point(20, 150)
    $dns6.Font = 'Microsoft Sans Serif,10'
    $tbdns6 = New-Object system.Windows.Forms.TextBox
    $tbdns6.TabIndex = 21
    $tbdns6.multiline = $false
    $tbdns6.size = New-Object System.Drawing.Size(196, 20)
    $tbdns6.location = New-Object System.Drawing.Point(100, 150)
    $tbdns6.Font = 'Microsoft Sans Serif,10'
    $lbdnsref6 = New-Object system.Windows.Forms.Label
    $lbdnsref6.text = "DNS 6 Ref:"
    $lbdnsref6.AutoSize = $true
    $lbdnsref6.Size = New-Object System.Drawing.Size(20, 20)
    $lbdnsref6.location = New-Object System.Drawing.Point(320, 150)
    $lbdnsref6.Font = 'Microsoft Sans Serif,10'
    $tbdnsref6 = New-Object system.Windows.Forms.TextBox
    $tbdnsref6.TabIndex = 22
    $tbdnsref6.multiline = $false
    $tbdnsref6.Size = New-Object System.Drawing.Size(140, 20)
    $tbdnsref6.location = New-Object System.Drawing.Point(428, 150)
    $tbdnsref6.Font = 'Microsoft Sans Serif,10'

    $dns7 = New-Object system.Windows.Forms.Label
    $dns7.text = "DNS 7"
    $dns7.AutoSize = $true
    $dns7.Size = New-Object System.Drawing.Size(20, 20)
    $dns7.location = New-Object System.Drawing.Point(20, 177)
    $dns7.Font = 'Microsoft Sans Serif,10'
    $tbdns7 = New-Object system.Windows.Forms.TextBox
    $tbdns7.TabIndex = 23
    $tbdns7.multiline = $false
    $tbdns7.size = New-Object System.Drawing.Size(196, 20)
    $tbdns7.location = New-Object System.Drawing.Point(100, 177)
    $tbdns7.Font = 'Microsoft Sans Serif,10'
    $lbdnsref7 = New-Object system.Windows.Forms.Label
    $lbdnsref7.text = "DNS 7 Ref:"
    $lbdnsref7.AutoSize = $true
    $lbdnsref7.Size = New-Object System.Drawing.Size(20, 20)
    $lbdnsref7.location = New-Object System.Drawing.Point(320, 177)
    $lbdnsref7.Font = 'Microsoft Sans Serif,10'
    $tbdnsref7 = New-Object system.Windows.Forms.TextBox
    $tbdnsref7.TabIndex = 24
    $tbdnsref7.multiline = $false
    $tbdnsref7.Size = New-Object System.Drawing.Size(140, 20)
    $tbdnsref7.location = New-Object System.Drawing.Point(428, 177)
    $tbdnsref7.Font = 'Microsoft Sans Serif,10'
    
    $dns8 = New-Object system.Windows.Forms.Label
    $dns8.text = "DNS 8"
    $dns8.AutoSize = $true
    $dns8.Size = New-Object System.Drawing.Size(20, 20)
    $dns8.location = New-Object System.Drawing.Point(20, 204)
    $dns8.Font = 'Microsoft Sans Serif,10'
    $tbdns8 = New-Object system.Windows.Forms.TextBox
    $tbdns8.TabIndex = 25
    $tbdns8.multiline = $false
    $tbdns8.size = New-Object System.Drawing.Size(196, 20)
    $tbdns8.location = New-Object System.Drawing.Point(100, 204)
    $tbdns8.Font = 'Microsoft Sans Serif,10'
    $lbdnsref8 = New-Object system.Windows.Forms.Label
    $lbdnsref8.text = "DNS 8 Ref:"
    $lbdnsref8.AutoSize = $true
    $lbdnsref8.Size = New-Object System.Drawing.Size(20, 20)
    $lbdnsref8.location = New-Object System.Drawing.Point(320, 204)
    $lbdnsref8.Font = 'Microsoft Sans Serif,10'
    $tbdnsref8 = New-Object system.Windows.Forms.TextBox
    $tbdnsref8.TabIndex = 26
    $tbdnsref8.multiline = $false
    $tbdnsref8.Size = New-Object System.Drawing.Size(140, 20)
    $tbdnsref8.location = New-Object System.Drawing.Point(428, 204)
    $tbdnsref8.Font = 'Microsoft Sans Serif,10'

    #endregion


    $Button1 = New-Object system.Windows.Forms.Button
    $Button1.TabIndex = 29
    $Button1.text = "Generate"
    $Button1.Size = New-Object System.Drawing.Size(135, 30)
    $Button1.location = New-Object System.Drawing.Point(3, 565)
    $Button1.Font = 'Microsoft Sans Serif,10'
    $Button1.add_Click($buttonStart_Click)

    #
    # textboxWizardProgress
    #
    $textboxWizardProgress = New-Object 'System.Windows.Forms.TextBox'
    $textboxWizardProgress.Font = "Microsoft Sans Serif, 8pt"
    $textboxWizardProgress.Location = New-Object System.Drawing.Point(140, 565)
    $textboxWizardProgress.Name = "textboxWizardProgress"
    $textboxWizardProgress.Size = New-Object System.Drawing.Size(498, 120)
    $textboxWizardProgress.TabIndex = 30
    $textboxWizardProgress.Text = "Cert Configuration Wizard Progress`r`n"
    $textboxWizardProgress.TextAlign = 'Left'
    $textboxWizardProgress.Multiline = $true
    $textboxWizardProgress.ScrollBars = "Vertical"
    $textboxWizardProgress.AcceptsReturn = "true"
    $textboxWizardProgress.WordWrap = "true"
    $textboxWizardProgress.AutoScrollOffset = 1

        
    $MainForm.Controls.Add($Groupbox1)
    $MainForm.Controls.Add($GroupPurpose)
    $MainForm.Controls.Add($GroupDNS)
        
    $Groupbox1.Controls.Add($lbFriendly)
    $Groupbox1.Controls.Add($tbFriendly)
    $Groupbox1.Controls.Add($lbCN)
    $Groupbox1.Controls.Add($tbCN)
    $Groupbox1.Controls.Add($lbOrg)
    $Groupbox1.Controls.Add($tbOrg)
    $Groupbox1.Controls.Add($lbOrgUnit)
    $Groupbox1.Controls.Add($tbOrgUnit)
    $Groupbox1.Controls.Add($lbLocation)
    $Groupbox1.Controls.Add($tbLocation)
    $Groupbox1.Controls.Add($lbState)
    $Groupbox1.Controls.Add($lboxState)
    $Groupbox1.Controls.Add($lbCountry)
    $Groupbox1.Controls.Add($lboxCountry)
    $GroupPurpose.Controls.Add($lbRadioButton2)
    $GroupPurpose.Controls.Add($RadioButton2)
    $GroupPurpose.Controls.Add($RadioButton3)

    $GroupDNS.Controls.Add($dns1)
    $GroupDNS.Controls.Add($tbdns1)
    $GroupDNS.Controls.Add($Lbdns1ref)
    $GroupDNS.Controls.Add($tbdns1ref)
    $GroupDNS.Controls.Add($dns2)
    $GroupDNS.Controls.Add($tbdns2)
    $GroupDNS.Controls.Add($Lbdns2ref)
    $GroupDNS.Controls.Add($tbdns2ref)
    $GroupDNS.Controls.Add($dns3)
    $GroupDNS.Controls.Add($tbdns3)
    $GroupDNS.Controls.Add($Lbdns3ref)
    $GroupDNS.Controls.Add($tbdns3ref)
    $GroupDNS.Controls.Add($dns4)
    $GroupDNS.Controls.Add($tbdns4)
    $GroupDNS.Controls.Add($Lbdns4ref)
    $GroupDNS.Controls.Add($tbdns4ref)
    $GroupDNS.Controls.Add($dns5)
    $GroupDNS.Controls.Add($tbdns5)
    $GroupDNS.Controls.Add($Lbdnsref5)
    $GroupDNS.Controls.Add($tbdnsref5)
    $GroupDNS.Controls.Add($dns6)
    $GroupDNS.Controls.Add($tbdns6)
    $GroupDNS.Controls.Add($Lbdnsref6)
    $GroupDNS.Controls.Add($tbdnsref6)
    $GroupDNS.Controls.Add($dns7)
    $GroupDNS.Controls.Add($tbdns7)
    $GroupDNS.Controls.Add($Lbdnsref7)
    $GroupDNS.Controls.Add($tbdnsref7)
    $GroupDNS.Controls.Add($dns8)
    $GroupDNS.Controls.Add($tbdns8)
    $GroupDNS.Controls.Add($Lbdnsref8)
    $GroupDNS.Controls.Add($tbdnsref8)

    $MainForm.controls.AddRange(@($Button1, $textboxWizardProgress))



    #Write your logic code here
    #Save the initial state of the form
    $InitialFormWindowState = $MainForm.WindowState
    #Init the OnLoad event to correct the initial state of the form
    $MainForm.add_Load($Form_StateCorrection_Load)
    #Clean up the control events
    $MainForm.add_FormClosed($Form_Cleanup_FormClosed)
    #Store the control values when form is closing
    $MainForm.add_Closing($Form_FormClosing)
    #Show the Form
    [void] $MainForm.ShowDialog()

} 
END
{
    # Closing out the GUI
    Write-Verbose "Closing out the GUI"
}