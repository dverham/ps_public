<#
.Synopsis
   Het script voegt gebruikersobjecten toe aan Active Directory groepen. 
 
.DESCRIPTION
   Het script voegt gebruikersobjecten toe aan AD groepen. In deze hoedanigheid kan het script gebruikt worden voor;
   - Wijzigingen voor lidmaatschappen.
   - Wijzigingen voor Exchange gedeelde kamers.
   - Wijzigingen voor Exchange gedeelde mailboxen.
   
   Bij uitvoeren van het script kan een waarschuwing naar voren komen. Accepteer deze, anders loopt het script niet.
   Voer de AD groep in.
   Kies de manier om personeelsnummers aan te leveren;
   - Via handmatig typen
   - Via bulk plakken vanuit Topdesk
       - Kopieer de tekst regel vanuit Topdesk
   - Via een CSV bestand
       - Navigeer via het pop-up venster naar het .txt bestand waar de personeelsnummers in zitten.
 
   Controles  
   De volgende controles worden uitgevoerd:
   - Bestaat de naam van de groep in AD? 
   - Bestaat het personeelsnummer in AD?
   - Welke personeelsnummers zijn al lid van de groep?
 
   Logging
   Het script logt naar 3 locaties;
   - Een variable, waarvan de inhoud op het laatste automatisch naar het klembord wordt gekopieerd.
   - De console
   - Een logbestand
 
.EXAMPLE
   .\AddAdUsersToAdGroup.ps1
 
   Via handmatig typen (H)
   Kies de optie H. 
   Type het personeelsnummer handmatig in. 
   Kies Ja of Nee om nog een personeelsnummer in te typen.
   Controleer de output en bevestig de keuze om de personeelsnummers te wijzigen in de groep.
   Plak de logging, die al in het klembord zit, in Topdesk.
 
   Via Topdesk (T)
   Topdesk heeft een melding waarin de personeelsnummers vermeldt staan. De opmaak is '[personeelsnummer];[spatie]'
   Kies de optie T.
   Plak de tekstregel vanuit Topdesk.
   Controleer de output en bevestig de keuze om de personeelsnummers te wijzigen in de groep.
   Plak de logging, die al in het klembord zit, in Topdesk.
 
   Via Bestand (B)
   Er dient een .txt bestand te zijn met een kolom waar de personeelsnummers in staan. Er mag geen koptekst zijn.
   Kies de optie B.
   Navigeer via de Windows Verkenner naar het .txt bestand.
   Controleer de output en bevestig de keuze om de personeelsnummers te wijzigen in de groep.
   Plak de logging, die al in het klembord zit, in Topdesk.
 
.AUTHOR
   Dominiek Verham
   dominiek.verham@conoscenza.nl
#>
 
##################### Functies definiëren ##################
# Functie om te navigeren naar een bestand.
Function Get-FileName($InitialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
 
  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "Plain Text (*.txt) | *.txt"
  $OpenFileDialog.ShowDialog() | Out-Null
  $OpenFileDialog.FileName
}
 
<# Functie om logging inregelen.
- Vul de waarde $LogMessage met de tekst die in de logging weergegeven moet worden.
- Voeg de tekst toe door de functie aan te roepen: Add-Logging $LogMessage. #>
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$logFile = "PAD\Log\AddUsersToAdGroups-"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "
************************************************************************************************
Het volgende script is gestart: Pad\adScripts\AddUsersToAdGroup.ps1
Dit is het logbestand van het script: $LogFile
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************
"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("
************************************************************************************************
Het volgende script is gestart: Pad\adScripts\AddUsersToAdGroup.ps1
Dit is het logbestand van het script: $LogFile
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************
")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
}
 
