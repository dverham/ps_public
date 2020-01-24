<#
.SYNOPSIS
    Het script voert countermeasures uit wanneer er ransomware gedetecteerd is door FSRM.

.DESCRIPTION
    Het script triggert door een File Screen en controleert het event log op entries van FSRM.
    De entry wordt ingelezen via een replacementstring array waar datapunten direct in opgeslagen zijn.
    Troubleshooting tip: om dit array uit te lezen : $Events.ReplacementStrings

    Het script kan het gebruikersobject disablen in AD en de gebruiker afmelden wanneer deze een Ivanti sessie heeft.
    Het afmelden is nog nie gewenst en dus niet actief.

    Wachtwoord van het account voor SQL veranderd? Geen probleem.
    Gebruik de bestaande key om een nieuw wachtwoord bestand te maken via de volgende code:
    $Cred = Get-Credential
    $Cred.Password| ConvertFrom-SecureString -Key (get-content pad\FsrmConfig\AesKey.key)| Set-Content E:\systeembeheerscripts\FsrmConfig\EncryptedPassword.txt

    Wil je ook een nieuwe key? 
    $AESKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
    $AESKey | out-file pad\FsrmConfig\AesKey.key

    Dit script is onderdeel van de FSRM toolkit, bestaande uit:
    - Inrichting                        Doel
    1: Add-PassiveFsrmServer.ps1        Dit richt FSRM met passieve File Screens in. (Monitoring)
    2: Add-ActiveFsrmServer.ps1         Dit richt FSRM met actieve File Screens in. (Productie)
    3: Set-PassiveScreensToActive.ps1   Dit converteert een monitoring inrichting naar een productie inrichting.
    
    - Countermeasures                   Doel
    1: Set-FsrmActions.ps1              Voert de acties uit om Ransomware tegen te gaan.

    - Supporting                        Doel
    1: Remove-FsrmConfiguration.ps1     Haalt FSRM configuratie weg.
    2: Update-Extensions.ps1            Download extensies van https://fsrm.experiant.ca/api/v1/combined.
    3: Update-ExtensionsInternally.ps1  Download extensies en exclusions lokaal, werkt de File Group bij.
    4: Update-RemoteFsrmServers.ps1     Vraagt leden op van de FSRM groep en triggert de remote update taak.


.EXAMPLE
    ALLEEN UITVOEREN VIA FSRM, NIET VIA ENIGE ANDERE MANIEREN

.NOTES
    Aangepast door: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: Voert de acties uit om Ransomware tegen te gaan.
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
    $SecurePassword = Get-Content 'pad\FsrmConfig\EncryptedPassword.txt' | ConvertTo-SecureString -Key (Get-Content 'pad\FsrmConfig\AesKey.key')
    # SQL object maken
    Try {
        $DataSource                     = 'SQL Instance'
        $User                           = 'account'
        $Password                       = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        $Database                       = 'database'
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
            $Sessies = quser | Where-Object {$_ -match $Using:BadUserWithoutDomain}
            # Sessie ID verwerken
            $SessieIds = ($Sessies -split ' +')[3]
            # Troubleshooting 
            Write-Host "Er zijn $(@($SessionIds).Count) sessies gevonden."
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
    $SecurePasswordPdq = Get-Content 'PadMetEncryptedFile.txt' | ConvertTo-SecureString -Key (Get-Content 'PadMetKey')
    $Credential = New-Object System.Management.Automation.PSCredential ("user", $SecurePasswordPdq)
    Invoke-Command -ComputerName $IwcData.strComputerName -Credential $Credential -ScriptBlock $ScriptBlock
    Add-Logging "Send-Logoff afgerond."
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
        # Send-Logoff
        Clear-Variable BadUser
    }
}
