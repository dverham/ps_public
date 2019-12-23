<#
.SYNOPSIS
   Het script controleert de aanwezige (Non-) Microsoft services van een remote computer.

.DESCRIPTION
   Het script vraagt welke services gecontroleerd moeten worden:
   1: Microsoft services (Kies 'M')
   2: Non-Microsoft services (Kies 'N')
   3: Alle services (Kies 'A')
   4: Lokale server opties (Kies 'L')
   4.1: Lokale Microsoft services (Kies 'M')
   4.2: Lokale Non-Microsoft services (Kies 'N')
   4.3: Lokale Alle services (Kies 'A')

   Bij remote servers:
   Vervolgens vraagt het script om naar een bestand te navigeren waarin alle externe computernamen staan. Deze 
   computernamen worden ingelezen en gecontroleerd in AD. Computernamen die niet gevonden worden, worden genegeerd.
   Er wordt een overzicht gegenereerd op basis van server, name, displayname.

   Bij lokale servers:
   Kies welke services opgevraagd moeten worden.
    Er wordt een overzicht gegenereerd op basis van server, name, displayname.
   
   Er vindt logging plaats naar PAD\log\Get-VariousServices_[Keuze]_[datum].log
    
.EXAMPLE
   .\Get-VariousServices.ps1

.NOTES
   Author: Dominiek Verham
   Mail: dominiek.verham@conoscenza.nl
#>

<# Functie om logging inregelen.
Vul de waarde $LogMessage met de tekst die in de logging weergegeven moet worden.
Voeg de tekst toe door de functie aan te roepen: Add-Logging $LogMessage. #>
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "PAD\log\Get-VariousServices_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Voeg de koptekst toe aan het logbestand.
Add-Content $logFile -value "************************************************************************************************
Dit is het logbestand van het script: Get-VariousServices.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
************************************************************************************************"
# Voeg de koptekst toe aan de variabele.
$LogVariable.Add("************************************************************************************************
Dit is het logbestand van het script: Get-VariousServices.ps1
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

Function Get-MicrosoftServers(){
    [System.Collections.ArrayList]$Global:ValidServers = @()
    [System.Collections.ArrayList]$Global:InvalidServers = @()
    Write-Host -ForegroundColor Green 'In welk domein zitten de servers? (Z)org.local, (C)are.lan, (O)rbis.local?: ' -NoNewline
    $DomainChoice = Read-Host 
    $SearchString = $Null
    if ($DomainChoice -eq 'Z'){
        $LogMessage = "We controleren de servers tegen het DomainA domein."
        Add-Logging $LogMessage
        $Server = "DomainA"
        $SearchBase = "DistingueshedName"
        $Global:AdminCredentials = Get-Credential
    }
    elseif ($DomainChoice -eq 'C'){
        $LogMessage = "We controleren de servers tegen het DomainB domein."
        Add-Logging $LogMessage
        $Server = "DomainB"
        $SearchBase = "DistingueshedName"
        $Global:AdminCredentials = Get-Credential
    }
    elseif ($DomainChoice -eq 'O'){
        $LogMessage = "We controleren de servers tegen het DomainC domein."
        Add-Logging $LogMessage
        $Server = "DomainC"
        $SearchBase = "DistingueshedName"
        $Global:AdminCredentials = Get-Credential
    }
    else {
        $LogMessage = "Invoer '$DomainChoice' is geen geldige waarde."
        Add-Logging $LogMessage
        break
    }
    $LogMessage = 'Navigeer naar een bestand met de servers...'
    Add-Logging $LogMessage
    $FilePath = Get-FileName 
    $InputServers = Get-Content $FilePath
    foreach ($UncheckedServer in $InputServers){
        if(Get-ADComputer -Server $Server -SearchBase $SearchBase -Filter {Name -eq $UncheckedServer}){
            $Global:ValidServers += $UncheckedServer
            Clear-Variable UncheckedServer
        }
        else {
            $Global:InvalidServers += $UncheckedServer
            Clear-Variable UncheckedServer
        }
    }
    $LogMessage = "De volgende servers zijn gevalideerd in AD: $Global:ValidServers"
    Add-Logging $LogMessage
    $LogMessage = "De volgende servers zijn niet gevonden in AD en worden overgeslagen: $Global:InvalidServers"
    Add-Logging $LogMessage
}

function Get-NonMicrosoftServices(){
    # Vraag de non-Microsoft services op van remote computers.
    # De functie vereist de Get-FileName functie.
    $CsvFile = "Pad\log\Get-VariousServices_NonMS_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    [System.Collections.ArrayList]$RemoteOutput = @()
    $RemoteOutput = foreach ($Server in $Global:ValidServers) {
        Invoke-Command -ComputerName $Server -Authentication Kerberos -Credential $Global:AdminCredentials -ScriptBlock {
            $Services = Get-WmiObject Win32_Service -Property Name,DisplayName,PathName | Select Name,DisplayName,PathName
            $ServiceList = New-Object System.Collections.ArrayList
            foreach ($Service in $Services) {
                Try {
                    $Path = $Service.Pathname.tostring().replace('"','')
                    $LegalCopyRight = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)).legalcopyright
                if ($LegalCopyRight -notlike "*Microsoft*") {
                        $Object = New-Object psobject -Property @{
                            Name        = $Service.Name
                            DisplayName = $Service.DisplayName
                            PathName    = $Service.PathName
                            Server      = $ENV:COMPUTERNAME
                        }
                        $ServiceList += $Object
                        Clear-Variable Object
                    }
                }
                catch {}
            }
        Return $ServiceList
        }
    }
