xcopy '\\SERVER\FsrmConfig$\Known_Extensions.txt' 'C:\Scripts\Ransomware' /Y
$Extensions = Get-Content 'C:\Scripts\Ransomware\Known_Extensions.txt'
Set-FsrmFileGroup -name "Ransomware_Extensions" -IncludePattern($Extensions)
