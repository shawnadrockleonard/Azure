<#PSScriptInfo
.VERSION 0.1.0
.GUID b4216e46-9916-47de-acdd-8b6435a3c058

.DESCRIPTION 
 PowerShell Desired State Configuration for deploying Domain Controllers 
#> 

Configuration SetEnvironmentVariableConfig
{
    param ()

    Import-DscResource -ModuleName @{ModuleName = 'ComputerManagementDsc'; ModuleVersion = '5.0.0.0' }
    Import-DscResource -ModuleName 'PSDscResources'

    Node localhost
    {
        Environment CreatePathEnvironmentVariable
        {
            Name   = 'TestPathEnvironmentVariable'
            Value  = 'TestValue'
            Ensure = 'Present'
            Path   = $true
            Target = @('Process', 'Machine')
        }
    }
}
