
function Send-EmailMessage
{
    <#
        .SYNOPSIS
        Sends an email via SendGrid
        .DESCRIPTION
        Sends an email via SendGrid using the connection object settings. Requires a valid ModuleAzureAutomation connection object.
        .PARAMETER Subject
        Specifies the subject of the email.
        .PARAMETER Message
        Specifies the email body.
        .PARAMETER To
        Specifies the recipient of the email.
        .PARAMETER Connection
        Specifies a hashtable returned from the Get-AutomationConnection activity, containing the ModuleAzureAutomation connection object.
        .INPUTS
        None. You cannot pipe objects to Send-EmailMessage.
        .OUTPUTS
        System.Bool Send-EmailMessage returns a true or false success result of the activity.
    #>  
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName='ConnectionObject')]
    [OutputType([bool])]
    Param(
        [parameter(ParameterSetName='ConnectionObject', Mandatory=$true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]$Connection,

        [Parameter(Mandatory = $true)]
        [String]$Subject,

        [Parameter(Mandatory = $true)]
        [String]$Message,

        [Parameter(Mandatory = $true)]
        [String]$To
    )
	begin 
	{
		Out-AzureCMTimestamp ("[BEGIN] SMTP Email Message to {0}" -f $To)
		if($Connection -eq $null)
		{
			throw("Smtp Connection not found.")
		}
		$smtp = $Connection.SendGridServer
		$smtpport = $Connection.SendGridPort
		$username = $Connection.SendGridUsername
		$securepassword = $Connection.SendGridPassword
		$smtpfrom = $Connection.SmtpFrom
	}
	process
	{
		try 
		{
			$passkey = ConvertTo-SecureString $securepassword -AsPlainText -Force
		    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $passkey

			Send-MailMessage -To $To -From $smtpfrom `
				-Body $Message -Subject $Subject `
				-UseSsl -Port $smtpport -Credential $cred -SmtpServer $smtp

			Out-AzureCMTimestamp "Completed sending message"
			return $true
		}
		catch [System.Net.WebException]
		{
			Write-Error -Exception $_.Exception
		}
		return $false
	}
	end
	{
		Out-AzureCMTimestamp ("[END] SMTP Email Message to {0}" -f $To)
	}
}

function Connect-AzureCMSubscription
{
	<#
	.SYNOPSIS 
		Sets up the connection to an Azure subscription
	.DESCRIPTION
		This runbook sets up a connection to an Azure subscription.
		Requirements: 
			1. Active Directory User with Service Administrator permissions
			2. Automation Connection for PS Credentials
     .PARAMETER CredentialVariableName
        Specifies the Azure asset variable
    .PARAMETER SubscriptionId
        Specifies the subscription id to connect
    .PARAMETER Environment
        Specifies the Azure environment for specific service management APIs
	.EXAMPLE
		Connect-AzureCMSubscription
	.NOTES
		AUTHOR: shawn Leonard
		LASTEDIT: Jan 5, 2015
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName = "ConnectionObject")]
	Param
    (      
        [Parameter(ParameterSetName = "ConnectionObject", Mandatory = $true, Position = 1)]
        [string]$CredentialVariableName,
		
        [Parameter(ParameterSetName = "ConnectionObject", Mandatory = $true, Position = 2)]
        [string]$SubscriptionId,

        [Parameter(Mandatory=$true, Position = 3)] 
        [string]$EnvironmentName
    )
	begin
	{
		if($SubscriptionId -eq $null) {
			throw "Could not retrieve Subscription Id connection"
		}

		if($EnvironmentName -ne "Azure" -and $EnvironmentName -ne "AzureUSGovernment") {
			throw "Please specify an EnvironmentName (Azure, AzureUSGovernment)"
		}
	}
	process
	{
	# Get Environment for settings
		$azureEnvironment = Get-AzureEnvironment -Name $EnvironmentName
		Write-Output ("{0} Environment successfully added" -f $azureEnvironment.Name)

	# Get the Azure connection asset that is stored in the Auotmation service based on the name that was passed into the runbook 
		$AzureConn = Get-automationPSCredential -name $CredentialVariableName
		if ($AzureConn -eq $null)
		{
			throw "Could not retrieve '$CredentialVariableName' connection asset."
		}

	# Get the Azure management certificate that is used to connect to this subscription
		Add-AzureAccount -Credential $AzureConn -Environment $azureEnvironment.Name | Out-Null
		Select-AzureSubscription -SubscriptionId $SubscriptionId | Out-Null
		Out-AzureCMTimestamp "Successfully connected to the subscription."
	}
}

function Get-AzureCMCopyStorageKey
{
    <#
    .Synopsis
        Leverages a series of CSVs identifying Azure Storage blobs to mass migrate an environment
    .DESCRIPTION
        Process blobs/disks from one subscription or one storage account to new subscriptions or new storage accounts
    .PARAMETER csvOfKeys
        Specifies a collection of storage accounts and their keys
    .PARAMETER accountName
        Specifies a destination storage account from which to create a storage context
    #>
	[CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
		[Parameter(Mandatory = $true)]
		[PSCustomObject[]]$csvOfKeys, 

		[Parameter(Mandatory = $true)]
		[string]$accountName
	) 
	begin
	{
		Out-AzureCMTimestamp ("Retrieving Storage Key {0} From CSV File" -f $accountName)
	}
	process 
	{
		$acctWithKey = $csvOfKeys | where-object { $_.StorageAccount -eq $accountName }
		if($acctWithKey -ne $null) {
			$storageEnvironment = "AzureCloud"
            if(Get-Member -inputobject $acctWithKey -name "StorageType" -Membertype Properties) {
				$storageEnvironment = $acctWithKey.StorageType
			}
			$acctContext = New-AzureStorageContext �StorageAccountName $accountName -StorageAccountKey $acctWithKey.StorageKey -Environment $storageEnvironment
			return $acctContext  
		}
		return $null
	}
}

function Get-AzureCMStorageConnectionString
{
	<# 
		.Synopsis
			This function create a Storage Account if it don't exists.

		.DESCRIPTION
			This function will create a string connection for a storage account

		.OUTPUTS
			Storage Account connectionString
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
    [OutputType([System.Collections.Hashtable])]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$StorageAccountName,

        [Parameter(Mandatory = $true)]
        [String]$Environment,

        [switch]$SecondaryStorage
    )
    begin
    {
        Out-AzureCMTimestamp ("[Begin] retrieve Storage account {0} connection" -f $StorageAccountName)
    }
    process
    {
        try
        {
            $storageAccount= Get-AzureStorageAccount -StorageAccountName $StorageAccountName -ErrorAction Stop
            Out-AzureCMTimestamp ("Storage account {0} in location {1} exist" -f $StorageAccountName, $StorageLocation)

            # Get the access key of the storage account
            $storagekey = Get-AzureStorageKey -StorageAccountName $StorageAccountName

            # Generate the connection string of the storage account
			$storageConnect = Get-AzureCMTableConnection -StorageAccountName $StorageAccountName -StorageKey $storagekey.Secondary -Environment $Environment

			if($SecondaryStorage) {
				Return @{ConnectionString = $storageConnect.SecondaryUri}
			}
            Return @{ConnectionString = $storageConnect.PrimaryUri}
        }
        catch
        {
        }
    }
    end
    {
        Out-AzureCMTimestamp ("[END] retrieve Storage account {0} connection" -f $StorageAccountName)
    }
}

