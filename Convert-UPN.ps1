<#
.SYNOPSIS
    Het script vraagt de eigenschappen van gebruikersaccount van een bepaalde OU op. Daarna wordt de UPN aangepast naar het bekende mail adres.

.DESCRIPTION
    Het script stelt algehele monitoring in. Daarna vraagt het script om een OU in te geven waar de gebruikersobjecten in zitten. 
    Daarna worden de gebruikersobjecten opgevraagd vanuit AD en worden de properties ingelezen. 
    De UPN wordt vergeleken met het mail property. Wanneer de velden gelijk zijn, zal het script naar de volgende gebruiker gaan.
    Wanneer de velden verschillen, zal de UPN aangepast worden met de waarde van het mail property.
    
.EXAMPLE
    .\Convert-UPN.ps1
.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@detron.nl
    Doel: Past de UPN aan naar het bekende mail adres.
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################
# Functie om logging inregelen.
# Voeg de tekst toe door de functie aan te roepen: Add-Logging 'bericht' of in geval van variabele Add-Logging "$Var".
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "C:\Scripts\log\Convert-UPN_"+$ENV:COMPUTERNAME+"_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Definieer de header
$Header = "************************************************************************************************
Dit is het logbestand van het script: Convert-UPN.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
Het script wordt uitgevoerd op $ENV:COMPUTERNAME
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

Function Set-ScriptFolder {
    $ScriptsFolder = Test-Path 'C:\Scripts'
    if ($ScriptsFolder -notlike 'True') {
        New-Item -ItemType Directory -Path 'C:\Scripts'
        Add-Logging 'C:\Scripts folder is aangemaakt.'
    }
    else {
        Add-Logging 'C:\Scripts folder bestaat al.'
    }
    $LogFolder = Test-Path 'C:\Scripts\Log'
    if ($LogFolder -notlike 'True') {
        New-Item -ItemType directory -Path 'C:\Scripts\Log'
        Add-Logging 'C:\Scripts\Log folder is aangemaakt.'
    }
    else {
        Add-Logging 'C:\Scripts\Log folder bestaat al.'
    }
}

Function Update-Users {
    Write-Host -ForegroundColor Green "In welke OU staan de gebruikers die je wil aanpassen? " -NoNewline
    $OU = Read-Host
    Add-Logging "De volgende OU is opgegeven: $OU"
    $AllUsers = get-aduser -Filter * -SearchBase $OU
    $Count = $allUsers.Count
    Add-Logging "Er zijn in totaal $Count gebruikersobjecten gevonden in de OU." 
    foreach ($User in $AllUsers) {
        $OriginalUser = get-aduser -Identity $User -Properties userPrincipalName,mail,displayName | Select-Object userPrincipalName,mail,displayName 
        Add-Logging "Gebruikersobject $($OriginalUser.displayName) wordt gecontroleerd."
        Add-Logging "De bestaande UPN is: $($OriginalUser.userPrincipalName) en het mail adres is: $($OriginalUser.mail)"
        if ($($OriginalUser.userPrincipalName) -notlike $($OriginalUser.mail)) {
            Add-Logging "De UPN is niet gelijk aan het mail adres, dit passen we aan..."
            set-AdUser -UserPrincipalName $($OriginalUser.mail) -Identity $User
        }
        else {Add-Logging "De UPN is gelijk aan het mail adres. Er worden geen aanpassingen gedaan."}
    }
}

##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Maak een script folder aan als deze nog niet mocht bestaan
Set-ScriptFolder
# Laadt de ActiveDirectory Powershell module
Import-Module ActiveDirectory
# Update de gebruikers
Update-Users
