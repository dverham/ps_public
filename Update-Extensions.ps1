<#
.SYNOPSIS
    Voer dit script uit om de meest recente extensies te downloaden. Deze extensies worden opgeslagen
    in het tekstbestand op de management server.

.DESCRIPTION
    Het script download de meest recente extensies van https://fsrm.experiant.ca/api/v1/combined en slaat
    dit op in het bestand padnaarbeheerserver\known_extensions.txt 
    
    Het script maakt een backup van het known_extensions.txt bestand en slaat dit op in 
    padnaarbeheerserver\backup_updateextensions. Er worden 7 kopieen bewaard.

    Het script maakt een backup van het aanwezige exclusion bestand en maakt een kopie in
    padnaarbeheerserver\backup_updateexclusions. Er worden 7 kopieen bewaard.

    Dit script is onderdeel van de FSRM toolkit, bestaande uit:
    - Inrichting                        Doel
    1: Add-PassiveFsrmServer.ps1        Dit richt FSRM met passieve File Screens in. (Monitoring)
    2: Add-ActiveFsrmServer.ps1         Dit richt FSRM met actieve File Screens in. (Productie)
    3: Set-PassiveScreensToActive.ps1   Dit converteert een monitoring inrichting naar een productie inrichting.
    
    - Countermeasures                   Doel
    1: Set-FsrmActions.ps1              Voert de acties uit om Ransomware tegen te gaan.

    - Supporting                        Doel
    1: Remove-FsrmConfiguration.ps1     Haalt FSRM configuratie weg.
    2: Update-Extensions.ps1            Download extensies van https://fsrm.experiant.ca/api/v1/combined.
    3: Update-ExtensionsInternally.ps1  Download extensies en exclusions lokaal, werkt de File Group bij.
    4: Update-RemoteFsrmServers.ps1     Vraagt leden op van de FSRM groep en triggert de remote update taak.
        
.EXAMPLE
    .\Update-Extensions.ps1

.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Download extensies van https://fsrm.experiant.ca/api/v1/combined
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################
function Set-backupFiles {
    # Controleer dat Known_Extensions bestaat en maak een backup
    $CheckExtensionsFile = Test-Path 'pad\FsrmConfig\Known_Extensions.txt'
    $CheckExclusionsFile = Test-Path 'pad\FsrmConfig\ZDL_Exclusions.txt'
    if ($CheckExtensionsFile -match 'True') {
        $NewFileName = "pad\FsrmConfig\Backup_UpdateExtensions\Known_Extensions_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".txt"
        copy-item 'pad\FsrmConfig\Known_Extensions.txt' -Destination $NewFileName -Confirm:$false
    }
    else {
        $ErrorFileName = "pad\FsrmConfig\Backup_UpdateExtensions\Error_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".txt"
        New-item -ItemType file -Path $ErrorFileName
        Add-Content -Path $ErrorFileName -Value "Het bronbestand is niet gevonden."
    }
    if ($CheckExclusionsFile -match 'True') {
        $NewFileName = "pad\FsrmConfig\Backup_UpdateExclusions\Exclusions_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".txt"
        copy-item 'pad\FsrmConfig\ZDL_Exclusions.txt' -Destination $NewFileName -Confirm:$false
    }
    else {
        $ErrorFileName = "pad\FsrmConfig\Backup_UpdateExclusions\Error_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".txt"
        New-item -ItemType file -Path $ErrorFileName
        Add-Content -Path $ErrorFileName -Value "Het bronbestand is niet gevonden."
    }
    # Ruim oude backups na 7 dagen op
    Get-ChildItem -Path 'pad\FsrmConfig\Backup_UpdateExtensions' -Recurse -File | where LastWriteTime -lt (Get-Date).AddDays(-8) | Remove-Item -Force
    Get-ChildItem -Path 'pad\FsrmConfig\Backup_UpdateExclusions' -Recurse -File | where LastWriteTime -lt (Get-Date).AddDays(-8) | Remove-Item -Force
}

function Update-KnownExtensions {
    $Extensions = (Invoke-WebRequest -Proxy 'http://proxy-lb.zorg.local:8080' -ProxyUseDefaultCredentials -Uri "https://fsrm.experiant.ca/api/v1/combined" -UseBasicParsing).content | convertfrom-json | % {$_.filters}
    $Extensions | Out-File 'pad\FsrmConfig\Known_Extensions.txt'
}

function Update-Log {
    $Today = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    $Today | Out-File "pad\FsrmConfig\UpdateLog.txt" -Append
}

##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Maak een backup en schoon verouderde backups op
Set-BackupFiles
# Werk de extensies bij
Update-KnownExtensions
# Werk het UpdateLog.txt bestand bij
Update-Log
