# Lock In Focus Buddy: one-time install for Chrome or Edge (no store, no admin).
# Run from PowerShell:  .\install.ps1
param(
    [string]$CompanionExe = (Join-Path $PSScriptRoot '..\windows-companion\bin\Debug\net10.0-windows\LockIn.Companion.exe')
)

$exe = Resolve-Path -LiteralPath $CompanionExe -ErrorAction Stop
Write-Host 'Step 1 of 2: linking Chrome and Edge to Lock In...'
& $exe.Path --register-browser
if ($LASTEXITCODE -ne 0) { throw 'Could not link the browsers. Is the companion built?' }

Write-Host ''
Write-Host 'Step 2 of 2: load the extension (one time):'
Write-Host '  1. Open Chrome or Edge.'
Write-Host '  2. Go to chrome://extensions (Edge: edge://extensions).'
Write-Host '  3. Turn on "Developer mode" (top right).'
Write-Host '  4. Click "Load unpacked" and pick the folder that just opened.'
Write-Host '  5. Open the extension details and turn on "Allow in Incognito".'
Write-Host ''
Start-Process explorer.exe -ArgumentList "`"$PSScriptRoot`""