$RemoteOutput | select Server,Name,DisplayName | ft -AutoSize
$RemoteOutput | select Server,Name,DisplayName | ft -AutoSize | clip.exe
$RemoteOutput | select Server,Name,DisplayName | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
$LogMessage = 'De uitkomst is weergegeven in de console en al naar het klembord gekopieerd.'
Add-Logging $LogMessage
$LogMessage = "Voor het gemak is het resultaat naar .CSV geexporteerd naar $CsvFile"
Add-Logging $LogMessage
Start-Sleep 10
}

function Get-MicrosoftServices(){
    # Vraag de non-Microsoft services op van remote computers.
    # De functie vereist de Get-FileName functie.
    $CsvFile = "Pad\log\Get-VariousServices_MS_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    [System.Collections.ArrayList]$RemoteOutput = @()
    $RemoteOutput = foreach ($Server in $Global:ValidServers) {
        Invoke-Command -ComputerName $Server -Authentication Kerberos -Credential $Global:AdminCredentials -ScriptBlock {
            $Services = Get-WmiObject Win32_Service -Property Name,DisplayName,PathName | Select Name,DisplayName,PathName
            $ServiceList = New-Object System.Collections.ArrayList
            foreach ($Service in $Services) {
                Try {
                    $Path = $Service.Pathname.tostring().replace('"','')
                    $LegalCopyRight = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)).legalcopyright
                if ($LegalCopyRight -like "*Microsoft*") {
                        $Object = New-Object psobject -Property @{
                            Name        = $Service.Name
                            DisplayName = $Service.DisplayName
                            PathName    = $Service.PathName
                            Server      = $ENV:COMPUTERNAME
                        }
                        $ServiceList += $Object
                        Clear-Variable Object
                    }
                }
                catch {}
            }
        Return $ServiceList
        }
    }
$RemoteOutput | select Server,Name,DisplayName | ft -AutoSize
$RemoteOutput | select Server,Name,DisplayName | ft -AutoSize | clip.exe
$RemoteOutput | select Server,Name,DisplayName | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
$LogMessage = 'De uitkomst is weergegeven in de console en al naar het klembord gekopieerd.'
Add-Logging $LogMessage
$LogMessage = "Voor het gemak is het resultaat naar .CSV geexporteerd naar $CsvFile."
Add-Logging $LogMessage
start-sleep 10
}