function Get-AzureCMStorageBlobToTemp
{
    <#
        .SYNOPSIS
        Get or Create a Blob which contains the Versioned Web Package to be deployed
        .DESCRIPTION
        Write data to Azure Storage Tables using the details provided.
        Requires a valid ModuleAzureStorage connection object.
        .INPUTS
        None. You cannot pipe objects to New-StorageContainer.
        .OUTPUTS
        System.Bool New-StorageContainer returns a true or false success result of the activity.
    #>  
    [CmdletBinding(DefaultParameterSetName='StorageConnection',HelpURI='http://aka.ms/SeeAzure')]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(ParameterSetName='StorageConnection',Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$StorageAccountName,

        [parameter(ParameterSetName='StorageConnection',Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$StorageAccountKey,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$ContainerName,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$StorageBlob
    )
	begin
	{
		Out-AzureCMTimestamp "Begin retreiving for azure storage blob in $ContainerName" 

        $tempFileLocation = ("{0}\Module-{1}" -f $env:TEMP)
	}
	process
	{
        $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

        $blob = Get-AzureStorageBlobContent -Blob $StorageBlob -Context $context -Container $ContainerName -Destination $tempFileLocation -Force

        return $tempFileLocation
    }
    end 
    {
        Out-AzureCMTimestamp "End retreiving for azure storage blob in $containerName"
    }
}

function Write-AzureCMTable
{
	<#
		.SYNOPSIS
			Writes a message to the Azure Table
		.DESCRIPTION
			Write data to Azure Storage Tables using the details provided.
			Requires a valid AzureStorage connection object.
		.INPUTS
			None. You cannot pipe objects.
		.OUTPUTS
			Successful write to tables.
	#>  
    [CmdletBinding(DefaultParameterSetName='AzureStorage',HelpURI='http://portal.azure.com')]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(ParameterSetName='AzureStorage',Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$StorageName,

        [parameter(ParameterSetName='AzureStorage',Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]$StorageKey,

        [parameter(Mandatory=$false)]
        [System.String]$environmentURI,

        [parameter(Mandatory=$false)]
        [string]$RowMessage
    )
    begin 
    {
        Out-AzureCMTimestamp "Begin writing error to log table"
    }
    process
    {
        # Get current time to use as timestamp for authenticating the REST request
        $timeNow = "{0:s}" -f ([System.DateTime]::UtcNow)
        $rowName = ("ErrLog-UTC:{0}" -f $timeNow)
        $metaData = @{Timestamp="$($timeNow)";Message="$($RowMessage)"}
		Write-AzureCMTableEntry -StorageAccountName $StorageName -StorageKey $storagekey -EndPointSuffix $environmentURI -TableName "Logs" -PartitionKey $rowName -RowContents $metaData
    }
    end
    {
        Out-AzureCMTimestamp "End writing error to log table"
    }
}

Function New-AzureCMStorage
{
	<# 
		.Synopsis
			This function create a Storage Account if it doesn't exists.
		.DESCRIPTION
			This function will obtain the Storage Account. If we have an exception, the Storage Account doesn�t exist then create it.
		 .PARAMETER StorageAccountName
			Specifies the cloud storage name
		.PARAMETER StorageLocation
			Specifies the region in which the storage should be created if it does not exist
		.PARAMETER StorageType
			Specifies the storage redundancy
		.PARAMETER SubscriptionId
			Specifies the subscription ID; if specified sets this as the default storage account
		.OUTPUTS
			Storage Account connectionString
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName='StorageConnection')]
	[OutputType([Microsoft.WindowsAzure.Commands.Utilities.Common.ManagementOperationContext])]
    param
	(
        [Parameter(ParameterSetName='StorageConnection',Mandatory = $true)]
		[string]$StorageAccountName,
		
        [Parameter(ParameterSetName='StorageConnection',Mandatory = $true)]
        [ValidateSet("East Asia", "Southeast Asia", "Central US", "East US", "East US 2", "USGov Iowa", "USGov Virginia")]
		[string]$StorageLocation, 
		
        [Parameter(ParameterSetName='StorageConnection',Mandatory = $true)]
		[ValidateSet("Standard_LRS", "Standard_ZRS", "Standard_GRS", "Standard_RAGRS", "Premium_LRS")]
		[string]$StorageType = "Standard_LRS",
		
        [Parameter(Mandatory = $false)]
		[string]$SubscriptionId
	)
	begin 
	{
        Out-AzureCMTimestamp ("[Begin] Storage account {0} in location {1} NewOrGet" -f $StorageAccountName, $StorageLocation)
    }
	process 
	{
        try
        {
            $myStorageAccount= Get-AzureStorageAccount -StorageAccountName $StorageAccountName -ErrorAction Stop
            $storageLocation = $myStorageAccount.Location
            Out-AzureCMTimestamp ("Storage account {0} in location {1} exist" -f $StorageAccountName, $StorageLocation)
        }
        catch
        {
            # Create a new storage account
            Write-Error $_.Exception.Message
            Out-AzureCMTimestamp ("[Start] creating storage account {0} in location {1}" -f $StorageAccountName, $StorageLocation)
            $myStorageAccount = New-AzureStorageAccount -StorageAccountName $StorageAccountName -Location $StorageLocation -Type $StorageType -Verbose
            Out-AzureCMTimestamp ("[Finish] creating storage account {0} in location {1} status {2}" -f $StorageAccountName, $StorageLocation, $myStorageAccount.OperationStatus)
            $myStorageAccount = Get-AzureStorageAccount -StorageAccountName $StorageAccountName -ErrorAction Stop
        }

		if($subscriptionId -ne $null -and $subscriptionId -ne "") {
			Set-AzureSubscription �SubscriptionId $subscriptionId �CurrentStorageAccountName $StorageAccountName
		}

		return $myStorageAccount
    }
    end
    {
        Out-AzureCMTimestamp ("[END] Storage account {0} in location {1} NewOrGet" -f $StorageAccountName, $StorageLocation)
    }
}

Function New-AzureCMVirtualMachine 
{
	<# 
		.Synopsis
			This function create a virtual machine from the PSCustomObject
		.DESCRIPTION
			This function will create a virtual machine
		 .PARAMETER vm
			Specifies the VM properties
		.PARAMETER vmLocation
			Specifies the region in which the storage should be created if it does not exist
		.PARAMETER vnet
			Specifies the virtual network into which it will be provisioned
		.PARAMETER SubscriptionId
			Specifies the subscription ID
		.PARAMETER credentials
			Specifies the credentials for any domain interactions [must be domain credentials]
		.PARAMETER azureEnvironment
			Specifies the cloud set of regions
		.OUTPUTS
			Storage Account connectionString
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
		[pscustomobject]$vm, 

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
		[string]$vmLocation, 

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
		[string]$vnet, 

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
		[string]$subscriptionId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$credentials,
		
        [Parameter(Mandatory = $false)]
		[ValidateSet("AzureUSGovernment", "AzureChinaCloud", "AzureCloud")]
		[string]$azureEnvironment = "AzureCloud"
	) 
	begin 
	{

		$service = $vm.service
		$storage = $vm.storage.ToLower() -replace "-", ""
		$availabilitySet = $vm.availset
		$netbiosName = $vm.domain.netbiosname
		$domain = $vm.domain.fqdn
		$isDC = $vm.isdc 
		if($isDC -eq $null) {
			$isDC = $false
		}

		Write-Host ""
		Out-AzureCMTimestamp "*** Configuring $($vm.name)"
		Out-AzureCMTimestamp "  * Name:    $($vm.name)"
		Out-AzureCMTimestamp "  * Service: $($service)"
		Out-AzureCMTimestamp "  * Size:    $($vm.size)"
		Out-AzureCMTimestamp "  * Subnet:  $($vm.subnet)"
		Out-AzureCMTimestamp "  * Storage: $($storage)"
		Out-AzureCMTimestamp ("  * ImageFamily: {0}" -f $vm.imageFamily)
		Write-Host ""
	}
	process 
	{
	    $user = $credentials.GetNetworkCredential().UserName
	    $pass = $credentials.GetNetworkCredential().Password

		if (!(Get-AzureVM -ServiceName $service -Name $vm.name)) {
			$stamp = Get-Date -format yyyy-MM-dd-HH-mm-ss

		    $vmImage = Get-AzureVMImage | where { $_.ImageFamily -eq $vm.imageFamily } | sort PublishedDate -Descending | select -ExpandProperty ImageName -First 1
		    $environment = Get-AzureEnvironment | Where-Object Name -eq $azureEnvironment
		    $storageacct = New-AzureCMStorage -storageaccountname $storage -storageLocation $vmLocation -storageType Standard_LRS -subscriptionId $subscriptionId
			$storagekey = Get-AzureStorageKey -StorageAccountName $storage
		    $storage = ("https://{0}.blob.{1}/vhds" -f $storage,$environment.StorageEndpointSuffix)
            $osDiskName = ("{0}/{1}-{2}-os.vhd" -f $storage,$stamp,$vm.name)

            if($availabilitySet -ne $null -and $availabilitySet.length -gt 1) {

			    $vmConfig = New-AzureVMConfig -Name $vm.name -InstanceSize $vm.size -ImageName $vmImage -MediaLocation $osDiskName -AvailabilitySetName $availabilitySet `
				    | Set-AzureSubnet $vm.subnet `
				    | Set-AzureStaticVNetIP -IPAddress $vm.ip

            }
            else {

			    $vmConfig = New-AzureVMConfig -Name $vm.name -InstanceSize $vm.size -ImageName $vmImage -MediaLocation $osDiskName `
				    | Set-AzureSubnet $vm.subnet `
				    | Set-AzureStaticVNetIP -IPAddress $vm.ip
            }


			$index = 0
			Foreach ($key in $vm.disks.Keys) {
				$disk = $vm.disks[$key]

				Out-AzureCMTimestamp "-- Adding disk: $($key) [$($disk.size) GB]"

				$vhdName = "$($stamp)-$($vm.name)-$($key)"

				$vmConfig = $vmConfig | Add-AzureDataDisk -CreateNew -DiskSizeInGB $disk.size -DiskLabel $vhdName -MediaLocation "$($storage)/$($vhdName).vhd" -LUN $index
				$index = $index + 1
			}

			If ($isDC) {
				$vmConfig | Add-AzureProvisioningConfig -Windows -AdminUsername $user -Password $pass
			} 
			Else {
				$vmConfig | Add-AzureProvisioningConfig -WindowsDomain -AdminUserName $user -Password $pass `
						-JoinDomain $domain -Domain $netbiosName -DomainPassword $pass -DomainUserName $user 
			}

            try 
            {
			    New-AzureVM -ServiceName $service -VNetName $vnet -Location $vmLocation -VMs $vmConfig -ErrorAction Stop

			    Out-AzureCMTimestamp "+++ [SUCCESS]  $($vm.name) provisioned == WaitForBoot $($vm.name)"

			    Wait-SetupForBoot -serviceName $service -vmName $vm.name

			    Install-WinRMCertificateForVM -serviceName $service -vmName $vm.name
			    Set-SetupFormatDisk -serviceName $service -vmName $vm.name -adminUserName $user -password $pass -drives $vm.disks

			    If ($isDC) {
				    $driveLetter = $vm.domain.driveletter
				    $installMode =  $vm.domain.installmode
				    $dnsname = $vm.name # ("{0}.{1}" -f $vm.name,$domain)

					$secPassword = ConvertTo-SecureString $pass -AsPlainText -Force
					$credential = New-Object System.Management.Automation.PSCredential($user, $secPassword)

				    Set-SetupConfigureDC -serviceName $service -vmName $vm.name -netbiosname $netbiosName -domain $domain -dcInstallMode $installMode `
					    -dcDrive $driveLetter -user $user -pass $pass
				    Set-SetupVNetDNSEntry -dnsServerName $dnsname -domainControllerIP $vm.ip
			    }
            }
            catch [Exception] {
                Write-Error $_
                Write-Error -Message "Failed to provision Azure Resource."
				Write-AzureCMTable -StorageName $storage -StorageKey $storagekey -environmentURI $environment.StorageEndpointSuffix -RowContents $_.Message
            }
		} else {
			Out-AzureCMTimestamp "!!! [SKIPPING] $($vm.name) already exists"
		}
	}
}

