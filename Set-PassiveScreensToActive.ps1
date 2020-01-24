<#
.SYNOPSIS
    Gebruik dit script wanneer er al passieve screens aangemaakt zijn en deze omgezet moeten worden naar 
    actieve screens.

.DESCRIPTION
    Voer dit script alleen uit wanneer het script 'Add-PassiveFsrmServers.ps1' al uitgevoerd is. Het script zal stoppen
    wanneer er geen passieve screens gevonden worden.

    Als er passieve screens gevonden worden zal het script het Set-FsrmActions.ps1 script kopieren naar C:\Scripts\Ransomware.
    Daarna zal het script de passieve screens verwijderen en de template verwijderen aangezien deze werkt met passieve screens.
    Hierna wordt een nieuw template aangemaakt met actieve screens en worden de file screens ingesteld.
    Daarna wordt het computerobject aan de FSRM groep toegevoegd en als laatste controleert het script dat de update taak aanwezig is.
    Mocht deze niet aanwezig zijn, dan zal deze alsnog aangemaakt worden.
    
    Dit script is onderdeel van de FSRM toolkit, bestaande uit:
    - Inrichting                        Doel
    1: Add-PassiveFsrmServer.ps1        Dit richt FSRM met passieve File Screens in. (Monitoring)
    2: Add-ActiveFsrmServer.ps1         Dit richt FSRM met actieve File Screens in. (Productie)
    3: Set-PassiveScreensToActive.ps1   Dit converteert een monitoring inrichting naar een productie inrichting.
    
    - Countermeasures                   Doel
    1: Set-FsrmActions.ps1              Voert de actis uit om Ransomware tegen te gaan.

    - Supporting                        Doel
    1: Remove-FsrmConfiguration.ps1     Haalt FSRM configuratie weg.
    2: Update-Extensions.ps1            Download extensies van https://fsrm.experiant.ca/api/v1/combined.
    3: Update-ExtensionsInternally.ps1  Download extensies en exclusions lokaal, werkt de File Group bij.
    4: Update-RemoteFsrmServers.ps1     Vraagt leden op van de FSRM groep en triggert de remote update taak.    
  
.EXAMPLE
    .\Set-PassiveScreensToActive.ps1

.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Dit converteert een monitoring inrichting naar een productie inrichting.
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################

# Functie om logging inregelen.
# Voeg de tekst toe door de functie aan te roepen: Add-Logging 'bericht' of in geval van variabele Add-Logging "$Var".
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "pad\log\Set-PassiveScreensToActive_"+$ENV:COMPUTERNAME+"_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Definieer de header
$Header = "************************************************************************************************
Dit is het logbestand van het script: Set-PassiveScreensToActive.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
Het script vraagt de PASSIVE screens op en maakt deze ACTIVE. 
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

function Get-PassiveFileScreens {
    $PassiveFileScreens = Get-FsrmFileScreen | where {$_.Active -match 'False' -and $_.Template -match 'Ransomware'}
    if($PassiveFileScreens) {
        $Prereq = 'True'
        Add-Logging 'Er zijn passieve File Screens gevonden. Het script wordt uitgevoerd.'
    }
    else {
        $Prereq = 'False'
        Add-Logging 'Er zijn geen passieve File Screens gevonden. Heb je het juiste script gebruikt? Het script stopt nu.'
        exit
    }
}

function Add-Scripts {
    xcopy '\\zorg\data\FsrmConfig\Set-FsrmActions.ps1' 'C:\Scripts\Ransomware' /Y
    Add-Logging 'Het Set-FsrmActions.ps1 script is gekopieerd naar C:\Scripts\Ransomware.'
}

function Remove-PassiveFileScreens {
    # Schoon de File Screens op
    $FilteredScreens = Get-FsrmFileScreen | where {$_.Template -match "Ransomware"}
    foreach ($FS in $FilteredScreens) {
        Add-Logging "Er is een passive Ransomware File Screen gevonden op $($FS.Path), en wordt nu verwijderd."
        Remove-FsrmFileScreen -Path $FS.Path -Confirm:$false
    }
    # Schoon de Ransomware template op
    $FilteredTemplate = Get-FsrmFileScreenTemplate | where {$_.Name -match "Ransomware"}
    Add-Logging "De volgende passive File Screen Template is gevonden: $($FilteredTemplate.Name), en wordt verwijderd."
    Remove-FsrmFileScreenTemplate $FilteredTemplate.Name -Confirm:$false
}