function Get-AllServices(){
    # Vraag alle services op van remote computers.
    # De functie vereist de Get-FileName functie.
    $CsvFile = "Pad\log\Get-VariousServices_All_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    [System.Collections.ArrayList]$RemoteOutput = @()
    $RemoteOutput = foreach ($Server in $Global:ValidServers) {
        Invoke-Command -ComputerName $Server -Authentication Kerberos -Credential $Global:AdminCredentials -ScriptBlock {
            $Services = Get-WmiObject Win32_Service -Property Name,DisplayName,PathName | Select Name,DisplayName,PathName
            $ServiceList = New-Object System.Collections.ArrayList
            foreach ($Service in $Services) {
                Try {
                    $Path = $Service.Pathname.tostring().replace('"','')
                    $LegalCopyRight = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)).legalcopyright
                if ($LegalCopyRight) {
                        $Object = New-Object psobject -Property @{
                            Name        = $Service.Name
                            DisplayName = $Service.DisplayName
                            PathName    = $Service.PathName
                            Server      = $ENV:COMPUTERNAME
                        }
                        $ServiceList += $Object
                        Clear-Variable Object
                    }
                }
                catch {}
            }
        Return $ServiceList
        }
    }
$RemoteOutput | select Server,Name,DisplayName | ft -AutoSize
$RemoteOutput | select Server,Name,DisplayName | ft -AutoSize | clip.exe
$RemoteOutput | select Server,Name,DisplayName | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
$LogMessage = 'De uitkomst is weergegeven in de console en al naar het klembord gekopieerd.'
Add-Logging $LogMessage
$LogMessage = "Voor het gemak is het resultaat naar .CSV geexporteerd naar $CsvFile."
Add-Logging $LogMessage
start-sleep 10
}

function Get-LocalNonMicrosoftServices(){
    # Vraag de non-Microsoft services op van de lokale computer.
    $CsvFile = "Pad\log\Get-VariousServices_LocalNonMS_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    $LocalServices = Get-WmiObject Win32_Service -Property Name,DisplayName,PathName | Select Name,DisplayName,PathName
    $LocalServiceList = New-Object System.Collections.ArrayList
    foreach ($Service in $LocalServices) {
        Try {
            $Path = $Service.Pathname.tostring().replace('"','')
            $LegalCopyRight = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)).legalcopyright
            if ($LegalCopyRight -notlike "*Microsoft*") {                       
                    $Object = New-Object psobject -Property @{
                     Name        = $Service.Name
                    DisplayName = $Service.DisplayName
                    PathName    = $Service.PathName
                    Server      = $ENV:COMPUTERNAME
                    }
            $LocalServiceList += $Object
            Clear-Variable Object
            }
        }
        catch {}
    }
$LocalServiceList | select Server,Name,DisplayName | ft -AutoSize
$LocalServiceList | select Server,Name,DisplayName | ft -AutoSize | clip.exe
$LocalServiceList | select Server,Name,DisplayName | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
$LogMessage = 'De uitkomst is weergegeven in de console en al naar het klembord gekopieerd.'
Add-Logging $LogMessage
$LogMessage = "Voor het gemak is het resultaat naar .CSV geexporteerd naar $CsvFile"
Add-Logging $LogMessage
Start-Sleep 10
}

function Get-LocalMicrosoftServices(){
    # Vraag de non-Microsoft services op van de lokale computer.
    $CsvFile = "Pad\log\Get-VariousServices_LocalMS_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    $LocalServices = Get-WmiObject Win32_Service -Property Name,DisplayName,PathName | Select Name,DisplayName,PathName
    $LocalServiceList = New-Object System.Collections.ArrayList
    foreach ($Service in $LocalServices) {
        Try {
            $Path = $Service.Pathname.tostring().replace('"','')
            $LegalCopyRight = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)).legalcopyright
            if ($LegalCopyRight -like "*Microsoft*") {                       
                    $Object = New-Object psobject -Property @{
                    Name        = $Service.Name
                    DisplayName = $Service.DisplayName
                    PathName    = $Service.PathName
                    Server      = $ENV:COMPUTERNAME
                }
            $LocalServiceList += $Object
            Clear-Variable Object
            }
        }
        catch {}
    }
$LocalServiceList | select Server,Name,DisplayName | ft -AutoSize
$LocalServiceList | select Server,Name,DisplayName | ft -AutoSize | clip.exe
$LocalServiceList | select Server,Name,DisplayName | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
$LogMessage = 'De uitkomst is weergegeven in de console en al naar het klembord gekopieerd.'
Add-Logging $LogMessage
$LogMessage = "Voor het gemak is het resultaat naar .CSV geexporteerd naar $CsvFile"
Add-Logging $LogMessage
Start-Sleep 10
}

