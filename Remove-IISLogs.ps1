<#
.Synopsis
   Gebruik dit script om de log bestanden van IIS op te schonen.
.DESCRIPTION
   Om dit script te kunnen gebruiken is de WebAdministration module nodig. Deze module is geïnstalleerd op IIS servers.
.EXAMPLE
   .\Remove-IISLog.ps1
.NOTES
    Auteur: Dominiek Verham
    Email: dominiek.verham@conoscenza.nl
#>
 
### Definieer de functies
Function CleanLogfiles($TargetFolder)
{
    if (Test-Path $TargetFolder) {
        $Now = Get-Date
        $LastWrite = $Now.AddDays(-$days)
        # $Files = Get-ChildItem $TargetFolder -Include *.log,*.blg, *.etl, *.txt -Recurse | Where {$_.LastWriteTime -le "$LastWrite"}
        $Files = Get-ChildItem $TargetFolder -Recurse | Where-Object {$_.Name -like "*.log" -or $_.Name -like "*.blg" -or $_.Name -like "*.etl" -or $_.Name -like "*.txt"}  | where {$_.lastWriteTime -le "$lastwrite"} | Select-Object FullName
        foreach ($File in $Files)
            {
            # Write-Host "Deleting file $File" -ForegroundColor "white"; Remove-Item $File -ErrorAction SilentlyContinue | out-null
            $FullFileName = $File.FullName  
            Write-Host "Deleting file $FullFileName" -ForegroundColor "yellow"; 
            Remove-Item $FullFileName -ErrorAction SilentlyContinue | Out-Null
            }
       }
Else {
    # Regel voor test doeleinden
    Write-Host "The folder $TargetFolder doesn't exist! Check the folder path!" -ForegroundColor "white"
    }
}
 
# Importeer de IIS WebAdministration PowerShell module.
# Breek het script af wanneer de module niet gevonden is.
try {
    Import-Module WebAdministration -ErrorAction Stop
}
catch {[System.IO.FileNotFoundException]
    Write-Host -ForegroundColor Red 'De PowerShell module WebAdministration is niet gevonden. Zonder deze module werkt het script niet.' 
    break
}
 
# Stel het aantal dagen in waar de logging van bewaard moet blijven.
$days=7
Write-Host -ForegroundColor Green "Het script is ingesteld om logging van $days dagen te laten staan."
 
# Schoon de logfiles op
foreach($WebSite in $(get-website)) 
{
    $logFile="$($Website.logFile.directory)\w3svc$($website.id)".replace("%SystemDrive%",$env:SystemDrive)
    Write-host "$($WebSite.name) [$logfile]"
    CleanLogfiles($logfile)
    Clear-Variable logFile
    }
