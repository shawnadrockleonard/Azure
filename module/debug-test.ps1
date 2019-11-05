
function Add-CompilerService {
  [cmdletbinding()]
  param($assemblyname) 
  PROCESS {
    # Load your target version of the assembly
    $newtonsoft = [System.Reflection.Assembly]::LoadFrom(("{0}{1}\.nuget\packages\system.runtime.compilerservices.unsafe\4.7.0-preview2.19523.17\lib\netstandard2.0\System.Runtime.CompilerServices.Unsafe.dll" -f $env:HOMEDRIVE, $env:HOMEPATH))
    $onAssemblyResolveEventHandler = [System.ResolveEventHandler] {
      param($sender, $e)
      # You can make this condition more or less version specific as suits your requirements
      if ($e.Name.StartsWith("System.Runtime.CompilerServices.Unsafe")) {
        return $newtonsoft
      }
      foreach ($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
        if ($assembly.FullName -eq $e.Name) {
          return $assembly
        }
      }
      return $null
    }
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolveEventHandler)
  }
}



Import-Module '.\AzureCMCore\bin\Debug\netstandard2.0\AzureCMCore.psd1' -Force
Get-Command -Module AzureCMCore
Connect-AzureCMAdal 
Connect-AzureCMAdal -Scopes @("User.Read", "User.ReadBasic.All") -ResourceUri "https://localhost:44300/"
# Examples
# Get-AzureCMConfig -WebUri "https://coolbridgeconfig.blob.core.usgovcloudapi.net/downloads/store.json"