function Add-Manually(){
    [System.Collections.ArrayList]$UncheckedInputUsers = @()
    [System.Collections.ArrayList]$ValidAdUsers = @()
    [System.Collections.ArrayList]$InvalidAdUsers = @()
    $Repeat = "J"
    Do{
        Write-Host -ForegroundColor Green "Welk personeelsnummer wil je toevoegen aan de groep? " -NoNewline
        $InputUser = Read-Host
        $UncheckedInputUsers.Add($InputUser) > $null
        Write-Host -ForegroundColor Green "Wil je nog een personeelsnummer toevoegen? (J/N) " -NoNewline
        $Repeat = Read-Host
        }
    while ($Repeat -eq "J")
    $LogMessage = "Er zijn " + $UncheckedInputUsers.count + " personeelsnummers ingevoerd."
    Add-Logging $LogMessage
 
    # Controle: Bestaan de personeelsnummers in AD?
    Foreach ($UserToCheck in $UncheckedInputUsers) {
    if (Get-ADUser -Filter {SamAccountName -eq $UserToCheck}) { 
        $ValidAdUsers.Add($UserToCheck) > $null
        $LogMessage = "Het personeelsnummer $UserToCheck is gevonden in Active Directory!"
        Add-Logging $LogMessage
        }
    else {
        $InvalidAdUsers.Add($UserToCheck) > $null
        $LogMessage = "Het personeelsnummer $UserToCheck is niet gevonden in Active Directory!"
        Add-Logging $LogMessage
        }
    }
 
    # Comparison of ArrayLists.
    $OnlyInValidInputUsers = $ValidAdUsers | where {$CurrentMembers -notcontains $_}
    $OnlyInCurrentMembers = $CurrentMembers | where {$ValidAdUsers -notcontains $_}
    $OnlyInBothArrays = $ValidAdUsers | where {$CurrentMembers -contains $_}
 
    # Controle dat er personeelsnummers zijn om toe te voegen.
    # Personeelsnummer toevoegen aan AD de groep.
    # Geeft als laatste de resultaten weer.
    $AddUsersToGroup = "N" 
    if ($OnlyInValidInputUsers -gt 0) {
        Write-Host -ForegroundColor Green "Wil je de volgende personeelsnummers toevoegen aan de groep $InputGroup ? (J/N)"
        Write-Host $OnlyInValidInputUsers
        $AddUsersToGroup = Read-Host
        if ($AddUsersToGroup -eq "J") {
            ForEach ($ValidNewUser in $OnlyInValidInputUsers){
                Add-ADGroupMember -Identity $InputGroup -Members $ValidNewUser -Confirm:$false
                }
        }
        Elseif ($AddUsersToGroup -eq "N") {
            $LogMessage = "U heeft $AddUsersToGroup gekozen. Het script wordt beeindigd."
            Add-Logging $LogMessage
            break
        }
        Else {
            $LogMessage = "De keuze $AddUsersToGroup is geen geldige keuze. Voer het script opnieuw uit."
            Add-Logging $LogMessage
            break
        }
    }
    Else {
        $LogMessage = "Er zijn geen personeelsnummers om toe te voegen."
        Add-Logging $LogMessage
    }
 
    # Logging afronden - De volgende personeelsnummers zijn toegevoegd.
    $LogMessage = "Resultaat voor de groep $InputGroup :"
    Add-Logging $LogMessage
    $LogMessage = "De volgende personeelsnummers zijn toegevoegd:" + $OnlyInValidInputUsers
    Add-Logging $LogMessage
    $LogMessage = "In totaal zijn " + $OnlyInValidInputUsers.Count + " toegevoegd aan de groep."
    Add-Logging $LogMessage
    # Logging afronden - De volgende personeelsnummers waren al in de groep.
    $LogMessage = "De volgende personeelsnummers waren al lid van de groep en zijn overgeslagen: " + $OnlyInBothArrays
    Add-Logging $LogMessage
    $LogMessage = "In totaal zijn " + $OnlyInBothArrays.Count + " overgeslagen omdat deze al lid waren van de groep."
    Add-Logging $LogMessage
    # Logging afronden - De volgende personeelsnummers zijn niet bekend in AD.
    $LogMessage = "De volgende personeelsnummers zijn niet gevonden in Active Directory: " + $InvalidAdUsers
    Add-Logging $LogMessage
    $LogMessage = "In totaal zijn " + $InvalidAdUsers.Count + " overgeslagen omdat deze niet gevonden zijn in Active Directory."
    Add-Logging $LogMessage
 
    # Logging naar klembord.
    Write-Host -ForegroundColor Green "De logging is naar het klembord gekopieerd. Plak deze in Topdesk om de melding bij te werken."
    $LogVariable | clip.exe
}
 
