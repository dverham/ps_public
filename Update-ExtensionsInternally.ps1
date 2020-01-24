<#
.SYNOPSIS
    Voer dit script uit om de exclusions en extensions te downloaden vanaf de beheer server.
    Daarna werkt het script de File Group bij.

.DESCRIPTION
    Het script download known_extensions.txt en ZDL_Exclusions.txt naar C:\Scripts\Ransomware.
    Daarna werkt het script de File Group 'Ransomware_Extensions' bij.

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
    .\Update-ExtensionsInternally.ps1

.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Download extensies en exclusions lokaal, werkt de File Group bij.
#>

##########################################################################################
###                             Script                                                 ###
##########################################################################################
xcopy 'pad\FsrmConfig\Known_Extensions.txt' 'C:\Scripts\Ransomware' /Y
xcopy 'pad\FsrmConfig\ZDL_Exclusions.txt' 'C:\Scripts\Ransomware' /Y
$Extensions = Get-Content 'C:\Scripts\Ransomware\Known_Extensions.txt'
$Exclusions = Get-Content 'C:\Scripts\Ransomware\ZDL_Exclusions.txt'
Set-FsrmFileGroup -name "Ransomware_Extensions" -IncludePattern($Extensions) -ExcludePattern($Exclusions)
