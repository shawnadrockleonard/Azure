[cmdletbinding()]
PARAM(
    [switch]$TestIt
)
PROCESS
{
    $context = Get-AzContext

    if ($TestIt)
    {
        
        New-AzResourceGroupDeployment -Name "azcmdlets-FunctionApp-QueueProcessor1" -ResourceGroupName "coalitionhub" -Mode Incremental `
            -TemplateFile .\infrastructure\azuredeploy.json `
            -TemplateParameterFile .\infrastructure\azuredeploy.parameters.json -creator $context.Account.Id -WhatIf -Verbose
    }
    else
    {
        New-AzResourceGroupDeployment -Name "azcmdlets-FunctionApp-QueueProcessor1" -ResourceGroupName "coalitionhub" -Mode Incremental `
            -TemplateFile .\infrastructure\azuredeploy.json `
            -TemplateParameterFile .\infrastructure\azuredeploy.parameters.json -creator $context.Account.Id -Verbose
    }
    Write-Host "Deployment finished ..."
}
