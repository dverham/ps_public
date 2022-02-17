Function Connect-Exchange {
    Write-Host 'Wat is de FQDN van de Exchange server?: ' -NoNewLine
    $GetServer = Read-Host
    $ConURI = 'http://'+$GetServer+'/PowerShell/'
    $UserCredential = Get-Credential
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ConURI -Authentication Kerberos -Credential $UserCredential
    Import-PSSession $Session -DisableNameChecking
}

Function Get-AllDistributionGroupsOnConsole {
    $AllDl = Get-DistributionGroup
    foreach ($DL in $Alldl) {
        $DlMembers = Get-DistributionGroupMember $DL.PrimarySmtpAddress | select -ExpandProperty Name
        $TotalMembers = $DlMembers.Count
        Write-Host -ForegroundColor Green "De naam van de distributiegroep is: $Dl.Name"
        Write-Host -ForegroundColor Green "De lijst heeft $TotalMembers lid/leden, te weten:  "
        $DlMembers
        start-sleep -Seconds 3
    }
}

Function Export-AllDistributionGroups {
    # Test het pad C:\Detron
    $PathExist = Test-Path 'C:\Detron'
    if ($PathExist -match $false) {
        Write-Host 'Het pad C:\Detron bestaat nog niet. De map wordt nu aangemaakt.'
        New-Item -Path 'C:\' -Name 'Detron' -ItemType 'Directory' | Out-Null
    } else {
    Write-Host 'Het pad C:\Detron bestaat en wordt niet aangemaakt.'
    }
    # Maak een overzicht van de file names naar mail adressen.
    [System.Collections.ArrayList]$FileToEmail = @()
    # Vraag de DLs op en exporteer deze naar C:\Detron.
    $AllDl = Get-DistributionGroup
    foreach ($DL in $Alldl) {
        $DlFileName = 'C:\Detron\'+$DL.Name+'_export.csv'
        $DlMembers = Get-DistributionGroupMember $DL.PrimarySmtpAddress #| select -ExpandProperty Name
        $DlMembers | Export-Csv -Path $DlFileName -NoClobber -NoTypeInformation
        $LogMessage = "De Distributielijst genaamd: "+$DL.Name+" heeft het e-mail adres: "+$DL.PrimarySmtpAddress
        $FileToEmail += $LogMessage
    }
    Write-Host -ForegroundColor Green 'De leden zijn per distributiegroep geexporteerd naar C:\Detron'
    $FileToEmail | Out-File -FilePath 'C:\Detron\01-Overzicht.txt'-NoClobber
    Write-Host -ForegroundColor Green 'Het bestand C:\Detron\01-Overzicht.txt geeft een overzicht van de DL en het bijbehorende mail adres.'
}

######### Start Script
clear-host
Write-Host -ForeGroundColor Yellow 'Wil je een verbinding opzetten met de lokale Exchange server? (1)'
Write-host -ForeGroundColor Yellow 'Wil je de bestaande distributielijsten met op de console laten zien (2)'
write-host -ForeGroundColor Yellow 'Wil je de bestaande distributielijsten met leden exporteren naar C:\Detron (3)'
write-host -ForeGroundColor Yellow 'Maak je keuze: ' -NoNewline
$ToDo = Read-Host
 switch ($ToDo){
    1 {
        Connect-Exchange
    }
    2 {
        Get-AllDistributionGroupsOnConsole
    }
    3 {
        Export-AllDistributionGroups
    }
    default {
        Write-Host -ForegroundColor Red "De keuze $ToDo is geen geldige keuze. Voer het script opnieuw uit."
    }
}