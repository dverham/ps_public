<#
.SYNOPSIS
    Het script blokkeert de gebruiker op de admin share waar misbruik herkent is door FSRM.

.DESCRIPTION
    Het script triggert door een File Screen en controleert het event log op entries van FSRM.
    De entry wordt ingelezen via een replacementstring array waar datapunten direct in opgeslagen zijn.
    Troubleshooting tip: om dit array uit te lezen : $Events.ReplacementStrings

    Dit script is onderdeel van vier componenten:
    1: Add-FsrmServer.ps1 | Dit script stelt een nieuwe server in om FSRM te gebruiken.
    2: Set-FsrmActions.ps1 | Dit script voert de acties uit nadat Ransomware gedetecteerd is.
    3: Update-ExtensionsLocally.ps1 | Dit script werkt de extensies bij van de share op het netwerk.
    4: Update-Extensions.ps1 | Dit script haalt de extensies van het internet op en slaat deze lokaal op de management server op.
    Subinacl.exe op 2012 en hoger niet aan de gang gekregen / geen rechten om admin shares aan te passen 

    Het script disabled het AD gebruikersobject en logt de gebruiker af.
    
    Om verbinding te maken met een de SQL server;
    - Maak een key file
    - Maak een password file
    - Het script leest deze in vanaf de file share
    - Zet rechten op het .key bestand om security te borgen. 
    (System, Domain Admins, Security Groep: DoC - FsrmConf met de computer objecten waar het script uitgevoerd is.)
    
    Stap 1: Maak een key file
    $AESKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
    $AESKey | out-file E:\systeembeheerscripts\FsrmConfig\AesKey.key

    Stap 2: Maak een password file
    $Cred = Get-Credential
    $Cred.Password| ConvertFrom-SecureString -Key (get-content [pad]\FsrmConfig\AesKey.key)| Set-Content [Pad]\FsrmConfig\EncryptedPassword.txt 

    Wachtwoord veranderd van het account? Maak dan een nieuw password bestand aan.
    Nieuw wachtwoord bestand maken op basis van een nieuwe key? Voer dan eerst stap 1 uit.

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
    $BadUserWithoutDomain = $BadUser.Substring(5)
    import-module ActiveDirectory
    Disable-ADAccount -Identity $BadUserWithoutDomain
    Add-Logging "Het account $BadUserWithoutDomain is geblokkeerd in AD."
}

function Send-Logoff ($Baduser) {
    # Vraag de gebruikersnaam en wachtwoord op;
    $SecurePassword = Get-Content '\\zorg\data\FsrmConfig\EncryptedPassword.txt' | ConvertTo-SecureString -Key (Get-Content '\\zorg\data\FsrmConfig\AesKey.key')
    # SQL object maken
    Try {
        $DataSource                     = 'SQL server instance'
        $User                           = 'Gebruikersnaam'
        $Password                       = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        $Database                       = 'p-res-workspace-conf'
        $ConnectionString               = "Server=$DataSource;uid=$User;pwd=$Password;Database=$Database;Integrated Security=True;"
        $Connection                     = New-Object System.Data.SqlClient.SqlConnection
        $Connection.ConnectionString    = $ConnectionString
        $Connection.Open()
    }
    catch {
        Add-Logging 'Er kon geen verbinding gemaakt worden met de database! De sessie wordt niet afgemeld. Het script stopt nu'
        exit
    }
    # Vraag de sessie gegevens op in de Ivanti Workspace Console database
    $Cmd = New-Object System.Data.SqlClient.SqlCommand
    $Cmd.Connection = $Connection
    $SqlBadUser = "'%" + $BadUser + "%'"
    try {
        $Cmd.CommandText = "SELECT * FROM tblLicenses WHERE strUserLC LIKE $SqlBadUser"
        $Result = $Cmd.ExecuteReader()
        $IwcData = New-Object System.Data.DataTable
        $IwcData.Load($Result)
        Add-Logging "De gebruiker $($IwcData.strUser) is volgens IWC ingelogd op $($IwcData.strComputerName)"
    }
    catch {
        Add-Logging "Er is iets mis gegaan bij het opvragen van de gegevens. Het script stopt nu."
        exit
    }
    $Connection.Close()
    # Meldt de sessie af
    $ScriptBlock = {
        $ErrorActionPreference = 'Stop'
        try {
            # Controleer dat de gebruiker ingelogd is.
            $Sessies = quser | Where-Object {$_ -match $BadUser}
            # Sessie ID verwerken
            $SessieIds = ($Sessies -split ' +')[2]
            # Troubleshooting 
            Write-Host "Er zijn $(@(SessionIds).Count) sessies gevonden."
            # Verstuur het logoff command per sessie
            $SessieIds | ForEach-Object {
                Write-Host "Sessie ID [$($_)] wordt afgemeld..."
                Logoff $_
            }
        }
        catch {
            if ($_.Exception.Message -match 'No user exists') {
                Write-Host 'Geen sessie gevonden om af te melden...'
            }
            else {
                throw $_.Exception.Message
            }
        }
    }
    Invoke-Command -ComputerName $IwcData.strComputerName -Authentication Kerberos -ScriptBlock $ScriptBlock
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
# Zet een actie uit wanneer de rule matcht    
    if ($Rule -match "Ransomware") {
        Add-Logging "$FullEvent"
        Disable-BadUser
        Send-Logoff
        Clear-Variable BadUser
    }
}
