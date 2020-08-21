<#
.SYNOPSIS
    Voer het script op een domein controller uit met een account dat domain administrator rechten heeft.
    Het script vraagt de computer objecten op in AD, filtert servers, linux OSen en verouderde objecten eruit. 
    Daarna stuurt het script een Powershell script naar de overgebleven computerobjecten en vraagt daar de hardware hash op.

.DESCRIPTION
    Dit script is onderdeel van twee scripts;
    1: Get-AutopilotHardwareHashes.ps1: Vraagt de hardware hashes van relevante computers op.
    2: Add-AutopilotInfoToIntune.ps1: Upload de gewenste gegevens naar de tenant van de klant.

    Prerequisites
    1: Voer dit script uit op een AD of Management Server met domain administrator rechten.
    2: Het script heeft deze rechten nog omdat het Powershell modules nodig heeft en een script van de PS Gallery.

    Hoe gebruik je het script?
    1: Voer het script Get-AutopilotHardwareHashes.ps1 uit.
    2: Kies de bron om de computerobjecten op te halen. A voor AD, T voor een .TXT bestand.
    2.1: Kies je voor AD, dan vraagt het script om een aantal dagen. Het gaat om een aantal dagen dat een domain computer contact heeft gehad met de DC. 
    Hoe groter het getal, hoe meer objecten meegenomen worden en groter de kans is dat niet gebruikte computer objecten meegenomen worden.
    2.2: Kies je voor het tekst bestand, dan opent een pop-up venster om te navigeren naar het bestand. 
    De opmaak van het bestand is als volgt, geen header en per regel een hostname.
    3: Nu de computerobjecten bekend zijn, wordt via Powershell remoting een scriptblock uitgevoerd op de remote computer.
    Dit scriptblock installeert de benodigde Powershell modules en voert een script van MS uit om de hardware hash op te vragen. 
    De output van dit script is naar een .csv bestand. Daarom halen we in de remote PS sessie de info uit het .CSV bestand terug naar een variabele
    die vervolgens terug gegeven wordt als uitkomst naar de management server. 
    4: Nadat alle remote Powershell sessies afgerond zijn, blijft op de management server het script lopen dat een .CSV bestand maakt met alle 
    hardware hashes. 
    5: Het script verwijst nu naar Add-AutopilotInfoToIntune.ps1 als vervolgstap. Controleer natuurlijk eerst de inhoud van het .CSV bestand.
    
.EXAMPLE
    .\Get-AutopilotHardwareHashes.ps1

.NOTES
    Author: Dominiek Verham
    Mail: dominiek.verham@detron.nl
    Status: In development
#> 
################################## Functies ##################################
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-CimInstance -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "C:\Scripts\Get-AutopilotHardwareHashes_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
Dit is het logbestand van het script: Get-AutopilotHardwareHashes.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Get-AutopilotHardwareHashes.ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
    Clear-Variable LogMessage
}

Function Get-GACredential {
    Add-Logging 'Geef de gebruikersnaam en wachtwoord combinatie in van een global administrator.'
    $Global:GACreds = Get-Credential
}

Function Set-AccountPermissions {
    Set-ExecutionPolicy -ExecutionPolicy Bypass
    Add-Logging 'ExecutionPolicy wordt omgezet naar BYPASS'
    Find-Module -Name Microsoft.Graph.Intune
    Install-Module -Name Microsoft.Graph.Intune
    Import-Module -Name Microsoft.Graph.Intune
    Add-Logging 'De PS commandlets voor Graph zijn geladen.'
    Add-Logging 'Log in met een account dat global admin rechten heeft op de tenant. Accepteer de voorwaarden.'
    Connect-MSGraph -Credential $GACreds
    Write-Host -ForegroundColor Yellow 'Zijn de voorwaarden geaccepteerd? (J/N): ' -NoNewline
    $Confirm = Read-Host
    Add-Logging "Op de controlevraag is het volgende antwoord gegeven: $Confirm"
}

Function Get-FileName($InitialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "Plain Text (*.txt) | *.txt"
  $OpenFileDialog.ShowDialog() | Out-Null
  $OpenFileDialog.FileName
}

Function Get-LocalComputers ($DaysInactive) {
    $Time = (Get-Date).Adddays(-($DaysInactive))
    $Global:Computers = Get-ADComputer -Filter {(OperatingSystem -notlike "*windows*server*") -and (OperatingSystem -notlike "*Linux") -and (OperatingSystem -notlike "*Red*Hat*") -and (OperatingSystem -notlike "*unknown*") -and (LastLogonTimeStamp -gt $time)} -Properties * | select -ExpandProperty Name
    Add-Logging "Er zijn ($Global:Computers).Count computers"
}

