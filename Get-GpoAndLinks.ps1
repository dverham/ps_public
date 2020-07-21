# Maak de arrays aan
[System.Collections.ArrayList]$IsAssigned = @()
[System.Collections.ArrayList]$IsNotAssigned = @()
# Verdeel de GPOs naar Assigned en Not Assigned
foreach ($Gpo in $AllGpos) {
    [xml]$gpoReport = Get-GPOReport -Guid $Gpo.Id -ReportType xml
    if (-not $gpoReport.GPO.LinksTo) {
        $IsNotAssigned += $Gpo.Id
    }
    else {
        $IsAssigned += $Gpo.Id
    }
}
# Geef de totalen weer
Write-Host -ForegroundColor Yellow "Er zijn $($IsNotAssigned.Count) GPO's zonder links."
Write-Host -ForegroundColor Green "Er zijn $($IsAssigned.Count) GPO's gelinked aan OU's."
# Bouw een overzicht van GPO's en links
[System.Collections.ArrayList]$Overview = @()
# -join wordt gebruikt om te voorkomen dat bij het exporteren data weergegeven wordt als System.Object[]
foreach ($Id in $IsAssigned) {
    $TempGpo = Get-GPO -GUID $Id
    [xml]$gpoReport = Get-GPOReport -Guid $Id -ReportType xml
    $SOMPath = $GpoReport.Gpo.LinksTo | select -ExpandProperty SOMPath
    # Voeg custom object awesomeness toe
    $Object = New-Object psobject -Property @{
        DisplayName     = $TempGpo.DisplayName
        GpoStatus       = $TempGpo.GpoStatus
        Description     = $TempGpo.Description
        LinksTo         = ($SOMPath -join ',')
    }
    $Overview += $Object
    Clear-Variable TempGpo
    Clear-Variable gpoReport
    Clear-Variable SOMPath
    Clear-Variable Object
}
# Sla overzichten op
$Scriptfolder = Test-Path 'c:\scripts'
if ($Scriptfolder -match 'False') {
    Write-Host -ForegroundColor Yellow 'Scriptfolder niet gevonden. C:\Scripts wordt aangemaakt.'
    New-Item -Path 'C:\' -Name 'Scripts' -ItemType 'Directory' | Out-Null
}
$Overview | Export-Csv -Path 'C:\Scripts\Overview.csv' -NoClobber -NoTypeInformation
Write-Host -ForeGroundColor Green 'C:\Scripts\Overview.csv bevat het overzicht van GPOs en links in CSV format'
