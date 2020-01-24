<#
.SYNOPSIS
    Voer dit script uit om alle FSRM servers bij te werken met de file screens extensies.

.DESCRIPTION
    Het script vraagt de groep DoC - FsrmConfig uit en stuurt via PSRemoting een command om
    de reeds aanwezige geplande taak uit te voeren. 
    
    Het gevolg is dat de geplande taak het exclusion bestand en extensions bestand download
    en direct importeert in de file group van FSRM.

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
    .\Update-RemoteFsrmServers.ps1

.NOTES
    Auteur: Dominiek Verham
    Mail: dominiek.verham@conoscenza.nl
    Doel: FSRM automatisch instellen op verschillende Windows Server versies, vanaf 2012.
#>

##########################################################################################
###                             Functions                                              ###
##########################################################################################

# Functie om logging inregelen.
# Voeg de tekst toe door de functie aan te roepen: Add-Logging 'bericht' of in geval van variabele Add-Logging "$Var".
[System.Collections.ArrayList]$LogVariable = @()
$Who = "$env:userdomain\$env:username"
$WinVer = Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object -MemberName Caption
$logFile = "padnaarbeheerserver\log\Update-RemoteFsrmServers_"+$ENV:COMPUTERNAME+"_"+(Get-Date -UFormat "%Y%m%d%H%M%S")+".log"
$StartDateTime = (Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
# Definieer de header
$Header = "************************************************************************************************
Dit is het logbestand van het script: Update-RemoteFsrmServers.ps1
Het script wordt uitgevoerd door $who op $StartDateTime
Het script vraagt alle leden op van de groep 'DoC - FsrmConfig' en triggert de scheduled update task.
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

function Get-FsrmServers {
    $FsrmServers = Get-ADGroupMember -Identity 'DoC - FsrmConfig'
    [System.Collections.ArrayList]$UpdateResults = @()
    if ($FsrmServers) {
        foreach ($FsrmServer in $FsrmServers) {
            Add-Logging "De geplande taak wordt gestart op server $($FsrmServer.name)"
            Invoke-Command -ComputerName $($FsrmServer.Name) -Authentication Kerberos -ScriptBlock {Get-ScheduledTask | where Taskname -eq 'FSRM - Update File Screen Group - Ransomware_Extensions' | Start-ScheduledTask}
            Start-Sleep -Seconds 5
            Add-Logging "De resultaten worden verwerkt..."
            $RemoteResult = Invoke-Command -ComputerName $($FsrmServer.Name) -Authentication Kerberos -ScriptBlock {$LastResult = Get-ScheduledTask | where Taskname -eq 'FSRM - Update File Screen Group - Ransomware_Extensions' | Get-ScheduledTaskInfo 
                $CustomResult = New-Object psobject -Property @{
                    LastRunTime = $LastResult.LastRunTime
                    LastTaskResult = $LastResult.LastTaskResult
                    NextRunTime = $LastResult.NextRunTime
                    LastExecutedOn = $ENV:COMPUTERNAME
                }
                return $CustomResult
            }
            $UpdateResults += $RemoteResult
            Clear-Variable RemoteResult
        }
        $ResultToCSV = $UpdateResults | select PSComputerName,LastTaskResult
        $UpdateResultsLog = 'E:\SysteembeheerScripts\FsrmConfig\Update-RemoteFsrmServers_Log\UpdateResults_'+(Get-Date -UFormat "%Y%m%d%H%M%S")+".csv"
        $ResultToCSV | Export-Csv -Path $UpdateResultsLog -NoTypeInformation
        Add-Logging "De export is terug te vinden op $UpdateResultsLog"
    }
    else {
    Add-Logging 'Geen servers gevonden in de DoC - FsrmConfig groep. Er zijn geen updates om te triggeren.'
    exit
    }
}

##########################################################################################
###                             Script                                                 ###
##########################################################################################
# Vraag de leden op van de FSRM groep er start de update taak
Get-FsrmServers
# Afronden
Start-Sleep -Seconds 5