function Add-File() {
# Er is een .txt bestand nodig. Deze heeft een kolom zonder koptekst.
Write-Host `n
Write-Host -ForegroundColor Yellow "Let op: Deze functie vraagt om een tekst (.txt) bestand met personeelsnummers.
Gebruik geen koptekst in het tekst bestand!
`n"
 
# Vraag naar de locatie van het tekst bestand.
$FilePath = Get-FileName 
$InputUsers = Get-Content $FilePath
 
# Controle: Bestaat de gebruiker in AD?
[System.Collections.ArrayList]$ValidAdUsers = @()
[System.Collections.ArrayList]$InvalidAdUsers = @()
foreach ($User in $InputUsers){
    if (Get-ADUser -Filter {SamAccountName -eq $User}) {
        $ValidAdUsers.Add($User) > $null
        $LogMessage = "De medewerker met personeelsnummer $User is gevonden in de AD!"
        Add-Logging $LogMessage
    }
    else {
        $InvalidAdUsers.Add($User) > $null
        $LogMessage = "De medewerker met personeelsnummer $User is NIET gevonden in de AD!"
        Add-Logging $LogMessage
    }
}
 
# Comparison of ArrayLists.
$OnlyInValidAdUsers = $ValidAdUsers | where {$CurrentMembers -notcontains $_}
$OnlyInCurrentMembers = $CurrentMembers | where {$ValidAdUsers -notcontains $_}
$OnlyInBothArrays = $ValidAdUsers | where {$CurrentMembers -contains $_}
 
# Lees gebruikers in en voeg deze toe aan de groep. 
$MarkForImport = "N"
if($OnlyInValidAdUsers -gt 0){
    $LogMessage = "De volgende personeelsnummers worden toegevoegd aan de groep: $OnlyInValidAdUsers"
    Add-Logging $LogMessage
    Write-Host -ForegroundColor Green "Wil je de genoemde gebruikers toevoegen aan de groep? (J/N) " -NoNewline
    $MarkForImport = Read-Host 
    if ($MarkForImport -eq "J"){
        foreach ($IdToImport in $OnlyInValidAdUsers){
        Add-ADGroupMember $InputGroup -Members $IdToImport -Confirm:$false
        $LogMessage = "Personeelsnummer $IdToImport wordt toegevoegd aan de AD groep $InputGroup"
        Add-Logging $LogMessage
        }
    }
        elseif ($MarkForImport -eq "N"){
            $LogMessage = "U heeft $MarkForImport gekozen. Het script eindigt nu."
            Add-Logging $LogMessage
            break
        }
    else {
        $LogMessage = "$MarkForImport is geen geldige keuze! Haal een koffie en voer het script opnieuw uit."
        Add-Logging $LogMessage
        break
        }
    }
Else {
    $LogMessage = "Er zijn geen personeelsnummers om toe te voegen."
    Add-Logging $LogMessage
}
 
# Logging afronden - De volgende personeelsnummers zijn toegevoegd.
$LogMessage = "Resultaat voor de groep $InputGroup :"
Add-Logging $LogMessage
$LogMessage = "De volgende personeelsnummers zijn toegevoegd:" + $OnlyInValidAdUsers
Add-Logging $LogMessage
$LogMessage = "In totaal zijn " + $OnlyInValidAdUsers.Count + " toegevoegd aan de groep."
Add-Logging $LogMessage
# Logging afronden - De volgende personeelsnummers waren al in de groep.
$LogMessage = "De volgende personeelsnummers waren al lid van de groep en zijn overgeslagen: " + $OnlyInBothArrays
Add-Logging $LogMessage
$LogMessage = "In totaal zijn " + $OnlyInBothArrays.Count + " overgeslagen omdat deze al lid waren van de groep."
Add-Logging $LogMessage
# Logging afronden - De volgende personeelsnummers zijn niet bekend in AD.
$LogMessage = "De volgende personeelsnummers zijn niet gevonden in Active Directory: " + $InvalidAdUsers
Add-Logging $LogMessage
$LogMessage = "In totaal zijn " + $InvalidAdUsers.Count + " overgeslagen omdat deze niet gevonden zijn in Active Directory."
Add-Logging $LogMessage
 
$LogVariable | clip.exe
Write-Host -ForegroundColor Green "Het script is afgerond. De resultaten zijn in het Clipboard opgeslagen."
}
 
