<#
.SYNOPSIS
    Het script installeert de File Server Resource Manager op een server. Daarna worden de volgende zaken automatisch ingesteld;
    1: File Groups
    2: File Screen Template
    3: File Screens (Per drive)
 
.DESCRIPTION
    Het script werkt alleen vanaf Server 2012 en hoger. 
 
    Als eerste checkt het script dat de folder C:\Scripts bestaat en maakt deze aan wanneer deze niet bestaat. Vervolgens worden de benodigde bestanden 
    gekopieerd naar C:\Scripts.
    
    Het script controleert de aanwezigheid van FSRM. Wanneer deze rol niet geinstalleerd is, zal deze rol geinstalleerd worden.
    Daarna zal de melding weergegeven worden dat de server opnieuw gestart moet worden. Dit gebeurt niet automatisch. Het script stopt. 
    Voer het script opnieuw uit na herstart.
 
    Nu worden de generieke opties van FSRM ingesteld. (Mail server, Admin Mail adres, default FROM address)
    Daarna wordt een File Group genaamd 'Ransomware_Extensions'. Deze groep wordt in beginsel gevuld met één extensie en daarna bijgewerkt
    met een online lijst van bekende Cryptoware extensies. (fsrm.experiant.ca)
    Daarna maakt het script een template aan met de naam Ransomware Template en stelt de notificaties in. 
    Als laatste vraagt het script alle drives op van het systeem en filtert de verwijderbare drivers en system reserved uit de lijst. De 
    overgebleven drives worden voorzien van een File Screen in Active mode. De C: drive is de enige drive die een Passive File Screen krijgt. 
 
    Dit script is onderdeel van vier componenten:
    1: Add-FsrmServer.ps1 | Dit script stelt een nieuwe server in om FSRM te gebruiken.
    2: Set-FsrmActions.ps1 | Dit script voert de acties uit nadat Ransomware gedetecteerd is.
    3: subinacl.exe | Deze executable zorgt er voor dat de rechten weg genomen worden op de share.
    
.EXAMPLE
    .\Add-FsrmServer.ps1
 
.NOTES
    Gebaseerd op het origineel van Tim Buntrock, RansomwareBlockSmb.ps1, URL: https://gallery.technet.microsoft.com/scriptcenter/Protect-your-File-Server-f3722fce
    Aangepast door: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Automatisch instellen op verschillende Windows Server versies.
#>
 
##########################################################################################
###                             Functions                                              ###
##########################################################################################
 
# Functie om logging inregelen.
# Voeg de tekst toe door de functie aan te roepen: Add-Logging 'bericht' of in geval van variabele Add-Logging "$Var".
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "\\Path\log\Add-FsrmServer_"+$ENV:COMPUTERNAME+"_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
Dit is het logbestand van het script: Add-FsrmServer.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Add-FsrmServer.ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
    Clear-Variable LogMessage
}
 
Function Get-ServerOS {
    # Stel vast welk OS gebruikt wordt. Het script werkt alleen vanaf Server 2012 en hoger.
    $OSver = (Get-WmiObject Win32_OperatingSystem).Name
    if  ($OSver -match '2019') {
        Add-Logging 'Windows Server 2019 is gevonden.'
        $Global:OS = 'Server2019'
    }
    elseif ($OSver -match '2016') {
        Add-Logging 'Windows Server 2016 is gevonden.'
        $Global:OS = 'Server2016'
    }
    elseif ($OSver -match '2012'){
        Add-Logging 'Windows Server 2012 is gevonden.'
        $Global:OS = 'Server2012'
    }
    elseif ($OSver -match '2008') {
        Add-Logging 'Windows Server 2008 is gevonden.'
        Add-Logging 'Tijd om een upgrade uit te voeren! Het script stopt'
        exit
    }
    else {
        Add-Logging 'Geen supported OS gevonden'
        Add-Logging 'Het script stopt.'
        exit
    }
}
 