function Add-ActiveFileScreens {
    # Maak een File Screen template aan
    $MA = New-FsrmAction -Type Email -MailTo "[Admin Email]" -Subject "$ENV:COMPUTERNAME FSRM Ransomware Notification!" -Body "User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server." 
    $EA = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server." -RunLimitInterval 1
    $CA = New-FsrmAction -Type Command -Command "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -CommandParameters "-ExecutionPolicy Bypass -Command &{C:\Scripts\Ransomware\Set-FsrmActions.ps1}" -WorkingDirectory "C:\Scripts\Ransomware" -SecurityLevel LocalSystem -KillTimeOut 5 -RunLimitInterval 0
    [Ciminstance[]]$Notifications = $MA,$EA,$CA
    New-FsrmFileScreenTemplate -Name "Ransomware Template" -Description "Template wordt gebruikt om een File Screen te maken" -IncludeGroup @('Ransomware_Extensions') -Notification $Notifications
    Add-Logging 'De File Screen template genaamd Ransomware Template is aangemaakt.'
    
    # Maak de file screens aan
    [System.Collections.ArrayList]$PreppedVols = @()
    $Vol = Get-Volume | where {$_.DriveType -match 'Fixed' -And $_.FileSystemLabel -notmatch 'System Reserved' -And $_.DriveLetter -notmatch 'C'}
    foreach ($DL in ($Vol.DriveLetter)) {
        $PreppedDL = $DL+':\'
        $PreppedVols += $PreppedDL
        Add-Logging "De volgende drive is gevonden: $PreppedDL"
    }
    foreach ($PDL in $PreppedVols) {
        New-FsrmFileScreen -Path "$PDL" -Template "Ransomware Template"
        Add-Logging "Er is een active File Screen aangemaakt van de template Ransomware Template voor het pad: $PDL"
    }
}

function Add-ToGroup {
    # Voeg het computerobject toe aan de DoC-FsrmConfig groep in AD.
    $LocalComputer = Get-ADComputer -Identity $ENV:COMPUTERNAME
    $DocGroup = 'Doc - FsrmConfig'
    $DocGroupMembers = Get-ADGroupMember -Identity $DocGroup | select -ExpandProperty Name
    if ($DocGroupMembers -contains $LocalComputer.Name){
        Add-Logging "De computer $LocalComputer is al lid van $DocGroup."
        Add-Logging 'Het toevoegen wordt overgeslagen.'
    }
    else {
        Add-ADGroupMember -Identity 'DoC - FsrmConfig' -Members $LocalComputer
        Add-Logging "De computer $LocalComputer is toegevoegd aan de groep $DocGroup."
    }
}

function Get-UpdateTask {
    $FilteredScheduledtask = Get-ScheduledTask | where {$_.TaskName -match "FSRM - Update File Screen Group - Ransomware_Extensions"}
    if ($FilteredScheduledtask) {
        Add-Logging "De update taak genaamd $($FilteredScheduledTask.TaskName) bestaat."
    }
    else {
        $Action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-ExecutionPolicy Bypass C:\Scripts\Ransomware\Update-ExtensionsInternally.ps1'
        $Trigger = New-ScheduledTaskTrigger -Daily -At 9am
        Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskPath FSRM -TaskName 'FSRM - Update File Screen Group - Ransomware_Extensions' -Description 'FSRM - Update File Screen Group - Ransomware_Extensions' -User 'System'
        Add-Logging "De update taak bestond niet en is opnieuw aangemaakt."
    }
}

##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Check dat er PASSIVE file screens aanwezig zijn
Get-PassiveFileScreens
# Kopieer het Set-FsrmActions.ps1 script naar C:\Scripts\Ransomware
Add-Scripts
# Verwijder de passive file screens
Remove-PassiveFileScreens
# Maak de template aan met de juiste acties en file screens
Add-ActiveFileScreens
# Voeg het computerobject toe aan de groep
Add-ToGroup
# Controleer dat de update taak bestaat
Get-UpdateTask
# Einde van het script
Add-Logging 'Het einde van het script is bereikt.'
Add-Logging "Logging is terug te vinden op $LogFile"
Start-Sleep 10