Function New-AzureCMSqlServer
{
	<#
		.Synopsis
			This script create Azure SQl Server and Database
		.EXAMPLE     How to Run this script
			New-AzureCMSqlServer -AppDatabaseName "XXXXXX" 
					-StartIPAddress "XXXXXX" 
					-EndIPAddress "XXXXXX" 
					-Location "XXXXXX 
					-FirewallRuleName ""XXXX"
		.OUTPUTS
			Database connection string in a hastable
	#>

    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	Param(
		[Parameter(Mandatory = $true)]
		[String]$AppDatabaseName,   

		[Parameter(Mandatory = $true)]
		[String]$FirewallRuleName ,            

		[Parameter(Mandatory = $FALSE)]
		[String]$StartIPAddress,               

		[Parameter(Mandatory = $FALSE)]
		[String]$EndIPAddress,       

		[Parameter(Mandatory = $true)]
		[String]$Location,       

		[Parameter(Mandatory = $true)]
		[PSCredential]$credential                        
	)
	BEGIN
	{
		#a. Detect IP range for SQL Azure whitelisting if the IP range is not specified
		If (-not ($StartIPAddress -and $EndIPAddress))
		{
			$ipRange = Get-AzureCMIPAddress -CidrMask 32
			$StartIPAddress = $ipRange.FirstUsable
			$EndIPAddress = $ipRange.LastUsable
		}
	}
	PROCESS
	{
	#c Create Server
		Write-Verbose ("[Start] creating SQL Azure database server in location {0} with username {1} and password {2}" -f $Location, $credential.UserName , $credential.GetNetworkCredential().Password)
		$databaseServer = New-AzureSqlDatabaseServer -AdministratorLogin $credential.UserName  -AdministratorLoginPassword $credential.GetNetworkCredential().Password -Location $Location
		Write-Verbose ("[Finish] creating SQL Azure database server {3} in location {0} with username {1} and password {2}" -f $Location, $credential.UserName , $credential.GetNetworkCredential().Password, $databaseServer.ServerName)

	#C. Create a SQL Azure database server firewall rule for the IP address of the machine in which this script will run
	# This will also whitelist all the Azure IP so that the website can access the database server
		Write-Verbose ("[Start] creating firewall rule {0} in database server {1} for IP addresses {2} - {3}" -f $RuleName, $databaseServer.ServerName, $StartIPAddress, $EndIPAddress)
		New-AzureSqlDatabaseServerFirewallRule -ServerName $databaseServer.ServerName -RuleName $FirewallRuleName -StartIpAddress $StartIPAddress -EndIpAddress $EndIPAddress -Verbose
		New-AzureSqlDatabaseServerFirewallRule -ServerName $databaseServer.ServerName -RuleName "AllowAllAzureIP" -StartIpAddress "0.0.0.0" -EndIpAddress "0.0.0.0" -Verbose
		Write-Verbose ("[Finish] creating firewall rule {0} in database server {1} for IP addresses {2} - {3}" -f $FirewallRuleName, $databaseServer.ServerName, $StartIPAddress, $EndIPAddress)

	#d. Create a database context which includes the server name and credential
		$context = New-AzureSqlDatabaseServerContext -ServerName $databaseServer.ServerName -Credential $credential 

	# e. Use the database context to create app database
		Write-Verbose ("[Start] creating database {0} in database server {1}" -f $AppDatabaseName, $databaseServer.ServerName)
		New-AzureSqlDatabase -DatabaseName $AppDatabaseName -Context $context -Verbose
		Write-Verbose ("[Finish] creating database {0} in database server {1}" -f $AppDatabaseName, $databaseServer.ServerName)

	#f. Generate the ConnectionString
		[string] $appDatabaseConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $databaseServer.ServerName -DatabaseName $AppDatabaseName -SqlDatabaseUserName $credential.UserName  -Password $credential.GetNetworkCredential().Password

	#g.Return Database connection string
	   Return @{ConnectionString = $appDatabaseConnectionString;}
	}
}

Function Install-WinRMCertificateForVM 
{
    <#
    .Synopsis
        Install Certificate for use in RemoteWMI or Remote Powershell connectivity
    .DESCRIPTION
        Install Certificate for use in RemoteWMI or Remote Powershell connectivity
    .PARAMETER ServiceName
        Specifies the service name for the cloud service
	.PARAMETER vmName
        Specifies the virtual machine name to which it installs certificates
    #>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
        [Parameter(Mandatory = $true)]
		[string] $serviceName, 

        [Parameter(Mandatory = $true)]
		[string] $vmName
	)
	begin
	{
		Out-AzureCMTimestamp "== Installing WinRM Certificate for remote access: $vmName"
	}
	process 
	{
		$WinRMCert = (Get-AzureVM -ServiceName $serviceName -Name $vmName | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
		$AzureX509cert = Get-AzureCertificate -ServiceName $serviceName -Thumbprint $WinRMCert -ThumbprintAlgorithm sha1

		$certTempFile = [IO.Path]::GetTempFileName()
		$AzureX509cert.Data | Out-File $certTempFile

		# Target The Cert That Needs To Be Imported
		$CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile

		$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
		$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
		$store.Add($CertToImport)
		$store.Close()
	
		Remove-Item $certTempFile
	}
}

