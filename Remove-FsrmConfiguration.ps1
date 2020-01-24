<#
.SYNOPSIS
    Het script controleert de configuratie van FSRM en verwijderd deze automatisch.

.DESCRIPTION
    Het script controleert de instellingen die deze toolkit configureert voor FSRM en schoont deze op. 
    Zo worden de volgende zaken in volgorde opgeschoond;
    1; Scripts folder
    2; FSRM configuratie
    3; Update taak 
    4; Het computerobject wordt uit de FSRM groep gehaald

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
    .\Remove-FsrmConfiguration.ps1

.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Haalt FSRM configuratie weg.
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################

# Functie om logging inregelen.
# Voeg de tekst toe door de functie aan te roepen: Add-Logging 'bericht' of in geval van variabele Add-Logging "$Var".
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "pad\log\Remove-FsrmConfiguration_"+$ENV:COMPUTERNAME+"_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Definieer de header
$Header = "************************************************************************************************
Dit is het logbestand van het script: Remove-FsrmConfiguration.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
Het script verwijderd de FSRM configuratie op $ENV:COMPUTERNAME
************************************************************************************************"
# Voeg de koptekst toe aan het logbestand en de variabele
Add-Content $logFile -value $Header
$LogVariable.Add($Header) | Out-Null
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") | Out-Null
    $LogVariable[-1]
    Clear-Variable LogMessage
}

function Remove-RansomwareFolder {
    $CheckRansomwareFolder = Test-Path -Path 'C:\Scripts\Ransomware'
    if ($CheckRansomwareFolder -eq 'True'){
        Add-Logging 'Het pad C:\Scripts\Ransomware is gevonden en wordt verwijderd!'
        Remove-Item -Path C:\Scripts\Ransomware -Recurse
    }
    else {
        Add-Logging 'Het pad C:\Scripts\Ransomware bestaat niet.'
    }
}

function Remove-FsrmConfig {
    # Schoon de File Screens op
    $FilteredScreens = Get-FsrmFileScreen | where {$_.Template -match "Ransomware"}
    foreach ($FS in $FilteredScreens) {
        Add-Logging "Er is een Ransomware File Screen gevonden op $($FS.Path), en wordt nu verwijderd."
        Remove-FsrmFileScreen -Path $FS.Path -Confirm:$false
    }
    # Schoon de Ransomware template op
    $FilteredTemplate = Get-FsrmFileScreenTemplate | where {$_.Name -match "Ransomware"}
    Add-Logging "De volgende File Screen Template is gevonden: $($FilteredTemplate.Name), en wordt verwijderd."
    Remove-FsrmFileScreenTemplate $FilteredTemplate.Name -Confirm:$false
    # Schoon de File Group op
    $FilteredFileGroup = Get-FsrmFileGroup | where {$_.Name -match "Ransomware"}
    Add-Logging "De volgende File Group is gevonden: $($FilteredFileGroup.Name), en wordt verwijderd."
    Remove-FsrmFileGroup -Name $FilteredFileGroup.Name -Confirm:$false
}

function Remove-UpdateTask {
    $FilteredScheduledtask = Get-ScheduledTask | where {$_.TaskName -match "FSRM - Update File Screen Group - Ransomware_Extensions"}
    Unregister-ScheduledTask -TaskName $FilteredScheduledtask.TaskName -Confirm:$false
    Add-Logging 'De update task in de task schedular is verwijderd.'
}

function Remove-FromGroup {
    $LocalHost = $ENV:COMPUTERNAME
    $FilteredGroup = Get-AdGroup -Identity 'DoC - FsrmConfig'
    $FilteredGroupMembers = Get-ADGroupMember -Identity $FilteredGroup
    if ($FilteredGroupMembers.Name -contains $LocalHost) {
        Add-Logging "Het computerobject $LocalHost wordt uit de groep $($FilteredGroup.name) gehaald."
        Remove-ADGroupMember -Identity $FilteredGroup -Members $FilteredGroupMembers -Confirm:$false
    }
    else {
        Add-Logging "Het computerobject $LocalHost is geen lid van de groep $($FilteredGroup.name)."
    }
}

##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Schoon de C:\Scripts\Ransomware folder op
Remove-RansomwareFolder
# Schoon de FSRM configuratie op
Remove-FsrmConfig
# Schoon de update taak op
Remove-UpdateTask
# Verwijder het computerobject uit de groep DoC - FsrmConfig
Remove-FromGroup
# Einde van het script
Add-Logging 'Het einde van het script is bereikt.'
Add-Logging "Logging is terug te vinden op $LogFile"
Start-Sleep 10
