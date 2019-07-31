[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Provide the literal path to the CSV")]
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [string]$csvFile
)

begin {
}

process {

    $mergevalues = ""
    $azureTableKeys = Import-Csv -Path $csvFile
    $azureTableKeys | ForEach-Object {
        $azurekey = $_
        $insertquery = (",({0},'{1}','{2}','{3}','{4}','{5}','{6}','{7}','{8}','{9}')" -f `
                $azurekey.Id,
            $azurekey.CreatedByUser,
            $azurekey.CreatedDateTime,
            $azurekey.ExcludedEnvironments,
            $azurekey.LastModifiedByUser,
            $azurekey.LastModifiedDateTime,
            $azurekey.MinimumAllowedPermissionLevel,
            $azurekey.Name,
            $azurekey.OnOff,
            $azurekey.ExactAllowedPermissionLevel)

        $mergevalues += $insertquery

    }

    $mergevalues = $mergevalues.Substring(1)

    $sql = ("SET IDENTITY_INSERT [dbo].[FeatureBitDefinitions] ON

MERGE INTO [dbo].[FeatureBitDefinitions] AS Target
    USING (VALUES
        {0}
        ) AS Source ([Id],[CreatedByUser],[CreatedDateTime],[ExcludedEnvironments],[LastModifiedByUser],[LastModifiedDateTime],[MinimumAllowedPermissionLevel],[Name],[OnOff],[ExactAllowedPermissionLevel])
ON (Target.[Id] = Source.[Id])
WHEN MATCHED THEN
UPDATE SET
   [CreatedByUser] = Source.[CreatedByUser]
   ,[CreatedDateTime] = Source.[CreatedDateTime]
   ,[ExcludedEnvironments] = Source.[ExcludedEnvironments]
   ,[LastModifiedByUser] = Source.[LastModifiedByUser]
   ,[LastModifiedDateTime] = Source.[LastModifiedDateTime]
   ,[MinimumAllowedPermissionLevel] = Source.[MinimumAllowedPermissionLevel]
   ,[Name] = Source.[Name]
   ,[OnOff] = Source.[OnOff]
   ,[ExactAllowedPermissionLevel] = Source.[ExactAllowedPermissionLevel]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([Id],[CreatedByUser],[CreatedDateTime],[ExcludedEnvironments],[LastModifiedByUser],[LastModifiedDateTime],[MinimumAllowedPermissionLevel],[Name],[OnOff],[ExactAllowedPermissionLevel])
    VALUES (Source.[Id],Source.[CreatedByUser],Source.[CreatedDateTime],Source.[ExcludedEnvironments],Source.[LastModifiedByUser],Source.[LastModifiedDateTime],Source.[MinimumAllowedPermissionLevel],Source.[Name],Source.[OnOff],Source.[ExactAllowedPermissionLevel])
;
SET IDENTITY_INSERT [dbo].[FeatureBitDefinitions] OFF
SET NOCOUNT OFF
" -f $mergevalues)

    Write-Verbose $sql
    Invoke-SQLcmd -ServerInstance 'tcp:leosurbook,1433' -query $sql -Database FeatureBitsDb_1029
}

end {
}