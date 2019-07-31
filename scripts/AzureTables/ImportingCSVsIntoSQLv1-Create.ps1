#####################################################################
# Start of the script - Description, Requirements & Legal Disclaimer
#####################################################################
# Written by: Joshua Stenhouse joshuastenhouse@gmail.com
##############################################
# Description:
# This script creates a demo database and table required for the CSV and SQL database script
# Script tested using Windows 10, PowerShell 5.1 and a local SQL Express 2017 instance, will work exactly the same for a remote instance/server
##############################################
# Requirements:
# - Set-executionpolicy unrestricted on the computer running the script
# - A SQL server, instance, and credentials to create a database
##############################################
# Legal Disclaimer:
# This script is written by Joshua Stenhouse is not supported under any support program or service. 
# All scripts are provided AS IS without warranty of any kind. 
# The author further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. 
# In no event shall its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever. 
# Including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss arising out of the use of,
# or inability to use the sample scripts or documentation, even if the author has been advised of the possibility of such damages.
##############################################
# Configure variables below for connecting to the SQL database
##############################################
$SQLInstance = "localhost\SQLEXPRESS"
$SQLDatabase = "CSVDemoDB01"
$SQLTable = "CSVData"
############################################################################################
# Nothing to change below this line, comments provided if you need/want to change anything
############################################################################################
##############################################
# Prompting for SQL credentials
##############################################
$SQLCredentials = Get-Credential -Message "Enter your SQL username & password"
$SQLUsername = $SQLCredentials.UserName
$SQLPassword = $SQLCredentials.GetNetworkCredential().Password
##############################################
# Checking if SqlServer module is already installed, if not installing it
##############################################
$SQLModuleCheck = Get-Module -ListAvailable SqlServer
if ($SQLModuleCheck -eq $null) {
    write-host "SqlServer Module Not Found - Installing"
    # Not installed, trusting PS Gallery to remove prompt on install
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    # Installing module
    Install-Module -Name SqlServer –Scope CurrentUser -Confirm:$false -AllowClobber
}
##############################################
# Importing SqlServer module
##############################################
Import-Module SqlServer
##############################################
# Creating SQL Database
##############################################
$SQLCreateDB = "USE master;  
GO  
CREATE DATABASE $SQLDatabase
GO"
Invoke-SQLCmd -Query $SQLCreateDB -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
##############################################
# Creating SQL Table
##############################################
$SQLCreateTable = "USE $SQLDatabase
    CREATE TABLE $SQLTable (
    RowID int IDENTITY(1,1) PRIMARY KEY,
	RecordID varchar(50),
	Date datetime,
    DataField1 varchar(255),
	DataField2 varchar(255)
);"
Invoke-SQLCmd -Query $SQLCreateTable -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
##############################################
# End of script
##############################################