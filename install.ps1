# Nacre bootstrap: downloads the repo and runs windows\install.ps1
#   irm https://nhahan.github.io/nacre/install.ps1 | iex
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dest = Join-Path $env:USERPROFILE 'nacre'
$zip  = Join-Path $env:TEMP 'nacre.zip'
$tmp  = Join-Path $env:TEMP 'nacre-extract'

Invoke-WebRequest -UseBasicParsing 'https://github.com/Nhahan/nacre/archive/refs/heads/main.zip' -OutFile $zip
if (Test-Path $tmp)  { Remove-Item $tmp -Recurse -Force }
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $zip -DestinationPath $tmp -Force
Move-Item (Join-Path $tmp 'nacre-main') $dest
Remove-Item $zip -Force
Remove-Item $tmp -Recurse -Force

& (Join-Path $dest 'windows\install.ps1')
