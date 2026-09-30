# Nacre bootstrap: downloads the repo and runs windows\install.ps1
#   irm https://nhahan.github.io/nacre/install.ps1 | iex
& {
  $ErrorActionPreference = 'Stop'          # scoped to this block, the caller's session is not changed
  $ProgressPreference = 'SilentlyContinue' # the progress bar makes Invoke-WebRequest very slow on PowerShell 5.1
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  # A dedicated folder that Nacre owns, so nothing of the user's is ever deleted
  $base = Join-Path $env:LOCALAPPDATA 'Nacre'
  $dest = Join-Path $base 'src'
  $zip  = Join-Path $env:TEMP 'nacre.zip'
  $tmp  = Join-Path $env:TEMP 'nacre-extract'

  New-Item -ItemType Directory -Force $base | Out-Null
  Invoke-WebRequest -UseBasicParsing 'https://github.com/Nhahan/nacre/archive/refs/heads/main.zip' -OutFile $zip
  if (Test-Path $tmp)  { Remove-Item $tmp -Recurse -Force }
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Expand-Archive $zip -DestinationPath $tmp -Force
  Move-Item (Join-Path $tmp 'nacre-main') $dest
  Remove-Item $zip -Force
  Remove-Item $tmp -Recurse -Force

  & (Join-Path $dest 'windows\install.ps1')
}
