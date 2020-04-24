#
# Module manifest for module 'AzureServers'

@{

    # Script module or binary module file associated with this manifest.
    RootModule            = 'AzureServers.psm1'

    # Version number of this module.
    ModuleVersion         = '1.0.0.0'

    # ID used to uniquely identify this module
    GUID                  = '575a608b-c7c6-4a09-b0e9-2f0ba7328972'

    # Author of this module
    Author                = 'Shawn Leonard'

    # Company or vendor of this module
    CompanyName           = 'SPL-INC'

    # Copyright statement for this module
    Copyright             = '(c) 2014 . All rights reserved.'

    # Description of the functionality provided by this module
    Description           = 'Module contains functions for Servers and Clients that can be modified.'

    ProcessorArchitecture = 'Amd64'
    FunctionsToExport     = '*'
    CmdletsToExport       = '*'
    VariablesToExport     = '*'
    AliasesToExport       = '*'

}