<#
    .EXAMPLE
        This example shows how to install a named instance of SQL Server on a single server, from an UNC path.
    .NOTES
        Assumes the credentials assigned to SourceCredential have read permission on the share and on the UNC path.
        The media will be copied locally, using impersonation with the credentials provided in SourceCredential, so
        that the SYSTEM account can access the media locally.

        SQL Server setup is run using the SYSTEM account. Even if SetupCredential is provided
        it is not used to install SQL Server at this time (see issue #139).
#>
Configuration Sql2016-Install
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $SqlInstallCredential,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $SqlAdministratorCredential = $SqlInstallCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $SqlServiceCredential,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $SqlAgentServiceCredential = $SqlServiceCredential
    )

    Import-DscResource -ModuleName xSQLServer
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    node $env:COMPUTERNAME
    {
        #region Install prerequisites for SQL Server
        WindowsFeature 'NetFramework35' {
           Name = 'NET-Framework-Core'
           Source = 'C:\Windows\WinSxS' # Assumes built-in Everyone has read permission to the share and path.
           Ensure = 'Present'
        }

        WindowsFeature 'NetFramework45' {
           Name = 'NET-Framework-45-Core'
           Ensure = 'Present'
        }
        #endregion Install prerequisites for SQL Server

        #region Install SQL Server
        xSQLServerSetup 'InstallNamedInstance-MSSQLSERVER'
        {
            InstanceName = 'MSSQLSERVER'
            Features = 'SQLENGINE,CONN,IS,BC,BOL,Tools'
            SQLCollation = 'SQL_Latin1_General_CP1_CI_AS'
            SQLSvcAccount = $SqlServiceCredential
            AgtSvcAccount = $SqlAgentServiceCredential
            ASSvcAccount = $SqlServiceCredential
            SQLSysAdminAccounts = 'contoso\Domain Database Admins', $SqlAdministratorCredential.UserName
            ASSysAdminAccounts = 'contoso\SQL Administrators', $SqlAdministratorCredential.UserName
            SetupCredential = $SqlInstallCredential
            InstallSharedDir = 'D:\Apps\Microsoft SQL Server'
            InstallSharedWOWDir = 'D:\Apps (x86)\Microsoft SQL Server'
            InstanceDir = 'D:\Apps\Microsoft SQL Server'
            InstallSQLDataDir = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLUserDBDir = 'M:\Apps\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLUserDBLogDir = 'L:\Apps\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLTempDBDir = 'P:\Apps\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
            SQLTempDBLogDir = 'L:\Apps\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log'
            SQLBackupDir = 'E:\Apps\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup'
            ASConfigDir = 'D:\Apps\Microsoft SQL Server\MSOLAP13.MSSQLSERVER\Config'
            ASDataDir = 'M:\Apps\Microsoft SQL Server\MSOLAP13.MSSQLSERVER\Data'
            ASLogDir = 'L:\Apps\Microsoft SQL Server\MSOLAP13.MSSQLSERVER\Log'
            ASBackupDir = 'E:\Apps\Microsoft SQL Server\MSOLAP13.MSSQLSERVER\Backup'
            ASTempDir = 'P:\Apps\Microsoft SQL Server\MSOLAP13.MSSQLSERVER\Temp'
            SourcePath = '\\install1\dba\Microsoft SQL Server\2016'
            SourceCredential = $SqlInstallCredential
            UpdateEnabled = 'False'
            ForceReboot = $false
            BrowserSvcStartupType = 'Automatic'

            DependsOn = '[WindowsFeature]NetFramework35','[WindowsFeature]NetFramework45'
        }
        #endregion Install SQL Server
    }
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            InstallerServiceAccount = "contoso\user1"
            AdminAccount = "contoso\user1"
        }
        @{
            NodeName = "$env:COMPUTERNAME"
            SQLServers = @(
                @{
                    InstanceName = "MSSQLSERVER"
                }
            )
        }

    )
}
$password = 'password1' | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'contoso\user1', $password
$InstallerServiceAccount = $credential # Get-Credential "contoso\user1"
#run from command line:
Sql2016-Install -ConfigurationData $ConfigurationData -PsDscRunAsCredential $credential -SqlInstallCredential $credential -SqlAdministratorCredential $credential -SqlServiceCredential $credential -SqlAgentServiceCredential $credential 
Start-DscConfiguration -Path c:\temp\SQLInstall  -Wait -Force -Credential $credential -Debug