function Get-LocalAllServices(){
    # Vraag de non-Microsoft services op van de lokale computer.
    $CsvFile = "Pad\log\Get-VariousServices_LocalAll_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".CSV"
    $LocalServices = Get-WmiObject Win32_Service -Property Name,DisplayName,PathName | Select Name,DisplayName,PathName
    $LocalServiceList = New-Object System.Collections.ArrayList
    foreach ($Service in $LocalServices) {
        Try {
            $Path = $Service.Pathname.tostring().replace('"','')
            $LegalCopyRight = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)).legalcopyright
            if ($LegalCopyRight) {                       
                    $Object = New-Object psobject -Property @{
                    Name        = $Service.Name
                    DisplayName = $Service.DisplayName
                    PathName    = $Service.PathName
                    Server      = $ENV:COMPUTERNAME
                    }
            $LocalServiceList += $Object
            Clear-Variable Object
            }
        }
        catch {}
    }
$LocalServiceList | select Server,Name,DisplayName | ft -AutoSize
$LocalServiceList | select Server,Name,DisplayName | ft -AutoSize | clip.exe
$LocalServiceList | select Server,Name,DisplayName | Export-Csv -Path $CsvFile -NoClobber -NoTypeInformation
$LogMessage = 'De uitkomst is weergegeven in de console en al naar het klembord gekopieerd.'
Add-Logging $LogMessage
$LogMessage = "Voor het gemak is het resultaat naar .CSV geexporteerd naar $CsvFile"
Add-Logging $LogMessage
Start-Sleep 10
}

########################### Begin van het script ###########################
Clear-Host
Write-Host -ForegroundColor Green "Dit script vraagt de (Non-)Microsoft services op, bij remote hosts of de lokale computer."
Write-Host -ForegroundColor Green "Wil je remote Microsoft services, Non-Microsoft services, Alle services of de lokale services opvragen? (M/N/A/L): " -NoNewline
$Choice = Read-Host
if ($Choice -eq 'M') {
    $LogMessage = "Keuze '$Choice'. De Microsoft services worden opgevraagd."
    Add-Logging $LogMessage
        Get-MicrosoftServers
    Get-MicrosoftServices
    break
}
elseif ($Choice -eq 'N'){
    $LogMessage = "Keuze '$Choice'. De Non-Microsoft services worden opgevraagd."
    Add-Logging $LogMessage
    Get-MicrosoftServers
    Get-NonMicrosoftServices
    break
}
elseif ($Choice -eq 'A'){
    $LogMessage = "Keuze '$Choice'. Alle services worden opgevraagd."
    Add-Logging $LogMessage
    Get-MicrosoftServers
    Get-AllServices
    break
}
elseif ($Choice -eq 'L'){
    $LogMessage = "Keuze '$Choice'. De services worden op de localhost opgevraagd."
    Add-Logging $LogMessage
    Write-Host -ForegroundColor Green "Wil je de lokale Microsoft services, Non-Microsoft services of Alle services opvragen? (M/N/A): " -NoNewline
    $LocalChoice = Read-Host
    if ($LocalChoice -eq 'M') {
        $LogMessage = "Keuze '$LocalChoice' . De Microsoft services van de lokale machine wordeen opgevraagd."
        Add-Logging $LogMessage
        Get-LocalMicrosoftServices
        break
    }
    elseif ($LocalChoice -eq 'N'){
        $LogMessage = "Keuze '$LocalChoice' . De Non-Microsoft services van de lokale machine wordeen opgevraagd."
        Add-Logging $LogMessage
        Get-LocalNonMicrosoftServices
        break
    }
    elseif($LocalChoice -eq 'A'){
        $LogMessage = "Keuze '$LocalChoice' . Alle services van de lokale machine wordeen opgevraagd."
        Add-Logging $LogMessage
        Get-LocalAllServices
        break
    }
    else{
        $LogMessage = "Keuze '$Choice' is ongeldig. Het script stopt."
        Add-Logging $LogMessage
        Start-Sleep 10
        break
    }
}
else {
    $LogMessage = "Keuze '$Choice' is ongeldig. Het script stopt."
    Add-Logging $LogMessage
    Start-Sleep 10
    break
}