Function Set-ScriptFolder {
    $ScriptsFolder = Test-Path 'C:\Scripts'
    if ($ScriptsFolder -notlike 'True') {
        New-Item -ItemType Directory -Path 'C:\Scripts'
        Add-Logging 'C:\Scripts folder is aangemaakt.'
    }
    else {
        Add-Logging 'C:\Scripts folder bestaat al.'
    }
    $RansomwareFolder = Test-Path 'C:\Scripts\Ransomware'
    $CopyCMD = ''
    if ($RansomwareFolder -notlike 'True') {
        New-Item -ItemType directory -Path 'C:\Scripts\Ransomware'
        Add-Logging 'C:\Scripts\Ransomware folder is aangemaakt.'
        xcopy '\\SERVER\FsrmConfig$\Set-FsrmActions.ps1' 'C:\Scripts\Ransomware' /Y
        # xcopy '\\SSERVER\FsrmConfig$\subinacl.exe' 'C:\Scripts\Ransomware' /Y
        xcopy '\\SERVER\FsrmConfig$\Update-ExtensionsInternally.ps1' 'C:\Scripts\Ransomware' /Y
        Add-Logging 'De scripts zijn gekopieerd naar C:\Scripts\Ransomware.'
    }
    else {
        Add-Logging 'De C:\Scrips\Ransomware folder bestaat al.'
        xcopy '\\SERVER\FsrmConfig$\Set-FsrmActions.ps1' 'C:\Scripts\Ransomware' /Y
        # xcopy '\\SERVER\FsrmConfig$\subinacl.exe' 'C:\Scripts\Ransomware' /Y
        xcopy '\\SERVER\FsrmConfig$\Update-ExtensionsInternally.ps1' 'C:\Scripts\Ransomware' /Y
        Add-Logging 'De scripts zijn gekopieerd naar C:\Scripts\Ransomware.'
    }
}
 
function Get-FsrmStatus {
    $FSRole = Get-WindowsFeature -Name 'FS-Resource-Manager' | select Name,InstallState
    if ($FSRole.InstallState -like 'Installed') {
        $Global:FsrmStatus = $FSRole.InstallState
        Add-Logging 'De File Server rol is gevonden en heeft de status Installed.'
    }
    else{
        $Global:FsrmStatus = $FSRole.InstallState
        Add-Logging 'De File Server Resource Manager rol is niet gevonden.'
    }
}
 
function Add-FsrmRole {
    If ($Global:FsrmStatus -notlike 'Installed') {
        Add-Logging 'We gaan nu de File Server Resource Manager rol installeren.'
        Add-Logging 'Er is een herstart nodig na het installeren van de rol. Deze wordt niet automatisch uitgevoerd.'
        Install-WindowsFeature -Name 'FS-Resource-Manager' -IncludeManagementTools
        Add-Logging 'Herstart de server en voer het script daarna opnieuw uit.'
        Add-Logging 'Let op: Tijdens testen hebben we gezien dat sommige servers 2 reboots nodig hebben.'
        Start-Sleep 10
        exit
    }
    else {
        Add-Logging 'De FSRM rol is al geïnstalleerd.'
    }
}
 
