
@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'AzTestPolicy.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.1'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = 'abfab8b9-87e7-41cf-9e52-678b383eca4a'

    # Author of this module
    Author            = 'Shawn Leonard'

    # Company or vendor of this module
    CompanyName       = 'devtest labs'

    # Copyright statement for this module
    Copyright         = '(c) no copyright.'

    # Description of the functionality provided by this module
    Description       = 'Provides pre-defined pester tests for Azure Policy and Initiative definitions'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(@{ModuleName = "pester"; ModuleVersion = "4.7.0"; Guid = "a699dea5-2c73-4616-a270-1f7abb777e71" })

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Test-AzPolicyDefinition', 'Test-AzPolicySetDefinition', 'Test-JSONContent')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList          = @('AzPolicyTest.psd1', 'AzPolicyTest.psm1', 'AzPolicyTest.psm1-Help.xml', 'fileContent.tests.ps1', 'policyDefStructure.tests.ps1', 'policySetDefStructure.tests.ps1')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags                       = @('Azure', 'AzurePolicy', 'Pester')

            # A URL to the license for this module.
            LicenseUri                 = 'https://dev.azure.com/shawniq/azureautomation/AzPolicyTest/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri                 = 'https://dev.azure.com/shawniq/azureautomation/AzPolicyTest'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # External dependent modules of this module
            ExternalModuleDependencies = @('Pester')

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

