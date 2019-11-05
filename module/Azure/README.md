# azureautomation
AzureAutomation




Build Events Post-Build event command line
C:\windows\system32\windowspowershell\v1.0\powershell.exe -ExecutionPolicy bypass -NoLogo -NonInteractive -Command .'$(SolutionDir)\scripts\PostBuild.ps1' -ProjectDir:'$(ProjectDir)' -ConfigurationName:'$(ConfigurationName)' -TargetDir:'$(TargetDir)' -TargetFileName:'$(TargetFileName)' -TargetName:'$(TargetName)' -SolutionDir:'$(SolutionDir)' -ProjectName:'$(ProjectName)'