function Set-Fsrm {
    # Stel mail notificaties in
    $FromAddress = "FSRM_"+$ENV:COMPUTERNAME+"@domein.nl"
    Set-FsrmSetting -AdminEmailAddress "Systeembeheer@domein.nl" -SmtpServer "smtp.domein.local" -FromEmailAddress $FromAddress
    Add-Logging 'De notificaties zijn ingesteld.'
 
    # Maak een File Screen group aan genaamd Ransomware_Extensions, met maar 1 extensie.
    New-FsrmFileGroup -Name "Ransomware_Extensions" -Description "Deze groep wordt bijgewerkt met bekende crypto extensies." -IncludePattern @("*.dvtestdvtest")
    Add-Logging 'De File Screen groep met de naam Ransomware_Extensions is aangemaakt.'
    # Update online
    Set-FsrmFileGroup -name "Ransomware_Extensions" -IncludePattern @((Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/combined" -UseBasicParsing).content | convertfrom-json | % {$_.filters})
    # Update via de SRP-BHR-0001
    # $Extensions = Get-Content '\\SERVER\FsrmConfig$\Known_Extensions.txt'
    # Set-FsrmFileGroup -name "Ransomware_Extensions" -IncludePattern($Extensions)
    Add-Logging 'De File Screen groep is bijgewerkt met bekende extensies van fsrm.experiant.ca via de SRP-BHR-0001'
 
    # Maak een File Screen template aan
    $MA = New-FsrmAction -Type Email -MailTo "[Admin Email]" -Subject "$ENV:COMPUTERNAME FSRM Ransomware Notification!" -Body "User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server." 
    $EA = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server." -RunLimitInterval 1
    $CA = New-FsrmAction -Type Command -Command "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -CommandParameters "-ExecutionPolicy Bypass -Command &{C:\Scripts\Ransomware\Set-FsrmActions.ps1}" -WorkingDirectory "C:\Scripts\Ransomware" -SecurityLevel LocalSystem -KillTimeOut 5 -RunLimitInterval 0
    [Ciminstance[]]$Notifications = $MA,$EA,$CA
    New-FsrmFileScreenTemplate -Name "Ransomware Template" -Description "Template wordt gebruikt om een File Screen te maken" -IncludeGroup @('Ransomware_Extensions') -Notification $Notifications
    Add-Logging 'De File Screen template genaamd Ransomware Template is aangemaakt.'
    
    # Maak de file screens aan
    [System.Collections.ArrayList]$PreppedVols = @()
    $Vol = Get-Volume | where {$_.DriveType -match 'Fixed' -And $_.FileSystemLabel -notmatch 'System Reserved'}
    foreach ($DL in ($Vol.DriveLetter)) {
        $PreppedDL = $DL+':\'
        $PreppedVols += $PreppedDL
        Add-Logging "De volgende drive is gevonden: $PreppedDL"
    }
    foreach ($PDL in $PreppedVols) {
        New-FsrmFileScreen -Path "$PDL" -Template "Ransomware Template"
        Add-Logging "Er is een File Screen aangemaakt van de template Ransomware Template voor het pad: $PDL"
    }
}
 
function Check-AdModule {
    # Checkt de AD PowerShell module. Zonder deze module is het niet mogelijk om AD accounts te blokkeren.
    if (Get-Module -ListAvailable -Name ActiveDirectory) {
        Add-Logging 'ActiveDirectory PowerShell module is gevonden.'
    }
    else {
        Add-Logging 'ActiveDirectory PowerShell module is niet gevonden.'
        Import-Module -Name ActiveDirectory
        Add-Logging 'De ActiveDirectory PowerShell module is geladen.'
    }
}
 
Set-UpdateTask {
    $Action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-ExecutionPolicy Bypass C:\Scripts\Ransomware\Update-ExtensionsInternally.ps1'
    $Trigger = New-ScheduledTaskTrigger -Daily -At 9am
    Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskPath FSRM -TaskName 'FSRM - Update File Screen Group - Ransomware_Extensions' -Description 'FSRM - Update File Screen Group - Ransomware_Extensions' -User 'System'
}
 
##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Maak een Scripts directory aan, mocht deze nog niet bestaan.
Set-ScriptFolder
# Controleer de OS versie
Get-ServerOS
# Controleer dat de AD PowerShell module beschikbaar is
Check-AdModule
# Controleer dat FSRM geïnstalleerd is
Get-FsrmStatus
# Installeer FSRM wanneer dit niet het geval is. 
if ($Global:FsrmStatus -notlike 'Installed') {Add-FsrmRole}
# Configureer File Server Resource Manager
Set-Fsrm
# Maak een geplande taak om de extensies bij te werken
Set-UpdateTask
# Einde van het script
Add-Logging 'Het einde van het script is bereikt.'
Start-Sleep 10
Add-Logging "Logging is terug te vinden op $LogFile"
