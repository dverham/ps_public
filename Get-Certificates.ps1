<#
.SYNOPSIS
    Het script inventariseert de aanwezige computer certificaten. 
    Kies L voor de lokale computer. 
    Kies R voor remote computers (import via tekst bestand).

.DESCRIPTION
    Het script controleert de PERSONAL certificaten van de COMPUTER store. 

    Na het uitvoeren van het script wordt de vraag gesteld waar de certificaten gecontroleerd moeten worden. 
    Kies L voor de lokale server. 
    Kies R voor remote servers. Het script vraagt om input van de admin credentials en opent een Windows Verkenner scherm
    om te navigeren naar een tekst bestand waarin de servernamen vermeld staan. 

    De geimporteerde servernamen worden gevalideerd tegen de AD. Servernamen die niet gevonden worden, worden overgeslagen. 

    De certificaten worden geinventariseerd en de volgende waarden worden toegevoegd:
    - Type: Geeft aan waar de certificaten staan (Computer.Personal)
    - Status: Per certificaat checken we de geldigheid. Bij geldig: valid. Bij verlopen: Expired.

    Na inventarisatie wordt het resultaat in de Shell weergegeven en als .CSV bestand opgeslagen. 
    Pas de waarde in de variabele $Global:CsvFile aan om een eigen pad te kiezen.

    Er zijn geen extra PowerShell modules nodig om dit script te kunnen gebruiken.
    
.EXAMPLE
    .\Get-Certificates.ps1

.NOTES
    Author: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl

    Status: Productie
#>
################# Functies #################
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "PATH\log\Get-Certificates_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
Dit is het logbestand van het script: Get-Certificates.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Get-Certificates.ps1
Het script wordt uitgevoerd door $who op $StartDateTime)
************************************************************************************************")
Function Add-Logging ($LogMessage){
    $logPrefix = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S") + ": "
    Add-Content $logFile -value ($logPrefix + $LogMessage)
    $LogVariable.Add("$logPrefix" + "$LogMessage") > $null
    $LogVariable[-1]
    Clear-Variable LogMessage
}

Function Get-FileName($InitialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "Plain Text (*.txt) | *.txt"
  $OpenFileDialog.ShowDialog() | Out-Null
  $OpenFileDialog.FileName
}

Function Get-Servers {
    [System.Collections.ArrayList]$Global:ValidServers = @()
    [System.Collections.ArrayList]$Global:InvalidServers = @()
    Add-Logging 'Navigeer naar het bestand met de servers...'
    $FilePath = Get-FileName
    $InputServers = Get-Content $FilePath
    foreach ($UncheckedServer in $InputServers) {
        if (Get-ADComputer -Filter {Name -eq $UncheckedServer}){
            $Global:ValidServers += $UncheckedServer
            Clear-Variable UncheckedServer
        }
        else {
            $Global:InvalidServers += $UncheckedServer
            Clear-Variable UncheckedServer
        }
    }
    Add-Logging "De volgende servers zijn gevalideerd in AD: $Global:ValidServers"
    Add-Logging "De volgende servers zijn niet gevonden in AD en worden overgeslagen: $Global:InvalidServers"
}

function Get-LocalCertificates {
    [System.Collections.ArrayList]$LocalCertificates = @()
    $Today = Get-Date
    $Global:CsvFile = "PATH\log\Get-Certificates_Local_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    # We gaan voor de Computer store / Personal certificates
    Set-Location Cert:\LocalMachine\My
    # Vraag de personal certificates in de computer store op en check de geldigheid.
    $PcCerts = Get-ChildItem
    # $ValidPcCerts = $PcCerts | where {$_.NotAfter -ge $Today}
    # $ExpiredPcCerts = $AllPcCerts | where {$_.NotAfter -lt $Today}
    foreach ($Certificate in $PcCerts) {
        if ($Certificate.NotAfter -ge $Today) {
            $Status = 'Valid'
        }
        else {
            $Status = 'Expired'
        }
        $Object = New-Object psobject -Property @{
            Subject         = $Certificate.Subject
            FriendlyName    = $Certificate.FriendlyName
            Thumbprint      = $Certificate.Thumbprint
            NotAfter        = $Certificate.NotAfter
            Status          = $Status
            HasPrivateKey   = $Certificate.HasPrivateKey
            Issuer          = $Certificate.Issuer
            Type            = 'Computer.Personal'
            Hostname        = $ENV:COMPUTERNAME
        }
        $LocalCertificates += $Object
        Clear-Variable Object
        Clear-Variable Status
        }
    $LocalCertificates | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
    Add-Logging $LocalCertificates
    Return $LocalCertificates
}

Function Get-RemoteCertificates {
    Add-Logging 'We vragen de certificaten nu op bij de remote servers...'
    [System.Collections.ArrayList]$RemoteCertificates = @()
    $Today = Get-Date
    $Global:CsvFile = "Path\log\Get-Certificates_Remote_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    $RemoteCertificates = foreach ($Server in $Global:ValidServers){
        Invoke-Command -ComputerName $Server -Authentication Kerberos -Credential $Global:AdminCredentials -ScriptBlock {
            $ServerCertificates = New-Object System.Collections.ArrayList
            Set-Location Cert:\LocalMachine\My
            $PcCerts = Get-ChildItem
            foreach ($Certificate in $PcCerts) {
                if ($Certificate.NotAfter -ge $Today) {
                    $Status = 'Valid'
                }
                else {
                    $Status = 'Expired'
                }
                $Object = New-Object psobject -Property @{
                    Subject         = $Certificate.Subject
                    FriendlyName    = $Certificate.FriendlyName
                    Thumbprint      = $Certificate.Thumbprint
                    NotAfter        = $Certificate.NotAfter
                    Status          = $Status
                    HasPrivateKey   = $Certificate.HasPrivateKey
                    Issuer          = $Certificate.Issuer
                    Type            = 'Computer.Personal'
                    Hostname        = $ENV:COMPUTERNAME
                }
                $ServerCertificates += $Object
                Clear-Variable Object
                Clear-Variable Status
                }
            Return $ServerCertificates
        }
    }
    $RemoteCertificates | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
    $RemoteCertificates
}

################# Begin van het script #################
Clear-Host
Add-Logging "Dit script vraagt de lokale certificaten op en kan gebruikt worden om remote certificaten op te vragen."
Add-Logging "Alleen de PERSONAL certificaten in de COMPUTER store worden opgevraagd."
Write-Host -ForegroundColor Green 'Wil je de certificaten lokaal opvragen of van remote systemen? (L/R): ' -NoNewline
$Where = Read-Host
switch ($Where)
{
    L
    {
        Add-Logging "De lokale certificaten worden geinventariseerd."
        Get-LocalCertificates
        Add-Logging "Voor het gemak worden de gegevens geexporteerd naar .CSV op $CSVFile"
        break
    }
    R
    {
        Add-Logging "De certificaten worden opgevraagd op externe systemen."
        Add-Logging "Voer de admin credentials in die gebruikt worden om de certificaten op te vragen: "
        $Global:AdminCredentials = Get-Credential
        Get-Servers
        Get-RemoteCertificates
        Add-Logging "Voor het gemak worden de gegevens geexporteerd naar .CSV op $CSVFile"
        break
    }
    default
    {
        Add-Logging "$where is geen geldige keuze! Het script stopt."
        break
    }
}
