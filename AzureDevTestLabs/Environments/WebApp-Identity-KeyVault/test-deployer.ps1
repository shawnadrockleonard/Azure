$uri = (Get-ChildItem Env:\dep_uri).Value
$sas = (Get-ChildItem Env:\dep_sas).Value
$sassecret = ConvertTo-SecureString -String $sas -AsPlainText
$sqlpassword = ConvertTo-SecureString -String (Get-ChildItem Env:\dep_password).Value -AsPlainText


New-AzResourceGroupDeployment -Name "testdeploy" -ResourceGroupName "devtest-labs-va-DevSecure-024011" -Mode Incremental `
    -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json `
    -_artifactsLocation $uri -_artifactsLocationSasToken $sassecret -DatabaseAdministratorLoginPassword $sqlpassword `
    -Verbose -WhatIf


New-AzResourceGroupDeployment -Name "testdeploy" -ResourceGroupName "devtest-labs-va-DevSecure-024011" -Mode Incremental `
    -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json `
    -_artifactsLocation $uri -_artifactsLocationSasToken $sassecret -DatabaseAdministratorLoginPassword $sqlpassword `
    -Verbose

    