Function Get-FileName($InitialDirectory){
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "Plain Text (*.txt) | *.txt"
  $OpenFileDialog.ShowDialog() | Out-Null
  $OpenFileDialog.FileName
}

function Get-NonMicrosoftServices (){
    # Vraag de non-Microsoft services op van remote computers.
    # De functie vereist de Get-FileName functie.
    $FilePath = Get-FileName 
    $InputServers = Get-Content $FilePath 
    [System.Collections.ArrayList]$RemoteOutput = @()
    $RemoteOutput = foreach ($Server in $InputServers) {
        Invoke-Command -ComputerName $Server -ScriptBlock {
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
}

function Get-MicrosoftServices (){
    # Vraag de non-Microsoft services op van remote computers.
    # De functie vereist de Get-FileName functie.
    $FilePath = Get-FileName 
    $InputServers = Get-Content $FilePath 
    [System.Collections.ArrayList]$RemoteOutput = @()
    $RemoteOutput = foreach ($Server in $InputServers) {
        Invoke-Command -ComputerName $Server -ScriptBlock {
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
