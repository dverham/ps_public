<#
.SYNOPSIS
    Gebruik dit script om mailbox moves te beginnen, afronden, verwijderen of statistieken op te vragen.
.DESCRIPTION
    Voordat het script gebruikt kan worden, dient er een CSV aanwezig te zijn. De inhoud van de CSV moet als volgt uit zien;
    - Geen headers
    - Naam;Database

    Voorbeeld;
    Gebruiker.Afdeling;EXC01-DB1
    Contract Administratie;EXC01-DB5

    Zorg dat de CSV in de juiste map staat en de juiste naam heeft.

    Pas de servernaam van de Exchange server aan om een PS verbinding op te zetten.
    
.EXAMPLE
    .\Livegang.ps1
.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@detron.nl
    Doel: Migratie van mailboxen, zonder batches
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################
Function Connect-ToLocalExchange {
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://server/PowerShell/ -Authentication Kerberos
Import-PSSession $Session
}

Function Run-Live {
    $Live = Import-Csv -Path 'C:\Temp\Livegang.csv' -Delimiter ';' -Header DisplayName,TargetDB
    foreach ($User in $Live) {
        New-MoveRequest -Identity $User.DisplayName -TargetDatabase $User.TargetDB -SuspendWhenReadyToComplete
    }
}

Function Resume-Live{
    $Live = Import-Csv -Path 'C:\Temp\Livegang.csv' -Delimiter ';' -Header DisplayName,TargetDB
    foreach ($User in $Live) {
        Resume-MoveRequest -Identity $User.DisplayName
    }
}

Function Delete-Live {
    $Live = Import-Csv -Path 'C:\Temp\Livegang.csv' -Delimiter ';' -Header DisplayName,TargetDB
    foreach ($User in $Live) {
        Remove-MoveRequest -Identity $User.DisplayName -Force
    }
}

Function Get-LiveStatistics {
    $Live = Import-Csv -Path 'C:\Temp\Livegang.csv' -Delimiter ';' -Header DisplayName,TargetDB
    foreach ($User in $Live) {
        Get-MoveRequest -Identity $User.DisplayName | Get-MoveRequestStatistics | select DisplayName,StatusDetail,TotalMailboxSize,PercentComplete
    }
}


######## Script
# Verbindt met Exchange On Prem
Connect-ToLocalExchange
# Livegang aanzetten, completeren of verwijderen?
Write-Host -ForegroundColor Red 'LET OP; DIT SCRIPT ALLEEN GEBRUIKEN BIJ LIVEGANG!'
Write-Host -ForegroundColor Red 'Wil je de LIVEGANG Beginnen, Afronden, Verwijderen of Statistieken opvragen? (B/A/V/S)?: ' -NoNewline
$Choice = Read-Host
switch ($Choice) {
    B{
        Run-Live
        break
    }
    A{
        Resume-Live
        break
    }
    V{
        Delete-Live
        break
    }
    S{
        Get-LiveStatistics
    }
    default{
    Write-Host -ForegroundColor Red 'Er is geen geldige keuze gemaakt.'
    break
    }
}
