<# Gebruik deze functie om logging te genereren.
De functie logt naar een bestand en naar een variabele. 
Hoe werkt de functie?
Vul de waarde $LogMessage met de tekst die in de logging weergegeven moet worden.
Voeg de tekst toe door de functie aan te roepen: Add-Logging $LogMessage. 
Pas de volgende zaken aan:
[Pad\Naam]   : Geef het pad naar het logbestand op en geef het bestand een naam. De naam wordt aangevuld met datum tijd en de .log extensie.
[bronscript] : Geef het pad en de naam op van het script dat uitgevoerd wordt.#>
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$logFile = "[Pad\Naam]-"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
 Dit is het logbestand van het script: [bronscript].ps1
 Het script wordt uitgevoerd door $who op $StartDateTime
 ************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: [bronscript].ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
    $LogMessage = $null > $null
}