function Add-BulkText {
    $UncheckedInputUsers = $null
    [System.Collections.ArrayList]$ValidAdUsers = @()
    [System.Collections.ArrayList]$InvalidAdUsers = @()
    Write-Host -ForegroundColor Green "Welke personeelsnummers wil je toevoegen aan de groep? "
    Write-Host -ForegroundColor Green "Let op: Voer de personeelsnumers in op de volgende manier: 123456; 123456; 123456"
    $UncheckedInputUsers = Read-Host
    $SplitUncheckedInputUsers = $UncheckedInputUsers -split "; "
    $LogMessage = "Er zijn " + $SplitUncheckedInputUsers.count + " personeelsnummers ingevoerd."
    Add-Logging $LogMessage
 
    # Controle: Bestaan de personeelsnummers in AD?
    Foreach ($UserToCheck in $SplitUncheckedInputUsers) {
    if (Get-ADUser -Filter {SamAccountName -eq $UserToCheck}) { 
        $ValidAdUsers.Add($UserToCheck) > $null
        $LogMessage = "Het personeelsnummer $UserToCheck is gevonden in Active Directory!"
        Add-Logging $LogMessage
        }
    else {
        $InvalidAdUsers.Add($UserToCheck) > $null
        $LogMessage = "Het personeelsnummer $UserToCheck is niet gevonden in Active Directory!"
        Add-Logging $LogMessage
        }
    }
 
    # Comparison of ArrayLists.
    $OnlyInValidInputUsers = $ValidAdUsers | where {$CurrentMembers -notcontains $_}
    $OnlyInCurrentMembers = $CurrentMembers | where {$ValidAdUsers -notcontains $_}
    $OnlyInBothArrays = $ValidAdUsers | where {$CurrentMembers -contains $_}
 
    # Controle dat er personeelsnummers zijn om toe te voegen.
    # Personeelsnummer toevoegen aan AD de groep.
    # Geeft als laatste de resultaten weer.
    $AddUsersToGroup = "N" 
    if ($OnlyInValidInputUsers -gt 0) {
        Write-Host -ForegroundColor Green "Wil je de volgende personeelsnummers toevoegen aan de groep $InputGroup ? (J/N)"
        Write-Host $OnlyInValidInputUsers
        $AddUsersToGroup = Read-Host
        if ($AddUsersToGroup -eq "J") {
            ForEach ($ValidNewUser in $OnlyInValidInputUsers){
                Add-ADGroupMember -Identity $InputGroup -Members $ValidNewUser -Confirm:$false
                }
        }
        Elseif ($AddUsersToGroup -eq "N") {
            $LogMessage = "U heeft $AddUsersToGroup gekozen. Het script wordt beeindigd."
            Add-Logging $LogMessage
            break
        }
        Else {
            $LogMessage = "De keuze $AddUsersToGroup is geen geldige keuze. Voer het script opnieuw uit."
            Add-Logging $LogMessage
            break
        }
    }
    Else {
        $LogMessage = "Er zijn geen personeelsnummers om toe te voegen."
        Add-Logging $LogMessage
    }
 
    # Logging afronden - De volgende personeelsnummers zijn toegevoegd.
    $LogMessage = "Resultaat voor de groep $InputGroup :"
    Add-Logging $LogMessage
    $LogMessage = "De volgende personeelsnummers zijn toegevoegd:" + $OnlyInValidInputUsers
    Add-Logging $LogMessage
    $LogMessage = "In totaal zijn " + $OnlyInValidInputUsers.Count + " toegevoegd aan de groep."
    Add-Logging $LogMessage
    # Logging afronden - De volgende personeelsnummers waren al in de groep.
    $LogMessage = "De volgende personeelsnummers waren al lid van de groep en zijn overgeslagen: " + $OnlyInBothArrays
    Add-Logging $LogMessage
    $LogMessage = "In totaal zijn " + $OnlyInBothArrays.Count + " overgeslagen omdat deze al lid waren van de groep."
    Add-Logging $LogMessage
    # Logging afronden - De volgende personeelsnummers zijn niet bekend in AD.
    $LogMessage = "De volgende personeelsnummers zijn niet gevonden in Active Directory: " + $InvalidAdUsers
    Add-Logging $LogMessage
    $LogMessage = "In totaal zijn " + $InvalidAdUsers.Count + " overgeslagen omdat deze niet gevonden zijn in Active Directory."
    Add-Logging $LogMessage
 
    # Logging naar klembord.
    Write-Host -ForegroundColor Green "De logging is naar het klembord gekopieerd. Plak deze in Topdesk om de melding bij te werken."
    $LogVariable | clip.exe   
}
 