Function Get-RemoteHashInfo {
    Add-Logging 'We gaan de hashes van de remote systemen opvragen.'
    [System.Collections.ArrayList]$RemoteHashes = @()
    $Global:CsvFile = "C:\Scripts\RemoteHashes_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    $RemoteHashes = foreach ($PC in $Global:Computers){
        Invoke-Command -ComputerName $PC -Authentication Kerberos -ScriptBlock {
            $ProgressPreference = 'silentlyContinue'
            # Vraag het serienummer van de BIOS op.
            $Serial = Get-CimInstance -ClassName Win32_BIOS | Select -ExpandProperty Serialnumber

            # Voeg de benodigde modules toe.
            Install-Module AzureAD,WindowsAutoPilotIntune,Microsoft.Graph.Intune -Force
            # Geen logging ivm ps remoting

            # Importeer de benodigde modules.
            Import-Module -Name AzureAD,WindowsAutoPilotIntune,Microsoft.Graph.Intune
            # Geen logging ivm ps remoting
            Install-Script -Name Get-WindowsAutoPilotInfo -Force
            # Geen logging ivm ps remoting

            # Verbindt met Microsoft Graph
            Try {
                Connect-MSGraph -Credential $Using:GACreds
                # Geen logging ivm ps remoting
            }
            Catch {
                # Geen logging ivm ps remoting
            Break }

            # Controleer de script folder
            $Result = Test-Path -Path 'C:\Scripts'
                if (!$Result) {
                Set-Location -Path 'C:\'
                New-Item -ItemType Directory -Path 'C:\' -Name 'Scripts' | Out-Null
               # Geen logging ivm ps remoting
            }
            else {
                # Geen logging ivm ps remoting
            }

            # Het autopilot info script heeft een output parameter voor een CSV. De data wordt daarin opgeslagen.
            Write-Host "Creating Autopilot CSV File" -ForegroundColor Cyan
            Try {
                Get-WindowsAutoPilotInfo.ps1 -OutputFile "C:\Scripts\AutoPilotInfo.csv"
                # Geen logging ivm ps remoting
            }
            Catch {
                New-Item -ItemType File -Path 'C:\Scripts' -Name 'ErrorGeneratingHash.txt'
                Break
            }

            # Lees de inhoud van het CSV bestand in
            $CSVInfo = Import-Csv -Path 'C:\Scripts\AutoPilotInfo.csv'

            # Geef de hash terug naar de de management server.
            Return $CSVInfo
        }
    }
    $RemoteHashes | Export-CSV -Path $Global:CsvFile -NoClobber -NoTypeInformation
    Add-Logging "Er is een export van de hashes gemaakt op $Global:CsvFile"
}

################################## Begin van het script ##################################
Clear-Host
Add-Logging 'Dit script vraagt hardware hashes op van remote computers en upload deze naar de tenant in Intune.
Het script controleert de rechten voor het account om de gegevens op te vragen en op te slaan in Intune. Gebruik hiervoor
een account met Global Admin rechten in de tenant.'
Add-Logging 'Voer dit script uit door een account met domain administrator rechten op de werkplek.'
# Vraag de global admin credentials.
Get-GACredential
# Maak verbinding met Microsoft Graph en controleer de rechten.
Set-AccountPermissions
# Wil je de computerobjecten uit een .txt bestand inlezen of opvragen vanuit AD? 
Write-Host -ForegroundColor Green 'Wil je de computers ophalen uit AD of uit een .txt bestand? (A/T): ' -NoNewline
$SourceOfComputers = Read-Host
switch ($SourceOfComputers) {
    A{
        Write-Host -ForegroundColor Green 'In hoeveel dagen moet het computerobject contact gehad hebben met AD? (Default: 30): ' -NoNewline 
        [INT]$Days = Read-Host
        Add-Logging "De computerobjecten worden uit Active Directory opgevraagd."
        Add-Logging "Alleen de objecten die in de laatste $Days dagen contact hebben gehad met AD worden opgehaald."
        # Vraag de computerobjecten op. Geef het aantal dagen op wanneer de computer voor het laatst met AD gesproken heeft.
        Get-LocalComputer $Days
    }
    T{
        Add-Logging 'De computerobjecten worden uit een .txt bestand opgehaald.'
        # Er komt een pop-up om te navigeren naar een .txt bestand met de hostnames.
        $FilePath = Get-FileName
        $InputComputers = Get-Content $FilePath
        $ComputersFound = $InputComputers.Count
        Add-Logging "Er zijn $ComputersFound computers in het tekst bestand gevonden."
    }
    default{
        Add-Logging "De keuze $SourceOfComputers is geen geldige keuze. Het script stopt nu."
        break
    }
}
# Vraag de hashes op van de bestaande computer objecten
Get-RemoteHashInfo
# Vervolgstappen melden
Add-Logging 'Bewerk de het .CSV zodat het de juiste waardes bevat en upload deze naar de tenant via Add-AutoPilotInfoToIntune.ps1'
Add-Logging 'Het script is afgerond.'
