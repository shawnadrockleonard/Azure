$uri = (Get-ChildItem Env:\dep_uri).Value
$sas = (Get-ChildItem Env:\dep_sas).Value
$sqlpassword = ConvertTo-SecureString -String (Get-ChildItem Env:\dep_password).Value -AsPlainText -Force


New-AzResourceGroupDeployment -Name "testdeploy" -ResourceGroupName "devtest-labs-va-DevSecure-024011" -Mode Incremental `
    -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json `
    -DatabaseAdministratorLoginPassword $sqlpassword `
    -Verbose -WhatIf


New-AzResourceGroupDeployment -Name "testdeploy" -ResourceGroupName "devtest-labs-va-DevSecure-024011" -Mode Incremental `
    -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json `
    -DatabaseAdministratorLoginPassword $sqlpassword `
    -Verbose

    