### Start van het algemene deel van het script. Vraag de groep op en controleer dat deze in AD bestaat.
Clear-Host
Write-Host `n
Write-Host -ForegroundColor Green "Het script wordt uitgevoerd door $Who" # Registreer de admin.
Write-Host -ForegroundColor Green "Voer de Active Directory groep in: " -NoNewline
$InputGroup = Read-Host
$CheckGroup = Get-ADGroup -Filter {samAccountName -eq "$InputGroup"} | select -ExpandProperty name
if (Get-ADGroup -Filter {SamAccountName -eq $InputGroup}) {
    Write-Host `n
    $CurrentMembers = Get-ADGroupMember $InputGroup | select -ExpandProperty name
    $LogMessage = "De groep $InputGroup is gevonden in Active Directory."
    Add-Logging $LogMessage
    }
Else {
    $LogMessage = "De groep $InputGroup is niet gevonden in Active Directory"
    Add-Logging $LogMessage
    Break
}
 
# Kies tussen een handmatige invoer van personeelsnummers, via bulk plakken, of via een tekst bestand.
Write-Host -ForegroundColor Green "Wil je Handmatig personeelsnummers ingeven, plakken vanuit Topdesk of via een tekst Bestand? (H/T/B) " -NoNewline
$InputChoice = Read-Host
if ($InputChoice -eq "H"){
        $LogMessage = "Er is gekozen om handmatig personeelsnummers in te geven."
        Add-Logging $LogMessage
        Add-Manually
    }
    Elseif ($InputChoice -eq "B") {
        $LogMessage = "Er is gekozen om personeelsnummers via een tekst bestand in te geven."
        Add-Logging $LogMessage
        Add-File
    }
    Elseif ($InputChoice -eq "T") {
        $LogMessage = "Er is gekozen om personeelsnummers in te geven via Topdesk. De personeelsnummers worden gesplit door een ;spatie."
        Add-Logging $LogMessage
        Add-BulkText
    }
Else {
    $LogMessage = "Er is geen geldige waarde ingevoerd. Het script wordt beëindigd zonder enige aanpassing."
    Add-Logging $LogMessage
}
