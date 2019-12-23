<#
.Synopsis
   Het script zoekt SID's op bij personeelsnummers. 
.DESCRIPTION
   Het script zoekt SID's op bij personeelsnummers. Er wordt een tabel gemaakt met daarin de voornaam, achternaam,
   personeelsnummer en SID. Daarna wordt een overzicht gemaakt van de personeelsnummers die niet gevonden zijn.
   
   Bij uitvoeren van het script kan een waarschuwing naar voren komen. Accepteer deze, anders loopt het script niet.
   Navigeer via de Windows Verkenner pop-up naar het tekst bestand waar de personeelsnummers in staan.
   Controles  
   De volgende controles worden uitgevoerd:
   - Bestaat het personeelsnummer in AD?
   
   Logging
   Het script logt naar 3 locaties;
   - Een variable, waarvan de inhoud op het laatste automatisch naar het klembord wordt gekopieerd.
   - De console
   - Een logbestand
.EXAMPLE
   .\Get-SID.ps1
   Het script vraagt om via Windows Verkenner te navigeren naar de locatie waar het bestand met de groepsnamen staat.
   De inhoud wordt ingelezen en gevalideerd tegen AD.
   De overzichten worden gegenereerd.
   Als laatste wordt logging gegenereerd. Plak deze in de Topdesk melding.
.AUTHOR
   Dominiek Verham
   dominiek.verham@conoscenza.nl
#>

### Aanmaken van de functies ###
<# Functie om logging inregelen.
Vul de waarde $LogMessage met de tekst die in de logging weergegeven moet worden.
Voeg de tekst toe door de functie aan te roepen: Add-Logging $LogMessage. #>
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$logFile = "Pad\Log\GetSidOfAdUsers_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
 Dit is het logbestand van het script: Get-SID.ps1
 Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Get-SID.ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
    $LogMessage = $null | Out-Null
}

Function Get-FileName($InitialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
  
  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "Plain Text (*.txt) | *.txt"
  $OpenFileDialog.ShowDialog() | Out-Null
  $OpenFileDialog.FileName
  }

########################## Start van het script ##########################
clear-host
# Lees het bestand in met personeelsnummers.
$LogMessage = "Navigeer naar het tekst bestand met personeelsnummers"
Add-Logging $LogMessage
$FilePath = Get-FileName 
$InputUsers = Get-Content $FilePath
# Controle: Bestaat het personeelslid in AD?
$LogMessage = "De personeelsnummers worden nu gecontroleerd in AD"
Add-Logging $LogMessage
[System.Collections.ArrayList]$ValidAdUser = @()
[System.Collections.ArrayList]$InvalidAdUser = @()
foreach ($User in $InputUsers){
    if (Get-ADUser -Filter {Name -eq $User}) {
        $ValidAdUser.Add($User) > $null
        $LogMessage = "Het personeelsnummer $User is gevonden in de AD!"
        Add-Logging $LogMessage
    }
    else {
        $InvalidAdUser.Add($User) > $null
        $LogMessage = "Het personeelsnummer $User is NIET gevonden in de AD!"
        Add-Logging $LogMessage
    }
}
$LogMessage = "Er zijn " + $ValidAdUser.Count + " geldige personeelsnummers gevonden."
Add-Logging $LogMessage
$LogMessage = "Er zijn " + $InvalidAdUser.Count + " ongeldige personeelsnummers gevonden."
Add-Logging $LogMessage
# Overzicht samenstellen
[System.Collections.ArrayList]$Overview = @()
foreach ($ValidUser in $ValidAdUser){
    $Info = Get-ADUser -Identity $ValidUser | select GivenName,Surname,SamAccountName,Sid
    $Overview.Add($info) > $null
}
# Overzicht weergeven
$LogMessage = "Het volgende overzicht geeft de naam, personeelsnummer en SID weer:"
Add-Logging $LogMessage
$LogMessage = $Overview | ft -AutoSize | Out-String
Add-Logging $LogMessage
$LogMessage = "In totaal zijn " + $Overview.Count + " personeelsnummers gevonden."
Add-Logging $LogMessage
$LogMessage = "Het volgende overzicht geeft de personeelsnummers weer die niet gevonden zijn:"
Add-Logging $LogMessage
$LogMessage = $InvalidAdUser | Out-String
Add-Logging $LogMessage
$LogMessage = "In totaal zijn " + $InvalidAdUser.Count + " personeelsnummers niet gevonden."
Add-Logging $LogMessage
# Resultaten opslaan in het klembord van Windows
$LogVariable | clip.exe
$LogMessage = "De resultaten zijn al opgeslagen in het klembord."
Add-Logging $LogMessage
# Opslaan als CSV?
$LogMessage = "Wil je het resultaat als een CSV bestand opslaan? (J/N)"
Add-Logging $LogMessage
$CSVNeeded = Read-Host 
if ($CSVNeeded -eq "J") {
    $LogMessage = "Er wordt een CSV gegenereerd op E:\SysteembeheerScripts\Log."
    Add-Logging $LogMessage
    $CSVPath = "E:\SysteembeheerScripts\Log\GetSidOfAdUsers_Export_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    $Overview | Export-Csv -Path $CSVPath -NoClobber -NoTypeInformation
}
else {
    $LogMessage = "Er wordt geen CSV bestand gegenereerd."
    Add-Logging $LogMessage
}
