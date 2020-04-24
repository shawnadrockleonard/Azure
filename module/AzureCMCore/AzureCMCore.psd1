﻿#
# Module manifest for module 'AzureCMCore'
#
# Generated by: Shawn Leonard
#
# Generated on: 11/2/2019
#

@{
	#RootModule = 'AzureCMCore.dll'
	ModuleVersion        = '1.0.0.0'
	GUID                 = '605f3e0e-f2aa-426f-9475-5fb8ad67ac4d'
	Author               = 'Shawn Leonard (sleonard@microsoft.com)'
	CompanyName          = 'Microsoft'
	Description          = 'This module is used to automate various capabilities in Azure'
	CompatiblePSEditions = 'Core', 'Desktop'
	PowerShellVersion    = "5.1"
	ClrVersion           = "4.0"
	FormatsToProcess     = 'AzureCMCore.ps1xml' 
	RequiredAssemblies   = @('AzureCMCore.dll', 'Newtonsoft.Json.dll', 'Microsoft.WindowsAzure.Storage.dll', 'System.Runtime.CompilerServices.Unsafe.dll')
	NestedModules        = @('.\AzureCMCore.dll', "AzureCM.Automation")
  
	# Modules that must be imported into the global environment prior to importing this module  
	RequiredModules      = @( @{ ModuleName = 'Az.Profile'; ModuleVersion = '0.7.0' })
	FunctionsToExport    = '*'
	CmdletsToExport      = '*'
	VariablesToExport    = '*'
	AliasesToExport      = '*'

	PrivateData          = @{
		PSData = @{
			Tags       = @('AzureCMCore', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows', 'Linux', 'macOS')
			ProjectUri = 'https://oneget.org'
		}
	}
}

