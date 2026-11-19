# Installs SwipeLater for the PC. Downloads with PowerShell, so Windows adds no "from the internet" mark
# and shows no SmartScreen warning. Run it with the one line from the README.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/Chikensoupppp/lk-dac12ca4eb/releases/latest/download/SwipeLater-PC.exe'
$file = Join-Path $env:TEMP 'SwipeLater-PC.exe'
Write-Host 'Downloading SwipeLater...'
Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
Unblock-File $file
Write-Host 'Installing...'
Start-Process $file
Write-Host 'Done. SwipeLater is opening.'
