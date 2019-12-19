<#
.SYNOPSIS
   Gebruik dit script om informatie over een of meerdere e-mail berichten op te halen.

.DESCRIPTION
   Dit script geeft de optie om een verbinding te maken met een interne Exchange omgeving.
   Geef aan vanuit welk mail adres het bericht, of de berichten gestuurd zijn. 
   Vul de start datum en tijdstip is, gevolgd door de eind datum en tijdstip. 

   Het script voert de volgende stappen uit:
   1: De aanwezige Exchange servers worden geinventariseerd.
   2: Vraag alle mails op die gestuurd zijn vanuit het eerder opgegeven mail adres tussen een bepaalde tijdsperiode.
   3: Vraag de MessageID's op van de gevonden e-mail berichten en ontdubbel deze.
   4: Vraag per Exchange server de gevonden MessageID's op. Er zal meer informatie beschikbaar zijn wanneer een Exchange server het bericht gestuurd heeft.
   5: Filter de waardes op inhoud 'ClientType'. Zo blijven de entries over waarbij zichtbaar is welke client het bericht gestuurd heeft.
   6: Output de gegevens op beeld aan de hand van bepaalde properties en sorteer deze (descending).
   7: Exporteer de gegevens naar .CSV bestand. 
   
   Het script is afhankelijk van een actieve PowerShell sessie met Exchange.

   Logging is voorzien door middel van een export naar .CSV bestand. Pas de locatie naar wens aan in de laatste regel. 
    
.EXAMPLE
   .\Get-MailSource.ps1

.NOTES
   Author: Dominiek Verham
   Mail: dominiek.verham@conoscenza.nl
#>

############################################
#  Aanmaken van de functies
############################################
# Log functie
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "Pad\log\Get-MailSource_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
Dit is het logbestand van het script: Get-MailSource.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Get-MailSource.ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1] > $null
    Clear-Variable LogMessage
}

# Verbinding maken met Exchange
Function Connect-ToExchange{
    Write-Host -ForegroundColor Green 'Wil je een PowerShell sessie met Exchange opzetten? (J/N): ' -NoNewline
    $Exchange = Read-Host
    switch ($Exchange){
        J {
            Add-Logging 'Er wordt een PowerShell sessie met Exchange opgezet.'
            try{
                $Credentials = Get-Credential
                $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionURI http://server/PowerShell/ -Authentication Kerberos -Credential $Credentials -ErrorAction Stop
                Import-PSSession $Session
            }
            Catch [System.Management.Automation.Remoting.PSRemotingTransportException]{
                $SomethingWentWrong = $Error[0].exception
                Write-Host -ForeGroundColor Red 'Er is iets mis gegaan. De foutmelding is als volgt: '
                Write-Host -ForeGroundColor Red "$SomethingWentWrong"
                Add-Logging 'Er is iets mis gegaan. De foutmelding is als volgt: '
                Add-Logging "$SomethingWentWrong"
            }
        }
        N {
            Add-Logging 'Er wordt geen sessie met Exchange opgezet. Let op; zonder sessie met Exchange werkt het script niet goed.'
        }
        default {
            Add-Logging "De keuze $exchange is geen geldige keuze."
            Continue
        }
    }
}

############################################
#  Begin van het script
############################################
#  Opzetten van een PowerShell sessie met Exchange
Connect-ToExchange
#  Opvragen van de gegevens
Write-Host -ForegroundColor Green 'Vanuit welk mail adres is de mail verstuurt?: ' -NoNewline
$Source = Read-Host
Write-Host -ForegroundColor Green 'In welk tijdsbestek zijn de mail(s) gestuurd?
Geef de begin datum en tijdstip op in de voor van MM//DD/JJJJ UU:MM:SS: ' -NoNewline
$Start = Read-Host
Write-Host -ForegroundColor Green 'Geef de laatste datum en tijdstip op in de vorm van MM/DD/JJJJ UU:MM:SS: ' -NoNewline
$End = Read-Host
$EventID = 'RECEIVE'
$Attributes = "Timestamp,EventID,Source,Sender,Recipients,MessageSubject,MessageID,SourceContext"
# Exchange servers opvragen
$ExchangeServers = Get-ExchangeServer | select -ExpandProperty Name
# Alle berichten opvragen met alle properties
$Messages = Get-MessageTrackingLog -Sender $Source -EventId $EventID -Start $Start -End $End
# MessageIDs opvragen en direct ontdubbelen
$MessageIds = $Messages.MessageID | select -Unique
# Per Exchange server checken wat de SourceContext is
[System.Collections.ArrayList]$SourceContext = @()
foreach($ES in $ExchangeServers){
    foreach ($MID in $MessageIds){
        $SCEntry = Get-MessageTrackingLog -Server $ES -MessageId $MID 
        $SourceContext += $SCEntry
        clear-variable SCEntry
    }
}
# Arraylist opschonen zodat alleen objecten lid zijn die ClientType ingevuld hebben
[System.Collections.ArrayList]$ClientType = @()
Foreach ($Entry in $SourceContext){
    if ($Entry.SourceContext -like '*ClientType*'){
                $ClientType += $Entry
        Clear-Variable Entry
    }
    $ClientType | select Timestamp,EventID,Source,Sender,Recipients,MessageSubject,MessageID,RecipientCount,SourceContext | sort Timestamp -Descending
}
# Exporteer de resultaten naar .CSV
$ClientType | Sort Timestap -Descending | Export-Csv PAD\Export.CSV -NoTypeInformation -NoClobber