Function Set-SetupVNetDNSEntry 
{
	<# 
		.Synopsis
			This function create a DNS entry for a DC if it does not exist
		.DESCRIPTION
			This function will create a DNS entry for a DC if it does not exist
		 .PARAMETER dnsServerName
			Specifies the DNS Server name also computer name
		.PARAMETER domainControllerIP
			Specifies the DC IP Address for VNet config
		.OUTPUTS
			None
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName='DNSConnection')]
	param
	(
        [Parameter(ParameterSetName='DNSConnection',Mandatory = $true)]
		[string] $dnsServerName, 
		
        [Parameter(ParameterSetName='DNSConnection',Mandatory = $true)]
		[string] $domainControllerIP
	)
	begin 
	{
		Out-AzureCMTimestamp ("== Adding Active Directory DNS to VNET -- DC IP is: {0}" -f $domainControllerIP)

		#Get the NetworkConfig.xml path
		$vnetConfigurationPath =  ("{0}\azure-vnet.xml" -f $env:temp)
	
		Out-AzureCMTimestamp "  -- Exporting existing VNet..."
	}
	process
	{
		Get-AzureVNetConfig -ExportToFile  $vnetConfigurationPath | Out-Null

		$namespace = "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"

		# Read the configuration file into memory	
		Write-Output "Read the configuration file into memory..."
		[xml]$doc =  Get-Content $vnetConfigurationPath
	 
		if($doc.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers -eq $null) 
		{
			Out-AzureCMTimestamp " -- Adding Dns Server node...";
			$dnsServersNode = $doc.CreateElement("DnsServers", $namespace);
			$dnsServerNode = $doc.CreateElement("DnsServer", $namespace);
			$dnsServerNode.SetAttribute('name', $dnsServerName);
			$dnsServerNode.SetAttribute('IPAddress', $domainControllerIP);
			$dnsServersNode.AppendChild($dnsServerNode);	 
			$doc.NetworkConfiguration.VirtualNetworkConfiguration.GetElementsByTagName('Dns')[0].AppendChild($dnsServersNode);
		}
		else 
		{
			Out-AzureCMTimestamp " -- Updating existing Dns Server node..."
			$dnsServerNode = $doc.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers.SelectSingleNode("descendant::*[name()='DnsServer'][@name='" + $dnsServerName +"']");
			if($dnsServerNode -eq $null)
			{
				$dnsServerNode = $doc.CreateElement("DnsServer", $namespace);
				$dnsServerNode.SetAttribute('name', $dnsServerName);
				$dnsServerNode.SetAttribute('IPAddress',$domainControllerIP);	    
				$doc.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers.AppendChild($dnsServerNode);
			}
			else
			{
				$dnsServerNode.SetAttribute('IPAddress',$domainControllerIP);	    
			}
		}
	
		$vnetSite = $doc.SelectSingleNode("/*/*/*[name()='VirtualNetworkSites']/*[name()='VirtualNetworkSite'][@name='" + $vnet + "']");
		if($vnetSite.DnsServersRef -eq $null) 
		{
			Out-AzureCMTimestamp "  -- Adding Dns Servers Ref node...";
			$dnsServersRefNode = $doc.CreateElement("DnsServersRef", $namespace);
			$dnsServerRefNode = $doc.CreateElement("DnsServerRef", $namespace);
			$dnsServerRefNode.SetAttribute('name', $dnsServerName);
			$dnsServersRefNode.AppendChild($dnsServerRefNode);	 
			$vnetSite.AppendChild($dnsServersRefNode);
		}
		else 
		{
			Out-AzureCMTimestamp "  -- Updating existing Dns Servers Ref node..."
			$dnsServerRefNode = $vnetSite.DnsServersRef.SelectSingleNode("descendant::*[name()='DnsServerRef'][@name='" + $dnsServerName +"']");
			if($dnsServerRefNode -eq $null)
			{
				$dnsServerRefNode = $doc.CreateElement("DnsServerRef", $namespace);
				$dnsServerRefNode.SetAttribute('name', $dnsServerName);
				$vnetSite.DnsServersRef.AppendChild($dnsServerRefNode);
			}
		}
	
		$doc.Save($vnetConfigurationPath)
	
		Out-AzureCMTimestamp "  == Updating VNet with Dns Server entry..."
		Set-AzureVNetConfig -ConfigurationPath $vnetConfigurationPath	
	}
}

Function Set-SetupConfigureDC 
{
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
		[Parameter(Mandatory = $true)]
		[string] $serviceName, 
		[Parameter(Mandatory = $true)]
		[string] $vmName, 
		[Parameter(Mandatory = $true)]
		[string] $netbiosName, 
		[Parameter(Mandatory = $true)]
		[string] $domain, 
		[Parameter(Mandatory = $false)]
		[ValidateSet("Default", "Win2008R2", "Win2012", "Win2012R2")]
		[string] $domainMode = "Default", 
		[Parameter(Mandatory = $false)]
		[ValidateSet("NewForest", "Replica")]
		[string] $dcInstallMode, 
		[Parameter(Mandatory = $false)]
		[string] $dcDrive, 
		[Parameter(Mandatory = $true)]
		[string] $user, 
		[Parameter(Mandatory = $true)]
		[string] $pass)
	begin 
	{
		Out-AzureCMTimestamp "== Configuring DC on $vmName"
		Out-AzureCMTimestamp "  - Service:  $serviceName"
		Out-AzureCMTimestamp "  - VM:       $vmName"
		Out-AzureCMTimestamp "  - NetBIOS:  $netbiosName"
		Out-AzureCMTimestamp "  - Domain:   $domain"
		Out-AzureCMTimestamp "  - DC Mode:  $dcInstallMode"
		Out-AzureCMTimestamp "  - DC Drive: $dcDrive"
	}
	process
	{
		#Get the hosted service WinRM Uri
		$uris = Get-AzureWinRMUri -ServiceName $serviceName -Name $vmName

		$secPassword = ConvertTo-SecureString $pass -AsPlainText -Force
		$credential = New-Object System.Management.Automation.PSCredential($user, $secPassword)

		#TODO: If no powershell endpoints exists need to create an endpoint
		$uriEndpoint = $uris[0]

		$maxRetry = 5
		For($retry = 0; $retry -le $maxRetry; $retry++) {
			Try {
				#Create a new remote ps session and pass in the script block to be executed
				$session = New-PSSession -ComputerName $uriEndpoint.DnsSafeHost -Credential $credential -Port $uriEndpoint.Port -UseSSL 
				Invoke-Command -Session $session -Scriptblock {
					param($dcDrive, $dcInstallMode, $domain, $netbiosName, $user, $pass, $domainMode)

					Set-ExecutionPolicy Unrestricted -Force	
		
					#initialize DCPromo/ADDSDeployment arguments
					$computer = $env:COMPUTERNAME
					$dcPromoAnswerFile = ("{0}\dcpromo.ini" -f $Env:TEMP)
		
					$locationNTDS = ("{0}:\NTDS" -f $dcDrive)
					$locationNTDSLogs = ("{0}:\LOGS" -f $dcDrive)
					$locationSYSVOL = ("{0}:\SYSVOL" -f $dcDrive)

					Write-Output "  -- AD DS Paths"	
					Write-Output "   - NTDS:   $locationNTDS"	
					Write-Output "   - LOGS:   $locationNTDSLogs"	
					Write-Output "   - SYSVOL: $locationSYSVOL"	
				
					#Create output files
					New-Item -ItemType Directory -Force -Path $locationNTDS
					New-Item -ItemType Directory -Force -Path $locationNTDSLogs
					New-Item -ItemType Directory -Force -Path $locationSYSVOL
		
					#use ADDSDeployment module		
					Write-Output "  -- Running AD-DS Deployment module to install AD DS..."
		
					#Add AD-DS Role
					Install-windowsfeature -name AD-Domain-Services �IncludeManagementTools -verbose
		
					# Hash password
					$secPassword = ConvertTo-SecureString $pass -AsPlainText -Force

					Write-Output "  -- DC Install mode is $dcInstallMode"
					if($dcInstallMode -eq "NewForest")
					{
						#Installing a new forest root domain
						Install-ADDSForest �DomainName $domain -DomainNetBIOSName $netbiosName �DomainMode $domainMode �ForestMode $domainMode -InstallDNS:$true -Force `
							-SafeModeAdministratorPassword $secPassword `
							�DatabasePath $locationNTDS �SYSVOLPath $locationSYSVOL �LogPath $locationNTDSLogs -verbose
					}		
					elseif($dcInstallMode -eq "Replica")
					{
						#Installing a Replica domain
						
						$domainCredential = New-Object System.Management.Automation.PSCredential("$netbiosName\$user", $secPassword)

						Install-ADDSDomainController �Credential $domainCredential �DomainName $domain -Force `
							-SafeModeAdministratorPassword $secPassword `
							�DatabasePath $locationNTDS �SYSVOLPath $locationSYSVOL �LogPath $locationNTDSLogs -verbose
					}
		
					Write-Output "  -- AD-DS Deployment completed..."
				} -ArgumentList $dcDrive, $dcInstallMode, $domain, $netbiosName, $user, $pass, $domainMode

				#exit RPS session
				Remove-PSSession $session

				break
			} Catch [System.Exception] {
				Write-Warning "!!! Error - retrying..."
				Start-Sleep 30
			}
		}
	}
}

