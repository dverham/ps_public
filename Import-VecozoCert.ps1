# Welkom bij Detrons vette Vecozo Certificate installer! 
# Voer het script uit onder gebruikerscontext
# Time for functions

Function Get-FileName($InitialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "Certificaten (*.p12) | *.p12"
  $OpenFileDialog.ShowDialog() | Out-Null
  $OpenFileDialog.FileName
}

Function Get-VecozoPFX {
    $Prefix = $ENV:OneDrive
    $Suffix = '\Documents'
    $Path = $Prefix + $Suffix
    Write-Host -ForegroundColor Green 'Kies het VECOZO certificaat in het volgende scherm.'
    $Global:VecozoCert = Get-FileName($Path)
    Write-Host -ForegroundColor Green "Het volgende bestand is gekozen: $VECOZOCERT"
}

Function Get-Password {
    Write-Host -ForegroundColor Green 'Wat is het wachtwoord van uw certificaat?: ' -NoNewline
    $Global:Pwd = Read-host
    $Global:Secpwd = ConvertTo-SecureString $Pwd -Force -AsPlainText
    # Import-PfxCertificate -FilePath $Global:VecozoCert -Password $Global:Secpwd Cert:\CurrentUser\My
}

Function Set-Controle {
    $DateFile = Get-Date -UFormat "%Y%m%d%H%M%S"
    $DateNormalized = Get-Date
    $Data = "Het script heeft gelopen op $DateNormalized"
    $Who = $env:USERNAME
    $ControlFile = 'C:\Detron\VezozoImport' + '_' + $Who + '_' + $Date + '.txt'
    $Data | Set-Content $ControlFile
}

Function Get-LocalCertificates {
    [System.Collections.ArrayList]$LocalCertificates = @()
    $Today = Get-Date
    $Global:CsvFile = "PAD\log\Get-Certificates_Local_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    # We gaan voor de User store / Personal certificates
    Set-Location Cert:\CurrentUser\My
    # Vraag de personal certificates in de computer store op en check de geldigheid.
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
            Type            = 'User.Personal'
            Hostname        = $ENV:COMPUTERNAME
        }
        $LocalCertificates += $Object
        Clear-Variable Object
        Clear-Variable Status
        }
    $Global:UserCerts = $LocalCertificates
    # Return $LocalCertificates
}


Function Check-VecozoCertificate {
    $VecCheck = $Global:UserCerts | where {$_.Issuer -like '*Vecozo*' -and $_.Status -match 'Valid'}
    if (!$VecCheck) {
        Write-Host -ForegroundColor Yellow 'Er is geen geldig Vecozo certificaat gevonden.'
        $Global:ImportNeeded = 'YES'
    }
    else {
        Write-Host -ForegroundColor Green 'Er is een geldig Vecozo certificaat gevonden. Weet je zeker dat je een import wil doen?: (J/N) ' -NoNewline
        $Stubborn = Read-Host
        switch ($Stubborn){
        J{
            $Global:ImportNeeded = 'YES'
            }
        N{
            Write-Host -ForegroundColor Red 'U heeft Nee gekozen.'
            $Global:ImportNeeded = 'NOPE'
            }
        default {
            Write-Host -ForegroundColor Red "De keuze $Stobborn is geen geldige keuze."
            $Global:ImportNeeded = 'NOPE'
            }
        }
    }
}

Function Import-VecozoCertificate {
    if ($Global:ImportNeeded -match 'YES'){
        Import-PfxCertificate -FilePath $Global:VecozoCert -Password $Global:Secpwd Cert:\CurrentUser\My
        Write-Host -ForegroundColor Green 'Het certificaat is geimporteerd.'
    }
    else {
        Write-Host -ForegroundColor Green 'Het is niet nodig om een certificaat te importeren.'
    }
}

### Script ###
# Haal het VECOZO certificaat op
Get-VecozoPFX
Write-Host -ForegroundColor Green 'Zit er een wachtwoord op het certificaat? (J/N:) ' -NoNewline
$CertPasswordProtected = Read-Host
if ($CertPasswordProtected -match 'J'){
    Get-Password
}
else {
    # Geen actie
}
# Vraag de bestaande certificaten op
Get-LocalCertificates
# Certificaat importeren?
Check-VecozoCertificate
Import-VecozoCertificate
# Afronden script
Set-Controle