<#
.SYNOPSIS
Vraag de grootte van de mailboxen op.

.DESCRIPTION
Gebruik dit script om de groottes van de mailboxen op te vragen. Er wordt geen onderscheid gemaakt tussen gebruikersmailboxen en gedeelde mailboxen.

.NOTES
Auteur: Dominiek Verham
Mail: dominiek.verham@detron.nl
#>

######################### Functies #########################
Function Get-inMB{
    $Result = Get-Mailbox -ResultSize Unlimited | Get-MailboxStatistics | select DisplayName,@{label=”Total Size (MB)”;expression={$_.TotalItemSize.Value.ToMB()}}
    # Laat het resultaat in de console zien
    $Result
}

Function Get-inGB{
    $Result = Get-Mailbox -ResultSize Unlimited | Get-MailboxStatistics | select DisplayName,@{label=”Total Size (GB)”;expression={$_.TotalItemSize.Value.ToGB()}}
    # Laat het resultaat in de console zien
    $Result
}

Function Export-ToCSV {
    Write-Host -ForegroundColor Green 'Wil je de resultaten naar een CSV bestand exporteren? (J/N): ' -NoNewline
    $Export = Read-Host
    Switch ($Export) {
        J {
            $Result | Export-CSV -Path 'C:\Temp\MailboxSizes.CSV' -NoTypeInformation
        }
        N {
            Write-Host -ForegroundColor Green 'Prima.'
        }
        Default {
            Write-Host -ForegroundColor Gray "Keuze $Export is geen geldige keuze. Het resultaat wordt niet geexporteerd."
        }
    }
}

Function Set-Size {
    Write-Host -ForegroundColor Green 'Wil je de groottes in MB of GB ophalen? (M/G): ' -NoNewline
    $Size = Read-Host 
    switch ($Size) {
        M { 
            Get-inMB
         }
        G {
            Get-InGB
        }
        Default {
            Write-Host -ForegroundColor Gray "De optie $Size is geen geldige keuze. De groottes worden in GB opgehaald."
            Get-inGB
        }
    }
}

######################### Script #########################
Clear-Host
# MB of GB?
Set-Size
# Exporteren naar CSV?
Export-ToCSV
