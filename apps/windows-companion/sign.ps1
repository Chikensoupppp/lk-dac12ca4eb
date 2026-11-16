# Signs the PC app with Azure Artifact Signing (account nogbox-signing, profile nogbox-profile).
# Needs: Azure CLI signed in (az login), the "Artifact Signing Certificate Profile Signer" role,
# signtool (Windows SDK) and the Microsoft.ArtifactSigning.Client NuGet package unzipped.
# Usage: .\sign.ps1 -File Nogbox-PC.exe -Dlib <path>\bin\x64\Azure.CodeSigning.Dlib.dll
param([Parameter(Mandatory)][string]$File, [Parameter(Mandatory)][string]$Dlib)
$meta = Join-Path $env:TEMP 'nogbox-sign.json'
@{ Endpoint = 'https://eus.codesigning.azure.net/'; CodeSigningAccountName = 'nogbox-signing'; CertificateProfileName = 'nogbox-profile' } |
  ConvertTo-Json | Set-Content $meta -Encoding ascii
$tool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter signtool.exe |
  Where-Object FullName -like '*\x64\*' | Sort-Object FullName | Select-Object -Last 1
& $tool.FullName sign /v /fd SHA256 /tr 'http://timestamp.acs.microsoft.com' /td SHA256 /dlib $Dlib /dmdf $meta $File
