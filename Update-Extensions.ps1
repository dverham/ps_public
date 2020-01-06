$Extensions = (Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/combined" -UseBasicParsing).content | convertfrom-json | % {$_.filters}
$Extensions | Out-File E:\Pad\Ransomware\Known_Extensions.txt