Function Set-SetupFormatDisk 
{
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
        [Parameter(Mandatory = $true, Position = 1)]
		[string] $serviceName, 

        [Parameter(Mandatory = $true)]
		[string] $vmName, 

        [Parameter(Mandatory = $true)]
		[string] $adminUserName, 

        [Parameter(Mandatory = $true)]
		[string] $password, 

        [Parameter(Mandatory = $false)]
		$drives
	)
	begin
	{
		Out-AzureCMTimestamp  "== Formatting disks for $vmName"
	}
	process 
	{


		#Get the hosted service WinRM Uri
		$uris = Get-AzureWinRMUri -ServiceName $serviceName -Name $vmName

		$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
		$credential = New-Object System.Management.Automation.PSCredential($adminUserName, $secPassword)

		#TODO: If no powershell endpoints exists need to create an endpoint
		$uriEndpoint = $uris[0]

		$maxRetry = 10
		For($retry = 0; $retry -le $maxRetry; $retry++) {
			Try {
				#Create a new remote ps session and pass in the scrip block to be executed
				$session = New-PSSession -ComputerName $uriEndpoint.DnsSafeHost -Credential $credential -Port $uriEndpoint.Port -UseSSL 
				Invoke-Command -Session $session -Scriptblock {
					param($drives)

					Set-ExecutionPolicy Unrestricted -Force

					Foreach ($key in $drives.Keys) {
						$disk = $drives[$key]

						Get-Disk `
							| Where-Object Number -eq $disk.number `
							| Initialize-Disk -PartitionStyle GPT -PassThru `
							| New-Partition -DriveLetter $disk.letter -UseMaximumSize `
							| Format-Volume -FileSystem NTFS -NewFileSystemLabel $key -Confirm:$false

						Write-Host "  -- Formatted disk [$($disk.letter):] $key"
					}
				} -ArgumentList $drives

				#exit RPS session
				Remove-PSSession $session

				break
			} Catch [System.Exception] {
				Out-AzureCMTimestamp "!!! Error - retrying..."
				Start-Sleep 30
			}
		}
	}
}

Function Set-SetupConfigureCluster 
{
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
		[Parameter(Mandatory = $true)]
		[string] $serviceName, 

		[Parameter(Mandatory = $true)]
		[string] $vmName, 

		[Parameter(Mandatory = $true)]
		[string] $netbiosName, 

		[Parameter(Mandatory = $true)]
		[string] $domain, 

		[Parameter(Mandatory = $true)]
		[string] $user, 

		[Parameter(Mandatory = $true)]
		[string] $pass)
	begin 
	{
		Out-AzureCMTimestamp "== Configuring DC on $vmName"
		Out-AzureCMTimestamp "  - Service:  $serviceName"
		Out-AzureCMTimestamp "  - VM:       $vmName"
		Out-AzureCMTimestamp "  - NetBIOS:  $netbiosName"
		Out-AzureCMTimestamp "  - Domain:   $domain"
	}
	process
	{
		#Get the hosted service WinRM Uri
		$uris = Get-AzureWinRMUri -ServiceName $serviceName -Name $vmName

		$secPassword = ConvertTo-SecureString $pass -AsPlainText -Force
		$credential = New-Object System.Management.Automation.PSCredential($user, $secPassword)

		#TODO: If no powershell endpoints exists need to create an endpoint
		$uriEndpoint = $uris[0]

		$maxRetry = 5
		For($retry = 0; $retry -le $maxRetry; $retry++) {
			Try {
				#Create a new remote ps session and pass in the scrip block to be executed
				$session = New-PSSession -ComputerName $uriEndpoint.DnsSafeHost -Credential $credential -Port $uriEndpoint.Port -UseSSL 
				Invoke-Command -Session $session -Scriptblock {
					param($domain, $netbiosName, $user, $pass)

					Set-ExecutionPolicy Unrestricted -Force	
		
					#initialize 
					$computer = $env:COMPUTERNAME
		
					#use Failover module	
					Write-Output "  -- Running clustering module.."
		
					#Add AD-DS Role
					Install-windowsfeature -name Failover-Clustering, RSAT-Clustering �IncludeManagementTools -verbose
		
	
					Write-Output "  -- Clustering installed..."
				} -ArgumentList $domain, $netbiosName, $user, $pass

				#exit RPS session
				Remove-PSSession $session

				break
			} Catch [System.Exception] {
				Out-AzureCMTimestamp "!!! Error - retrying..."
				Start-Sleep 30
			}
		}
	}
}

Function Wait-SetupForBoot 
{
	<#
	.SYNOPSIS 
		Will pause the thread waiting for VM to spin up
	.DESCRIPTION
		This will hold thread for specified time until VM is operational
     .PARAMETER serviceName
        Specifies the cloud service name
    .PARAMETER vmName
        Specifies the machine name
    .PARAMETER SleepDuration
        Specifies the thread sleep in seconds
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName = "MachineId")]
    [OutputType([bool])]
	Param(
		[Parameter(ParameterSetName = "MachineId", Mandatory = $true, Position = 1)]
        [string]$serviceName, 
		
		[Parameter(ParameterSetName = "MachineId", Mandatory = $true, Position = 2)]
        [string]$vmName,
        
        [Parameter(Mandatory = $false)]
        [int]$SleepDuration = 30
	)
	process 
	{
		do {
			$vm = get-azurevm -ServiceName $serviceName -Name $vmName

			if($vm -eq $null) {
				Out-AzureCMTimestamp ("== WaitForBoot - could not connect to {0}" -f $vmName)
				return $false
			}

			if(($vm.InstanceStatus -eq "FailedStartingVM") -or ($vm.InstanceStatus -eq "ProvisioningFailed") -or ($vm.InstanceStatus -eq "ProvisioningTimeout")) {
				Out-AzureCMTimestamp ("== Provisioning of {0} failed." -f $vmName)
				return $false
			}

			if($vm.InstanceStatus -eq "ReadyRole") {
				break
			}

			Out-AzureCMTimestamp ("== Waiting for {0} to boot; pausing {1} seconds" -f $vmName,$SleepDuration)
			Start-Sleep $SleepDuration 
    
		} while($true)

		return $true
	}
}

function Wait-RestoreVM 
{
	<#
	.SYNOPSIS 
		Will pause the thread waiting for Backup restore service job to complete
	.DESCRIPTION
		This will pause the thread waiting for Backup restore service job to complete
     .PARAMETER RecoveryPoint
        Specifies the ASR Recovery Point
    .PARAMETER restoreStorageName
        Specifies the storage name where it should be restored
    .PARAMETER restorePointJobId
        Specifies the restore point Job ID if specified lets pull this specific job and reengage
    .PARAMETER SleepDuration
        Specifies the threat sleep in seconds
	.NOTES
		AUTHOR: shawn Leonard
	#>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.AzureBackup.Models.AzureRMBackupRecoveryPoint]$RecoveryPoint,
        
        [Parameter(Mandatory = $true)]
        [string]$restoreStorageName,

        [Parameter(Mandatory = $false)]
        [string]$restorePointJobId,
        
        [Parameter(Mandatory = $false)]
        [int]$SleepDuration = 5
    )
    begin 
    {
        $restoreJobId = $null
		Import-Module AzureRM.Backup
        Out-AzureCMTimestamp ("BEGIN>>>Restoring recovery point {0}" -f $RecoveryPoint.ItemName)        
    }
    process 
    {
        $restorejob = Restore-AzureRMBackupItem -StorageAccountName $restoreStorageName -RecoveryPoint $RecoveryPoint
        $restoreJobId = $restorejob.InstanceId
        Out-AzureCMTimestamp ("Restoring recovery point {0} VM:{1} Started:{2} Status:{3}" -f $RecoveryPoint.ItemName,$restorejob.WorkloadName,$restorejob.StartTime,$restorejob.Status)

		do
		{
            Out-AzureCMTimestamp ("Starting wait cycle for {0} Backup job.. This could take a while" -f $restorejob.WorkloadName)
            Wait-AzureRMBackupJob -Job $restoreJob -Timeout 43200 | Out-Null

			$switch = $true
			$restorejob = Get-AzureRMBackupJob -Job $restorejob
            Out-AzureCMTimestamp ("BackupJob:{0} VM:{1} Started:{2} Status:{3}" -f $restorejob.Operation,$restorejob.WorkloadName,$restorejob.StartTime,$restorejob.Status)
            
            if($restorejob.Status -eq "Failed") {
                Write-Error ("Failed to execute job with {0} and {1}" -f $restorejob.WorkloadName,$restorejob.Status)
            }
			elseif ($restorejob.Status -eq "InProgress") {
				$switch = $false
			}
                
			if (-Not($switch))
			{
				Out-AzureCMTimestamp ("Waiting AzureRMBackupJob ... {0}" -f $restorejob.WorkloadName)
				Start-Sleep -s $SleepDuration
			}
		}
		until ($switch) 

        return [string]$restoreJobId
    }
}

