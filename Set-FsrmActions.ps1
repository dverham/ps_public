<#
.SYNOPSIS
    Het script blokkeert de gebruiker op de admin share waar misbruik herkent is door FSRM.

.DESCRIPTION
    Het script triggert door een File Screen en controleert het event log op entries van FSRM.
    De entry wordt ingelezen via een replacementstring array waar datapunten direct in opgeslagen zijn.
    Troubleshooting tip: om dit array uit te lezen : $Events.ReplacementStrings

    Daarna wordt een SUBACLCMD variabele samengesteld en daarna uitgevoerd om de rechten op de admin share te ontnemen. 

    Dit script is onderdeel van vier componenten:
    1: Add-FsrmServer.ps1 | Dit script stelt een nieuwe server in om FSRM te gebruiken.
    2: Set-FsrmActions.ps1 | Dit script voert de acties uit nadat Ransomware gedetecteerd is.
    3: Update-ExtensionsLocally.ps1 | Dit script werkt de extensies bij van de share op het netwerk.
    4: Update-Extensions.ps1 | Dit script haalt de extensies van het internet op en slaat deze lokaal op de management server op.
    Subinacl.exe op 2012 en hoger niet aan de gang gekregen / geen rechten om admin shares aan te passen 

.EXAMPLE
    ALLEEN UITVOEREN VIA FSRM, NIET VIA ENIGE ANDERE MANIEREN

.NOTES
    Gebaseerd op het origineel van Tim Buntrock, RansomwareBlockSmb.ps1, URL: https://gallery.technet.microsoft.com/scriptcenter/Protect-your-File-Server-f3722fce
    Aangepast door: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Automatische acties uitvoeren om een ransomware aanval te blokkeren.
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################

# Functie om logging inregelen.
# Voeg de tekst toe door de functie aan te roepen: Add-Logging 'bericht' of in geval van variabele Add-Logging "$Var".
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "C:\Scripts\Ransomware\Set-FsrmActions_"+$ENV:COMPUTERNAME+"_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
Dit is het logbestand van het script: Set-FsrmActions.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Set-FsrmActions.ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
    Clear-Variable LogMessage
}

function Disable-BadUser {
    Disable-ADAccount -Identity $BadUser
    Add-Logging "Het account $BadUser is geblokkeerd in AD."
}

##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Check EventLog
$Events = Get-EventLog -LogName application -Source SRMSVC -After (get-date).AddMinutes(-2) | select ReplacementStrings -Unique
# Ontleed het event naar de data points 
foreach ($Event in $Events) {
    $FullEvent = $Event.ReplacementStrings[0]
    $BadUser = $Event.ReplacementStrings[6]
    $SharePath = $Event.ReplacementStrings[1]
    $Rule = $Event.ReplacementStrings[2]
    $BadFile = $Event.ReplacementStrings[3]
    $Posi = $SharePath.IndexOf("\")
    $SharePart = $SharePath.Substring(0,1)
    $SubinaclCmd = "C:\Scripts\Ransomware\subinacl.exe /verbose=1 /share \\127.0.0.1\" + "$SharePart" + "$" + " /deny=" + "$BadUser"
# Zet een actie uit wanneer de rule matcht    
    if ($Rule -match "Ransomware") {
        # cmd /c $SubinaclCmd - Uitgezet; Niet meer mogelijk om rechten op administrative shares aan te passen.
        Add-Logging "$FullEvent"
        Add-Logging "$SubinaclCmd wordt uitgevoerd."
        Disable-BadUser
        Clear-Variable BadUser
    }
}
