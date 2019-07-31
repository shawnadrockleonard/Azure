########################################################################################################################
# Start of the script - Description, Requirements & Legal Disclaimer
########################################################################################################################
# Written by: Joshua Stenhouse joshuastenhouse@gmail.com
################################################
# Description:
# This script shows you to import a CSV into a SQL database using the PowerShell SQL Module
# Script tested using Windows 10, PowerShell 5.1 and a local SQL Express 2017 instance, will work exactly the same for a remote instance/server
##############################################
# Requirements:
# - Set-executionpolicy unrestricted on the computer running the script
# - A SQL server, instance, credentials, and the DB already created from the Create script
# - A CSV file, start with the example given
################################################
# Legal Disclaimer:
# This script is written by Joshua Stenhouse is not supported under any support program or service. 
# All scripts are provided AS IS without warranty of any kind. 
# The author further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. 
# In no event shall its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever. 
# Including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss arising out of the use of,
# or inability to use the sample scripts or documentation, even if the author has been advised of the possibility of such damages.
################################################
# Configure variables below for connecting to the SQL database
################################################
$CSVFileName = "C:\ImportingCSVsIntoSQLv1\ExampleData.csv"
$SQLInstance = "localhost\SQLEXPRESS"
$SQLDatabase = "CSVDemoDB01"
$SQLTable = "CSVData"
$SQLTempDatabase = "tempdb"
$SQLTempTable = "CSVDataImport"
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
# Start of time taken benchmark
##############################################
$Start = Get-Date
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
# Creating Temp SQL Table
##############################################
"Creating SQL Table $SQLTempTable for CSV Import" 
$SQLCreateTempTable = "USE $SQLTempDatabase
    CREATE TABLE $SQLTempTable (
    RowID int IDENTITY(1,1) PRIMARY KEY,
	RecordID varchar(50),
	Date datetime,
    DataField1 varchar(255),
	DataField2 varchar(255)
);"
Invoke-SQLCmd -Query $SQLCreateTempTable -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
##############################################
# Importing CSV and processing data
##############################################
$CSVImport = Import-CSV $CSVFileName
$CSVRowCount = $CSVImport.Count
##############################################
# ForEach CSV Line Inserting a row into the Temp SQL table
##############################################
"Inserting $CSVRowCount rows from CSV into SQL Table $SQLTempTable"
ForEach ($CSVLine in $CSVImport) {
    # Setting variables for the CSV line, ADD ALL 170 possible CSV columns here
    $CSVRecordID = $CSVLine.RecordID
    $CSVDateString = $CSVLine.Date
    $CSVDataField1 = $CSVLine.DataField1
    $CSVDataField2 = $CSVLine.DataField2
    # Translating Date to SQL compatible format
    $CSVDate = "{0:yyyy-MM-dd HH:mm:ss}" -f ([DateTime]$CSVDateString)
    ##############################################
    # SQL INSERT of CSV Line/Row
    ##############################################
    $SQLInsert = "USE $SQLTempDatabase
INSERT INTO $SQLTempTable (RecordID, Date, DataField1, DataField2)
VALUES('$CSVRecordID', '$CSVDate', '$CSVDataField1', '$CSVDataField2');"
    # Running the INSERT Query
    Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
    # End of ForEach CSV line below
}
# End of ForEach CSV line above
##############################################
# Merging data from Temp Table to Target Table using SQL MERGE
##############################################
"Merging SQL Table Data from $SQLTempTable to $SQLTable"
# For more info, I.E to add DELETE as part of the MERGE, read: https://www.essentialsql.com/introduction-merge-statement/
$SQLMerge = "MERGE $SQLDatabase.dbo.$SQLTable Target
USING $SQLTempDatabase.dbo.$SQLTempTable Source
ON (Target.RecordID = Source.RecordID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.Date = Source.Date,
            Target.DataField1 = Source.DataField1,
            Target.DataField2 = Source.DataField2
WHEN NOT MATCHED BY TARGET
THEN INSERT (RecordID, Date, DataField1, DataField2)
     VALUES (Source.RecordID, Source.Date, Source.DataField1, Source.DataField2);"      
Invoke-SQLCmd -Query $SQLMerge -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
##############################################
# Dropping Temp Table using SQL DROP
##############################################
"Dropping SQL Table $SQLTempTable as no longer needed" 
$SQLDrop = "USE $SQLTempDatabase
DROP TABLE $SQLTempTable;"      
Invoke-SQLCmd -Query $SQLDrop -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
##############################################
# End of time taken benchmark
##############################################
$End = Get-Date
$TimeTaken = New-Timespan -Start $Start -End $End | Select -ExpandProperty TotalSeconds
$TimeTaken = [Math]::Round($TimeTaken, 0)
"CSV Import Finished In $TimeTaken Seconds"
##############################################
# End of script
##############################################