function Wait-ServiceInstancesReady 
{
    <#
    .Synopsis
        it wait all role instance are ready
    .DESCRIPTION
        Wait until al instance of Role are ready
    .PARAMETER ServiceName
        Specifies the service name to poll running instances
    #>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$ServiceName
    )
    begin 
    {
        Out-AzureCMTimestamp ("[Start] Waiting for Instance Ready")
    }
    process
    {
        do
        {
            $MyDeploy = Get-AzureDeployment -ServiceName $ServiceName  
            foreach ($Instancia in $MyDeploy.RoleInstanceList)
            {
                $switch=$true
                Out-AzureCMTimestamp ("Instance {0} is in state {1}" -f $Instancia.InstanceName, $Instancia.InstanceStatus )
                if ($Instancia.InstanceStatus -ne "ReadyRole")
                {
                    $switch=$false
                }
            }
            if (-Not($switch))
            {
                Out-AzureCMTimestamp ("Waiting Azure Deploy running, it status is {0}" -f $MyDeploy.Status)
                Start-Sleep -s 10
            }
        }
        until ($switch)
    }
    end 
    {
        Out-AzureCMTimestamp ("[Finish] Waiting for Instance Ready")
    }
}

function Start-AzureCMCopyStorageBlobs
{
    <#
    .Synopsis
        Leverages a series of CSVs including blobs and keys to process into a new destination storage account
    .DESCRIPTION
        Process blobs/disks from one subscription or one storage account to new subscriptions or new storage accounts
    .PARAMETER jsonDefinition
        Specifies a collection of storage accounts, their keys, and the blobs to be copied
    #>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateScript({Test-Path $_ -PathType 'Leaf'})]
		[string]$jsonDefinition
	)
	begin
	{
	# Variables to Seed
		$startVhdStorage = ""
	# Import the CSV files
        $blobJson = Get-Content -Path $jsonDefinition | ConvertFrom-Json -Verbose
		$csvOfDisks = $blobJson.blobs
		$csvOfKeys = $blobJson.keys


		Out-AzureCMTimestamp -Message "[BEGIN] Storage Blob Copy"
	}
	process
	{  
	# Enumerate CSV and process blobs to be processed
		$csvOfDisks | Where-Object { $_.Activity -eq "go" } | ForEach-Object {

			$vhdinteraction = $_.activity
			$sourceStorageName = $_.OriginalStorageName
			$sourceContainerName = $_.OriginalContainerName
			if($sourceContainerName -eq $null) {
				$sourceContainerName = "vhds"
			}
			$sourceVhdBlobName = $_.OriginalLocation
			$destinationStorageName = $_.DestinationStorageName
			$destinationContainerName = $_.DestinationContainerName
			if($destinationContainerName -eq $null) {
				$destinationContainerName = "vhds"
			}
			$destinationVhdName = $_.DestinationVhd
			$destinationVhdBlobName = $sourceVhdBlobName


		#converting end of url to file path for ease of access
			write-host ("Now copying storage from host {0} and VHD {1}" -f $sourceStorageName,$sourceVhdBlobName)
			if($sourceStorageName -ne $startVhdStorage) {
				$startVhdStorage = $sourceStorageName
				$sourceContext = Get-AzureCMCopyStorageKey -csvOfKeys $csvOfKeys -accountName $startVhdStorage
			}

			$destinationContext = Get-AzureCMCopyStorageKey -csvOfKeys $csvOfKeys -accountName $destinationStorageName


			if($destinationVhdName -ne $null -or $destinationVhdName.length -gt 0) {
				$destinationVhdBlobName = $destinationVhdName
			}

			$sourceContainer = Get-AzureStorageContainer -Context $sourceContext -Name $sourceContainerName
			$theblobs = Get-AzureStorageBlob -Context $sourceContext -Container $sourceContainerName
			$theblob = $theblobs | where { $_.Name -like $sourceVhdBlobName }

			$destinationContainer = Get-AzureStorageContainer -Context $destinationContext -Name $destinationContainerName -ErrorAction Continue
			if($destinationContainer -eq $null) {
				New-AzureStorageContainer -Context $destinationContext -Name $destinationContainerName -Permission Off
			}
        
			Out-AzureCMTimestamp ("Starting {0} copy to destination {1}" -f $sourceVhdBlobName,$destinationVhdBlobName)
			$copiedBlob = Start-AzureStorageBlobCopy -Context $sourceContext -CloudBlobContainer $sourceContainer.CloudBlobContainer -SrcBlob $sourceVhdBlobName -DestContext $destinationContext -DestContainer $destinationContainerName -DestBlob $destinationVhdBlobName               
			$copiedBlob | Get-AzureStorageBlobCopyState -WaitForComplete
			Out-AzureCMTimestamp ("Finishing {0} copy to destination {1}" -f $sourceVhdBlobName,$destinationVhdBlobName)
		}
	}
}

function Start-AzureCMCopySqlDatabase 
{
    <#
    .Synopsis
        Copies and Azure database from a server to storage
    .DESCRIPTION
        Will move an Azure SQL DB to storage
    .PARAMETER Credentials
        Specifies credentials for copying a sql database
    #>
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName = "AzureDB")]
	param(
		[Parameter(ParameterSetName = "AzureDB", Mandatory = $true, HelpMessage = "This should be admin credentials for the Azure SQL instance")]
		[PSCredential]$Credentials,

		[Parameter(ParameterSetName = "AzureDB", Mandatory = $true)]
		[string]$ServerName, #EX Azure SQL Server Name
		
		[Parameter(ParameterSetName = "AzureDB", Mandatory = $true)]
		[string]$DatabaseName, #EX Catalog Name
		
		[Parameter(Mandatory = $true)]
		[string]$StorageName, #EX "portalvhdslbzch5jbvsng7"
		
		[Parameter(Mandatory = $true)]
		[string]$StorageKey, #EX Storage Account Key
		
		[Parameter(Mandatory = $true)]
		[string]$ContainerName, #EX "sqlbkup"
		
		[Parameter(Mandatory = $true)]
		[string]$BlobName #EX db.bacpac
	)
	begin {

	}
	process {

		$CredUserName = $Credentials.UserName
		$CredPassword = $credential.GetNetworkCredential().Password 
		$SqlCtx = New-AzureSqlDatabaseServerContext -ServerName $ServerName -Credential $Credentials

		$StorageCtx = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $StorageKey
		$Container = Get-AzureStorageContainer -Name $ContainerName -Context $StorageCtx

		$importRequest = Start-AzureSqlDatabaseImport -SqlConnectionContext $SqlCtx -StorageContainer $Container -DatabaseName $DatabaseName -BlobName $BlobName -Edition Standard

		$statusflag = $true
		while ($statusflag) {

			$status = Get-AzureSqlDatabaseImportExportStatus -RequestId $ImportRequest.RequestGuid -ServerName $ServerName -Username $CredUserName -Password $CredPassword
			$statusObject = $status.Status
			Write-Host ("Status {0} for server {1} and modified time {2}" -f $statusObject,$status.ServerName,$status.LastModifiedTime)
			if($statusObject.Contains("Running") -eq $false) {
				$statusflag = $false    
			}
			Write-Host ("Pausing 5 seconds ...")
			Start-Sleep -Seconds 5
		}


	}
	end {

	}
}

function Start-AzureCMAutomationVirtualMachines
{
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure', DefaultParameterSetName = "ConnectionObject")]
	Param
    (   
        [Parameter(ParameterSetName = "ConnectionObject", Mandatory = $true, Position = 1)]
        [String]$VmStackWebUri       
    )
    begin 
	{
	}
	process
	{

		# Connect to Azure Subscription
		Connect-AzureCMSubscription
    
		$resultObject = Get-AzureCMConfig -WebUri $VmStackWebUri  -ErrorAction SilentlyContinue
        if($resultObject -eq $null) {
            # Invalid JSON Config
            Write-Error ("JSON config {0} could not be found" -f $jsonurl)
            exit
        }		
		    
		$jsonconnect = Get-AutomationConnection -Name "azuresmtpconn"


		$jsonstack = $resultObject | ConvertFrom-Json
		Out-AzureCMTimestamp "Variable from automation $VmStackWebUri"
    
		try 
		{

			$jsonstack | Sort-Object { $_.startorder } | ForEach-Object {
				Out-AzureCMTimestamp ("Now Starting ServiceName {0} `t`tVirtualMachine {1}" -f $_.ServiceName, $_.ComputerName)
            
				do
				{
					$switch=$true
					$vm = Get-AzureVM -ServiceName $_.ServiceName -Name $_.ComputerName
					Out-AzureCMTimestamp ("Instance {0} is in state {1}" -f $vm.Name, $vm.Status )
					if ($vm.Status -eq 'StoppedDeallocated' ) {
						Out-AzureCMTimestamp ("{0} is ready to start" -f $vm.ServiceName)
						$vm | Start-AzureVM    
					}
                
					if ($vm.Status -ne "ReadyRole")
					{
						$switch=$false
					}
                
					if (-Not($switch))
					{
						Out-AzureCMTimestamp ("Waiting Azure Startup, it status is {0}" -f $vm.Status)
						Start-Sleep -s 10
					}
				}
				until ($switch)           
			}

			$subject = ("Virtual machines in subscription {0} are all awake" -f "MyDevMSDN")
			$message = ("A number of virtual machines were spun in your subscription with JSON {0}" -f $jsonstack)
			Send-EmailMessage  -Subject $subject -Message $message -To "shawn.leonard@appliedis.com" -Connection $jsonconnect
		}
		catch 
		{

		}
	}
}

