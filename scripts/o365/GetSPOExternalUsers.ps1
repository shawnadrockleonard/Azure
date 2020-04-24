# Assumes sign-in assistant (beta)
# assumes Windows Azure Powershell installed
Import-Module MSOnline

$curService = Connect-Msolservice 


$incrementAmount = 50
$curPos = 0

while ($curPos -gt -1) {
    try {

        $externalUsers = Get-SPOExternalUser -Position $curPos -PageSize $incrementAmount -ErrorAction SilentlyContinue
        if ($externalUsers.length -gt 0) {
            $curPos = $curPos + $incrementAmount
        }
        else {
            $curPos = -1
        }
        $externalUsers

    }
    catch {
        $curPos = -1
    }
}