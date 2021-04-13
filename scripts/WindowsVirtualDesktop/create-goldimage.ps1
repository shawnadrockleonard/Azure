<#
###############################################################################################################
#
#  Code inteneded to access a running "gold image" VM and do the following:
#	1)  Connect to Azure
#	2)  Switch subscriptions
#	3)  Find AzureVm and deallocate VM
#	4)  Create a new Snapshot, Disk, and Provision VM
#   5)  SYSPREP then shutdown VM
#	6)  Deallocated sysprepd VM
#	7)  Increment image version and provision gallery and image definition
#   8)  Delete sysprep'd VM along with resources
#
###############################################################################################################
#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/WindowsVirtualDesktop/readme.md", SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript( { Test-Path $_ -PathType Container })]
    [string]$RunningDirectory,

    [Parameter(Mandatory = $false)]
    [string]$AzSourceVMname = "imageprep01",

    [Parameter(Mandatory = $false)]
    [string]$AZResourceGroup = "zelus-image-rg",

    [Parameter(Mandatory = $false, HelpMessage = "Image Gallery Name")]
    [string]$ImageGalleryName = "ZelusImages",

    [Parameter(Mandatory = $false, HelpMessage = "Destination Image Name")]
    [string]$ImageName = "DevOps2020withApps",

    [Parameter(Mandatory = $false, HelpMessage = "Identity the subscription into which the image will be provisioned.")]
    [string]$AZSubscriptionID = "",

    [Parameter(Mandatory = $false)]
    [string]$AzSysPrepVMname = "SysprepImage01",

    [Parameter(Mandatory = $false)]
    [ValidateSet("AzureCloud", "AzureUSGovernment")]
    [string]$AzEnvironment = "AzureUSGovernment",

    [Parameter(Mandatory = $false, HelpMessage = "Flag to provision image as a job")]
    [System.Management.Automation.SwitchParameter]$RunAsJob
)
BEGIN
{
    #################################
    #Step 1 - Connect to Azure
    #################################
    $AzContext = Get-AzContext
    if ($null -eq $AzContext -or $AzEnvironment -ne $AzContext.Environment.Name)
    {
        Connect-AzAccount -Environment $AzEnvironment -UseDeviceAuthentication -ErrorAction Stop
    }        

    #################################
    #Step 2 - Switch subscription
    #################################
    if ($null -ne $AZSubscriptionID -and $AZSubscriptionID -ne $AzContext.Subscription.Id)
    {
        #Select the target subscription for the current session
        Select-AzSubscription -SubscriptionId $AZSubscriptionID
    }

    # Specifies the directory in which this should run
    $runningscriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
    if ($RunningDirectory -eq "")
    {
        $RunningDirectory = $runningscriptDirectory
    }
    
}
PROCESS
{
    #################################
    #Step 3 - Find Main Image
    #################################
    $AzVMSource = Get-AZVM -name $AzSourceVMname -Status
    $AzVMSourceResourceGroup = $AzVMSource.ResourceGroupName
    $Power = $AzVMSource.powerstate
    write-host "`nMain Image VM:  $AzSourceVMname in State:  $Power"
    while ($AzVMSource.powerstate -ne "VM deallocated")
    {
        write-host "Main Image VM:  $AzSourceVMname Requesting Shutdown of VM"
        stop-AZVM -name $AzSourceVMname -ResourceGroupName $AZResourceGroup -force
        $AzVMSource = Get-AZVM -name $AzSourceVMname -Status
        $Power = $AzVMSource.powerstate
        write-host "Main Image VM:  $AzSourceVMname in State:  $Power`n"
    }
	
    #################################
    #Step 4 - Create new VM / Snapshot disk / attach to new VM
    #################################
    # Below section adapted from
    # https://dev.to/omiossec/using-powershell-to-rename-move-or-reconnect-an-azure-vm-i00
    $snapshotResults = New-AzResourceGroupDeployment -Name "SnapshotImagePrep" -ResourceGroupName $AzVMSourceResourceGroup -Mode Incremental `
        -TemplateFile .\scripts\WindowsVirtualDesktop\snapshot-template.json `
        -TemplateParameterFile .\scripts\WindowsVirtualDesktop\snapshot-template.parameter.json
    if ($snapshotResults.Status -eq $false)
    {
        throw "Failed to provision snapshot, look at Deployment logs."
    }

    #################################
    #Step 5 - Call Powershell Script to Sysprep 
    #
    #  Code creates a PowerShell script locally and invokes it on the remote VM before deleting the local copy
    #  The file contains the following command line:
    #	    Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList '/generalize /oobe /shutdown /quiet'
    #
    #################################

    ### Build a command that will be run inside the VM.
    if (!(Test-Path -Path '.\scripts\WindowsVirtualDesktop\PshellSysprep.PS1' -PathType Leaf))
    {
        $remoteCommand = 
        @"
    ### Run SysPrep
    Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList '/generalize /oobe /shutdown /quiet'
"@
        ## Save the command to a local file
        Set-Content -Path .\scripts\WindowsVirtualDesktop\PshellSysprep.PS1 -Value $remoteCommand -Force
    }
    
    ## Invoke the command on the VM, using the local file
    Invoke-AzVMRunCommand -Name $AzSysPrepVMname -ResourceGroupName $AzVMSourceResourceGroup -CommandId 'RunPowerShellScript' -ScriptPath .\scripts\WindowsVirtualDesktop\PshellSysprep.PS1


    #################################
    #Step 6 - Change the VM state
    #
    #   Have to deallocate the VM so we can update it
    #   (Sysprep doesn't deallocate when shutsdown) 
    #
    #################################
    ### Force Deallocation of VM and set the image to "Generalized"
    $TempVM = get-azvm -name $AzSysPrepVMname -Status
    $Power = $TempVM.powerstate
    while ($Power -ne "VM stopped")
    {
        Write-Host "Waiting for VM to shutdown gracefully."
        Start-Sleep -Seconds 5
        $TempVM = Get-AZVM -name $AzSysPrepVMname -Status
        $Power = $TempVM.powerstate
    }
    Stop-AzVM -ResourceGroupName $AZResourceGroup -Name $AzSysPrepVMname -Force
    Set-AzVm -ResourceGroupName $AZResourceGroup -Name $AzSysPrepVMname -Generalized


    #################################
    #Step 7 - Put image into Private Gallery 
    #
    #  Create image gallery if it is not already there
    #
    #################################
    ### see if there is already an image / figure out next verion
    $ImageVersion = '1.0.0'
    $expiryDate = Get-Date -Date ((Get-Date).AddMonths(2)) -Format "yyyy-MM-dd"
    $imageResourceId = get-azresource -ResourceType 'Microsoft.Compute/galleries/images' -Name $ImageName
    if ($null -ne $imageResourceId)
    {
        # Image Definition exists check for Versions
        $versions = Get-AzGalleryImageVersion -ResourceGroupName $AzVMSourceResourceGroup -GalleryName $ImageGalleryName -GalleryImageDefinitionName $ImageName | Select-Object Name
        $versionCount = ($versions | Measure-Object).Count
        if ($versionCount -gt 0)
        {
            $ImageVersion = "1.0.{0:D2}" -f $versionCount
        }
    }
    
    # Single replication, may take up to 16 minutes
    $imageOutput = New-AzResourceGroupDeployment -Name "GalleryImagePrep" -ResourceGroupName $AzVMSourceResourceGroup -Mode Incremental `
        -TemplateFile .\scripts\WindowsVirtualDesktop\image-template.json `
        -TemplateParameterFile .\scripts\WindowsVirtualDesktop\image-template.parameter.json `
        -galleryImageVersionName $ImageVersion -endOfLifeDate $expiryDate


    #################################
    #Step 8 - Delete temp VM
    #
    #  Delete VM which created image
    #
    #################################
    if ($imageOutput.Status -eq $true)
    {
        $NicId = $TempVM.NetworkProfile.NetworkInterfaces[0].Id
        $DiskId = $TempVM.StorageProfile.OsDisk.ManagedDisk.Id
        Remove-AzVM -ResourceGroupName $AZResourceGroup -Name $AzSysPrepVMname -Force
        Get-AzResource -ResourceId $NicId | Remove-AzResource -Force
        Get-AzResource -ResourceId $diskId | Remove-AzResource -Force
        Get-AzResource -ResourceId $snapshotResults.Outputs.snapshotResourceId.value | Remove-AzResource -Force
    }
    
    # Show Resource Id
    Get-AzResource -ResourceType 'Microsoft.Compute/galleries/images' -Name 'DevOps2020WithApps'
}