function Switch-AzureCMRestoreVirtualMachine 
{
    [CmdletBinding(DefaultParameterSetName='UseConnectionObject',HelpURI='http://aka.ms/SeeAzure')]
    [OutputType([Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext])]
    Param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.AzureBackup.Models.AzureRMBackupJobDetails]$RecoveredJobDetails,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VirtualMachineDetails,

        [Parameter(Mandatory = $true)]
        [Microsoft.WindowsAzure.Commands.Profile.Models.PSAzureEnvironment]$Environment,

        [Parameter(Mandatory = $true)]
        [string]$VNetName
	)
	begin 
    {
        $vmName = $VirtualMachineDetails.Name
		$vmService = $VirtualMachineDetails.ServiceName
		$vmStorage = $VirtualMachineDetails.StorageAccount.ToLower() -replace "-", ""
		$vmAvailabilitySet = $VirtualMachineDetails.HAName
        $vmSize = $VirtualMachineDetails.VMSize
        $vmSubnet = $VirtualMachineDetails.VMSubnet
        $vmStaticIP = $VirtualMachineDetails.VMStaticIP
        $vmEndPoints = $VirtualMachineDetails.Endpoints
		$isDC = $VirtualMachineDetails.IsDNS 
		if($isDC -eq $null) {
			$isDC = $false
		}

        $vmEndPointSuffix = $Environment.StorageEndpointSuffix
        $vmRestoreService = ("dr{0}" -f $vmService)

		Out-AzureCMTimestamp ("***BEGIN>>>Configuring Name:{0} Service:{1} Size:{2} Subnet:{3} Storage:{4}" -f $vmName,$vmService,$vmSize,$vmSubnet,$vmStorage)
	}
	process 
    {
        $workloadName =  $RecoveredJobDetails.WorkloadName
        $properties  = $RecoveredJobDetails.Properties
        $storageAccountName = $properties["Target Storage Account Name"]
        $containerName = $properties["Config Blob Container Name"]
        $blobName = $properties["Config Blob Name"]

        $storage = Get-AzureStorageAccount -StorageAccountName $storageAccountName
        $storageKeys = Get-AzureStorageKey -StorageAccountName $storageAccountName
        $storageAccountKey = $storageKeys.Primary
        $storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

        ## set default storage account as Azure cmdlets do not support specifying a location for existing disks
        $SubscriptionId = (Get-AzureSubscription -Current).SubscriptionId
        Set-AzureSubscription -SubscriptionId $SUbscriptionId -CurrentStorageAccountName $storageAccountName
        

        $vmConfigurationPath =  ("{0}\azure-{1}-vm-config.xml" -f $env:temp,$RecoveredJobDetails.WorkloadName)
        Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $vmConfigurationPath -Context $storageContext -Force


        $configXmlObj = [xml](((Get-Content -Path $vmConfigurationPath -Encoding UniCode)).TrimEnd([char]0x00))
        $configVMRole = $configXmlObj.PersistentVMRole
        $configVMName = ("dr{0}" -f $configVMRole.RoleName)
        $configVMods = $configVMRole.OSVirtualHardDisk
        $configVMdds = $configVMRole.DataVirtualHardDisks


        $osdiskname = ("dr{0}os" -f $workloadName)
        Out-AzureCMTimestamp ("Now adding media as a OS disk {0}" -f $osdiskname)
        #TODO: Set storage destination for the config as it does not make sense to set the default storage account
        $osDisk = Get-AzureDisk -DiskName $osdiskname -ErrorAction SilentlyContinue
        if($osDisk -eq $null) {
            $osDisk = Add-AzureDisk -MediaLocation $configVMods.MediaLink -OS $configVMods.OS -DiskName $osdiskname
        }

        $targetstorageaccount = ("https://{0}.blob.{1}" -f $storageAccountName,$vmEndPointSuffix)
        Out-AzureCMTimestamp ("Deploying to Account {0} OS Disk {1}" -f $targetstorageaccount,$osDisk.DiskName)

        if($vmAvailabilitySet -ne $null -and $vmAvailabilitySet.length -gt 1) {
            $vmConfig = New-AzureVMConfig -Name $configVMName -InstanceSize $configVMRole.RoleSize -DiskName $osDisk.DiskName -AvailabilitySetName $vmAvailabilitySet
        }
        else {
            $vmConfig = New-AzureVMConfig -Name $configVMName -InstanceSize $configVMRole.RoleSize -DiskName $osDisk.DiskName
        }

        if($vmSubnet -ne $null -and $vmSubnet.length -gt 1) {
            $vmConfig = $vmConfig | Set-AzureSubnet -SubnetNames $vmSubnet
        }

        if($vmStaticIP -ne $null -and $vmStaticIP.length -gt 1) {
            $vmConfig = $vmConfig | Set-AzureStaticVNetIP -IPAddress $vmStaticIP
        }


        if (!($configVMdds -eq $null))
        {
            foreach($dvhd in $configVMdds.DataVirtualHardDisk)
            {
                $lun = 0;
                if(!($dvhd.Lun -eq $null))
                {
                    $lun = $dvhd.Lun
                }
                $name = ("dr{0}data{1}" -f $workloadName,$lun).ToLower()
                $dataDisk = Get-AzureDisk -DiskName $name -ErrorAction SilentlyContinue
                if($dataDisk -eq $null) {
                    $dataDisk = Add-AzureDisk -DiskName $name -MediaLocation $dvhd.MediaLink
                }
                Out-AzureCMTimestamp ("Deploying to Account {0} Data Disk {1}" -f $targetstorageaccount,$dataDisk.DiskName)

                $vmConfig = $vmConfig | Add-AzureDataDisk -Import -DiskName $dataDisk.DiskName -LUN $lun
            }
        }

        if(!($vmEndPoints -eq $null)) 
        {
            foreach($vmEP in $vmEndPoints)
            {
                $vmConfig = $vmConfig | Add-AzureEndpoint -Protocol $vmEP.Protocol -LocalPort $vmEP.LocalPort -PublicPort $vmEP.Port -Name $vmEP.EndPoint
            }
        }


        New-AzureVM -ServiceName $vmRestoreService -VNetName $VNetName -Location $storage.Location -VM $vmConfig

		Out-AzureCMTimestamp ("+++ [SUCCESS] {0} provisioned == WaitForBoot {0}" -f $configVMName)

		$restoreVMStatus = Wait-SetupForBoot -serviceName $vmRestoreService -vmName $configVMName

        $restoredImage = Get-AzureVM -ServiceName $vmRestoreService -Name $configVMName
        return $restoredImage
	}
	end 
    {
	    Out-AzureCMTimestamp ("***END>>>Configuring Name:{0} Service:{1} Size:{2} Subnet:{3} Storage:{4}" -f $vmName,$vmService,$vmSize,$vmSubnet,$vmStorage)
	}
}

