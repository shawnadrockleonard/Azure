<#
Shawn Leonard
Cloud Solution Architect - Azure PaaS & Office365 | Microsoft Federal
BLOG – https://aka.ms/shawniq/   
LinkedIn - https://aka.ms/shawn-linkedin 

.DESCRIPTION
- This script downloads the Azure billing reports for a particular month.  

.REQUIREMENTS 
	- Access to the Enterprise Agreement Portal - https://ea.azure.com/ to collect the Accesskey and Enrollment number

.EXAMPLE

#>
[cmdletbinding(HelpUri = "https://github.com/shawnadrockleonard/Azure/scripts/AzInventory/readme.md", SupportsShouldProcess = $true)]
param
(
	[Parameter(Mandatory = $false)]
	[ValidateScript( { Test-Path $_ -PathType Container })]
	[string]$RunningDirectory,

	#Get the Azure Billing Enrollment Number from ea.azure.com under Manage->Enrollment Number
	[string]$EnrollmentNo,

	#Get the Accesskey from ea.azure.com under Reports->Download Usage->API Access Key. Create a new Access key if needed.
	[string]$Accesskey,

	#Change Month of the report - Use YYYY-MM date format
	[string]$Month = "2018-07" 
)
BEGIN {

	$baseurl = "https://ea.azure.com/"
	$baseurlRest = "https://ea.azure.com/rest/"


	#### READ IN Accesskey and Enrollment number
	./cred.ps1

	#Get the Accesskey from ea.azure.com under Reports->Download Usage->API Access Key. Create a new Access key if needed.
	$accesskey = $BearerKey


	$userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
	$authHeaders = @{
		"authorization" = "bearer $accesskey"
		"api-version"   = "1.0"
		"user-agent"    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36" 
 }

	#Export Azure Billing Report filename and locations
	$filename_detailRpt = "AzBilling_UsageData-Details_Month-$month-" + (Get-Date).ToString('yyyyMMddHHmmss') + ".csv"
	$filename_priceRpt = "AzBilling_UsageData-Price_Month-$month-" + (Get-Date).ToString('yyyyMMddHHmmss') + ".csv"
	$filename_summaryRpt = "AzBilling_UsageData-Summary_Month-$month-" + (Get-Date).ToString('yyyyMMddHHmmss') + ".csv"

	# Specifies the directory in which this should run
	$runningscriptDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
	if ($RunningDirectory -eq "") {
		$RunningDirectory = $runningscriptDirectory
	}
        
	$logDirectory = Join-Path -Path $RunningDirectory -ChildPath "_logs"
	if (!(Test-Path -Path $logDirectory -PathType Container)) {
		New-Item -Path $logDirectory -Force -ItemType Directory -WhatIf:$false | Out-Null
		$logDirectory = Join-Path -Path $RunningDirectory -ChildPath '_logs' -Resolve
	}     

	$rptDetail = Join-Path -Path $logDirectory -ChildPath $filename_detailRpt
	$rptPrice = Join-Path -Path $logDirectory -ChildPath $filename_priceRpt
	$rptSummary = Join-Path -Path $logDirectory -ChildPath $filename_summaryRpt

}
PROCESS {
	Try {
		#Get all usage reports
		Write-Host "Gathering billing Reports for Month: $month ..." -ForegroundColor Green
		$url = $baseurlRest + $enrollmentNo + "/usage-reports"
		$sResponse = Invoke-WebRequest $url -Headers $authHeaders -UserAgent $userAgent -Verbose
		$sContent = $sResponse.Content | ConvertFrom-Json

		#Get Download links for $month
		$downloadlinks = $sContent.AvailableMonths | Where-Object { $_.Month -eq $month }

		if ($downloadlinks) {
			$downloadDetailReport = $downloadlinks.LinkToDownloadDetailReport 
			$downloadPriceReport = $downloadlinks.LinkToDownloadPriceSheetReport
			$downloadSummaryReport = $downloadlinks.LinkToDownloadSummaryReport
 
			Write-Host "Downloading Azure Billing Reports..." -ForegroundColor Green
			$url_DetailReport = $baseurl + $downloadDetailReport
			$url_PriceReport = $baseurl + $downloadPriceReport
			$url_SummaryReport = $baseurl + $downloadSummaryReport

			#Start downloading the Reports
			# Details Report
			Invoke-WebRequest $url_DetailReport -Headers $authHeaders -OutFile $rptDetail -UserAgent $userAgent -Verbose
			# Price Report
			Invoke-WebRequest $url_PriceReport -Headers $authHeaders -OutFile $rptPrice -UserAgent $userAgent -Verbose
			# Summary Report
			Invoke-WebRequest $url_SummaryReport -Headers $authHeaders -OutFile $rptSummary -UserAgent $userAgent -Verbose

			Write-Host "Finished Downloading the Azure Billing Reports..." -ForegroundColor Green 
			Write-Host "Completed Sucessfully!" -ForegroundColor Green
		}
		else {
			Write-Host "Error: Unable to get the download links for Month: $month!" -ForegroundColor Red
		}
	}
	Catch [System.Exception] {
		$loopLine = $_.InvocationInfo.ScriptLineNumber;
		$loopEx = $_.Exception;
		$errMessage = "Exception at line $loopLine message: $loopEx"
		Write-Host $errMessage -ForegroundColor Red		
	} #end Catch
}