function Switch-AzureCMDisasterRecovery 
{
    [CmdletBinding(HelpURI='http://aka.ms/SeeAzure')]
    param
    (
        [Parameter(Mandatory=$true)] 
        [ValidateSet("Azure", "AzureUSGovernment")]
        [string]$Environment,

        [Parameter(Mandatory = $true)]
        [string]$VirtualNetwork
    )
    begin
    {
        # Holds a collection of restored images and their status
        $kvRestoredImages = @()
        $restoreJobId = $null
    }
    process
    {
        $venvironment = Get-AzureEnvironment -Name $Environment
        $vnet = Get-AzureVNetSite -VNetName $VirtualNetwork -ErrorAction Stop
        $location = Get-AzureLocation | Where-Object Name -eq $vnet.Location
        $vnetLocation = $location.Name

        $jsonStorage = "epaiowasc" #This should be specified in the runbook variables
        $jsonurl = ("https://{0}.blob.{1}/json/vm-definition.json" -f $jsonStorage,$venvironment.StorageEndpointSuffix)
        $resultObject = Get-AzureCMConfig -WebUri $jsonurl  -ErrorAction SilentlyContinue
        if($resultObject -eq $null) {
            # Invalid JSON Config
            Write-Error ("JSON config {0} could not be found" -f $jsonurl)
            exit
        }

        $restoreVault = Get-AzureRmBackupVault
        if($restoreVault -eq $null) {
            # Invalid Backup Vault
            Write-Error ("Backup Vault {0} could not be found" -f $Environment)
            exit
        }

		# Parse result to JSON for enumeration
		$resultJson = $resultObject | ConvertFrom-Json
        $restoreVMS = $resultJson.AzureVMs | Sort-Object RestoreOrderID
        $restoreVMS | ForEach-Object {
	
            $restoreVM = $_
            $restoreServiceName = ""
            $restoreVMName = $restoreVM.Name
            $restoreVMServiceName = $restoreVM.ServiceName
            $restoreStorage = ("dr{0}" -f $restoreVM.StorageAccount).ToLower()
            $restoreStorage = "drepaia" #TODO: make this dynamic but for now same storage account is sufficient
            $vmObj = Get-AzureVM -Name $restoreVMName -ServiceName $restoreVMServiceName
            Out-AzureCMTimestamp ("Azure Service {0} VM {1} found in subscription" -f $restoreVMServiceName,$restoreVMName)

	        $backupContainer = Get-AzureRmBackupContainer -Vault $restoreVault -Type AzureVM -Name $restoreVMName | Get-AzureRmBackupItem
            if($backupContainer -ne $null) {

                #JSON includes dependent objects if not restored we should fail the DR scenario
	            $vitemrp = Get-AzureRmBackupRecoveryPoint -Item $backupContainer
                if($vitemrp -ne $null) {
	                $recoveryPoint = $vitemrp[0]
                    $recoveryPointContainer = $recoveryPoint.ContainerUniqueName
                    $recoveryPointTime = $recoveryPoint.RecoveryPointTime.ToString("s")

                    #NewUp Storage Account if not already available
                    #Set Replication to ReadOnly GA so we can gain access to the secondary location
                    $storageAccount = New-AzureCMStorage -StorageAccountName $restoreStorage -StorageLocation $vnetLocation -StorageType Standard_RAGRS
                    $storageAccountKey = Get-AzureStorageKey -StorageAccountName $restoreStorage

                    $restoreJobId = Wait-RestoreVM -RecoveryPoint $RecoveryPoint -restoreStorageName $restoreStorage -SleepDuration 5
                    # Grab Job Details
                    $restoreJobStatus = Get-AzureRmBackupJobDetails -JobId $restoreJobId -Vault $restoreVault
                    $workloadHash = $null

                    if($restoreJobStatus.Status -eq "Completed") {

                        # Process the restore of the specific machine
                        $rjproperties  = $restoreJobStatus.Properties
                        $rjstorageAccountName = $rjproperties["Target Storage Account Name"]
                        $rjcontainerName = $rjproperties["Config Blob Container Name"]
                        $rjblobName = $rjproperties["Config Blob Name"]

                        $workloadHash = New-Object psobject -Property @{
                            Name =  $restoreJobStatus.WorkloadName
                            StorageAccountName = $rjstorageAccountName
                            containerName = $rjcontainerName
                            blobName = $rjblobName
                        }

                        Out-AzureCMTimestamp ("SUCCESS::Restore status {0} ... Now restoring VM {1}" -f $restoreJobStatus.Status,$restoreJobStatus.WorkloadName)
                        $restoredImage = Switch-AzureCMRestoreVirtualMachine -RecoveredJobDetails $restoreJobStatus -VirtualMachineDetails $restoreVM -Environment $venvironment -VNetName $VirtualNetwork
                        $restoreServiceName = $restoreImage.ServiceName
                        # Pop Array here for ILB and post config settings
                    }
                    elseif($restoreJobStatus.Status -eq "Failed") {
                        # Check dependencies, if exist rollback and take care of the concern
                        $errDetails = $restoreJobStatus.ErrorDetails
                        $errDetails | ForEach-Object {
                            Write-Error ("Restore Failed Code:{0}  Message:{1}" -f $_.ErrorCode,$_.ErrorMessage)
                        }
                        $workloadHash = New-Object psobject -Property @{
                            Name =  $restoreJobStatus.WorkloadName
                            Errors = $errDetails
                        }
                        Out-AzureCMTimestamp ("FAILED::Restore status {0} ... Now restoring VM {1}" -f $restoreJobStatus.Status,$restoreJobStatus.WorkloadName)
                    }
                    else {
                        
                        # More than likely this was failed or incomplete
                        $rjproperties  = $restoreJobStatus.Properties
                        $rjstorageAccountName = $rjproperties["Target Storage Account Name"]
                        $workloadHash = New-Object psobject -Property @{
                            Name =  $restoreJobStatus.WorkloadName
                            StorageAccountName = $rjstorageAccountName
                            Errors = $errDetails
                        }
                        Out-AzureCMTimestamp ("OTHER::Restore status {0} ... Now restoring VM {1}" -f $restoreJobStatus.Status,$restoreJobStatus.WorkloadName)
                    }
                    

                    $hash = New-Object psobject -Property @{
                        VM = $restoreVM
                        RestoreStatus = $restoreJobStatus.Status
                        RestoreServiceName = $restoreServiceName
                        RestoreTimestamp = $recoveryPointTime
                        RestoreJobId = $restoreJobId
                        RestoreJob = $workloadHash
                    }

                    $hashJson = $hash | ConvertTo-Json -Depth 5 -Compress

                    Write-AzureCMTableEntry -StorageAccountName $restoreStorage -StorageKey $storageAccountKey.Primary `
                        -EndPointSuffix $venvironment.StorageEndpointSuffix -rowIdentity $recoveryPointContainer -rowContents $hashJson -UseHttps

                    $kvRestoredImages += $hash
                }
            }
        }

        <#
        # Successfully provisioned VMs from restore disks, lets add environment/vnet configurations
        # Create the ILB
        #>
        $restoreEndPoints = $resultJson.AzureILBs
        $restoreEndPoints | ForEach-Object {
	    
            $restoreEndPoint = $_
            $ILBInternalName = $restoreEndPoint.Name
            $ILBSubnetName = $restoreEndPoint.Subnet
            $ILBStaticIP = $restoreEndPoint.StaticIP
            $ILBName = $restoreEndPoint.LBName
            $ILBSetName = $restoreEndPoint.LBSetName
            $ILBLocalPort= $restoreEndPoint.LBPort
            $ILBPublicPort= $restoreEndPoint.LBPublicPort
            $ILBProbePort= $restoreEndPoint.LBProbePort
            $ILBProtocol = $restoreEndPoint.Protocol
            $ILBProbeProtocol = $restoreEndPoint.ProbeProtocol
            $ILBProbeIntervalInSeconds = $restoreEndPoint.ProbeIntervalInSeconds
            $ILBProbeTimeoutInSeconds = $restoreEndPoint.ProbeTimeoutInSeconds
            $ILBDirectServerReturn = $restoreEndPoint.DirectServerReturn
            $ILBRestoreService = ("dr{0}" -f $restoreEndPoint.ServiceName)
            $ILBIdx = 1
            Add-AzureInternalLoadBalancer -InternalLoadBalancerName $ILBInternalName -SubnetName $ILBSubnetName -ServiceName $ILBRestoreService -StaticVNetIPAddress $ILBStaticIP

            # Configure a load balanced endpoint for each node in $AGNodes using ILB
            ForEach ($node in $restoreEndPoint.Machines)
            {
                $nodeRestore = ("dr{0}" -f $node)
                $nodeIlbName = ("{0}0{1}" -f $ILBName,$ILBIdx)
                Get-AzureVM -ServiceName $ILBRestoreService -Name $nodeRestore | 
                    Add-AzureEndpoint -Name $ILBName -InternalLoadBalancerName $ILBInternalName -LBSetName $ILBSetName `
                        -Protocol $ILBProtocol -LocalPort $ILBLocalPort -PublicPort $ILBPublicPort -ProbePort $ILBProbePort `
                        -ProbeProtocol $ILBProbeProtocol -ProbeIntervalInSeconds $ILBProbeIntervalInSeconds  -DirectServerReturn $ILBDirectServerReturn | 
                    Update-AzureVM
                $ILBIdx = $ILBIdx + 1
            }
        }
    }
}

# export all functions from within this module
Export-ModuleMember -Function *
