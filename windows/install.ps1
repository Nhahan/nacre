# Nacre - Windows side setup.
# Installs only what is missing (WSL2 + Ubuntu, WezTerm, Meslo LG M font), then writes the WezTerm
# config, a Windows Terminal profile and a desktop shortcut, and runs wsl\install.sh inside WSL.
# Run in Windows PowerShell 5.1+. Installing WSL needs admin rights and may need a reboot:
# reboot, then run this script again. An existing Ubuntu distro is reused as is.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo    = Split-Path -Parent $root
$iconDir = Join-Path $env:USERPROFILE '.wsl-icon'
$ico     = Join-Path $iconDir 'iterm-like.ico'
$wtGuid  = '{a1b2c3d4-0000-4000-8000-00000000ab01}'
$wezGui  = 'C:\Program Files\WezTerm\wezterm-gui.exe'

# wsl.exe writes to stderr on errors; with $ErrorActionPreference = 'Stop' that would abort the script
function Wsl-Text {
  param([string[]]$a)
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { (& wsl.exe @a 2>&1 | Out-String) -replace "`0", '' } finally { $ErrorActionPreference = $old }
}
function Wsl-Run {
  param([string[]]$a)
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & wsl.exe @a | Out-Host; $LASTEXITCODE } finally { $ErrorActionPreference = $old }
}
function Test-Admin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
# Windows user names may contain spaces, dots, capitals or non-ASCII; Linux user names may not
function ConvertTo-LinuxUser([string]$name) {
  $u = ($name.ToLower() -replace '[^a-z0-9_-]', '_')
  if ($u -notmatch '[a-z0-9]') { return 'user' }
  if ($u -notmatch '^[a-z_]') { $u = "u$u" }
  if ($u.Length -gt 32) { $u = $u.Substring(0, 32) }
  $u
}
function Find-Distro {
  (Wsl-Text @('-l', '-q')) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^Ubuntu' } | Select-Object -First 1
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw 'wsl.exe was not found. Nacre needs Windows 10 version 2004 (build 19041) or later, or Windows 11.'
}

# 1) WSL2 + Ubuntu: reuse an existing Ubuntu distro, install WSL + Ubuntu only when none exists
$distro = Find-Distro
if ($distro) {
  Write-Host ">> WSL distro '$distro' found, skipping WSL install"
} else {
  Write-Host '>> WSL/Ubuntu not found, installing (admin required; a reboot may be needed)'
  try {
    if (Test-Admin) { [void](Wsl-Run @('--install', '-d', 'Ubuntu', '--no-launch')) }
    else { Start-Process wsl.exe -ArgumentList '--install', '-d', 'Ubuntu', '--no-launch' -Verb RunAs -Wait }
  } catch {
    throw "WSL installation was cancelled or failed: $($_.Exception.Message)"
  }
  $distro = Find-Distro
  if (-not $distro) {
    Write-Host 'WSL was installed. Reboot Windows, then run this script again.' -ForegroundColor Yellow
    return
  }
}

# 2) A freshly installed distro has only root: create a passwordless user named like the Windows user.
#    An existing distro with its own user is left untouched.
$current = (Wsl-Text @('-d', $distro, '--', 'id', '-un')).Trim()
if ($current -notmatch '^[a-z_][a-z0-9_-]*\$?$') {
  throw "Cannot run commands in WSL distro '$distro' (got: $current). Start it once with: wsl -d $distro"
}
if ($current -eq 'root') {
  $user = ConvertTo-LinuxUser $env:USERNAME
  Write-Host ">> Creating WSL user '$user' (no password, passwordless sudo)"
  $tmpSh = Join-Path $env:TEMP 'nacre-create-user.sh'
  $sh = @'
set -e
u="__USER__"
id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo "$u"
passwd -d "$u" >/dev/null
echo "$u ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/nacre-$u"
chmod 440 "/etc/sudoers.d/nacre-$u"
grep -q '^\[user\]' /etc/wsl.conf 2>/dev/null || printf '\n[user]\ndefault=%s\n' "$u" >> /etc/wsl.conf
'@.Replace('__USER__', $user).Replace("`r", '')
  [IO.File]::WriteAllText($tmpSh, $sh, (New-Object Text.UTF8Encoding $false))
  $code = Wsl-Run @('-d', $distro, '-u', 'root', '--cd', $env:TEMP, '--', 'bash', './nacre-create-user.sh')
  Remove-Item -LiteralPath $tmpSh -Force -ErrorAction SilentlyContinue
  if ($code -ne 0) { throw "Creating the WSL user failed (exit code $code)." }
  [void](Wsl-Run @('--terminate', $distro))
} else {
  Write-Host ">> Using the existing WSL user '$current'"
}

# 3) WezTerm
if (-not (Test-Path $wezGui)) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget was not found. Install WezTerm from https://wezterm.org/install/windows.html and run this script again.'
  }
  Write-Host '>> Installing WezTerm via winget'
  winget install --id wez.wezterm -e --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $wezGui)) { throw 'WezTerm installation failed.' }
}
$lua    = (Get-Content (Join-Path $root 'wezterm.lua') -Raw -Encoding UTF8).Replace("'-d', 'Ubuntu'", "'-d', '$distro'")
$luaDst = Join-Path $env:USERPROFILE '.wezterm.lua'
if ((Test-Path $luaDst) -and -not (Test-Path "$luaDst.bak-nacre") -and ((Get-Content $luaDst -Raw -Encoding UTF8) -ne $lua)) {
  Copy-Item $luaDst "$luaDst.bak-nacre"   # keep the user's original config once
}
[IO.File]::WriteAllText($luaDst, $lua, (New-Object Text.UTF8Encoding $false))

# 4) Icon (generated locally, no download)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $iconDir | Out-Null
function New-Png($size) {
  $bmp = New-Object Drawing.Bitmap $size, $size
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear([Drawing.Color]::Transparent)
  $r = [int]($size * 0.18); $d = $r * 2; $m = [int]($size * 0.04); $w = $size - 2 * $m
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $path.AddArc($m, $m, $d, $d, 180, 90); $path.AddArc($m + $w - $d, $m, $d, $d, 270, 90)
  $path.AddArc($m + $w - $d, $m + $w - $d, $d, $d, 0, 90); $path.AddArc($m, $m + $w - $d, $d, $d, 90, 90); $path.CloseFigure()
  $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 20, 22, 26))), $path)
  $font = New-Object Drawing.Font 'Consolas', ([single]($size * 0.42)), ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $g.DrawString('>_', $font, (New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 60, 220, 110))), [single]($size * 0.14), [single]($size * 0.26))
  $g.Dispose()
  $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  , $ms.ToArray()
}
$sizes = 16, 32, 48, 64, 128, 256
$pngs = foreach ($s in $sizes) { , (New-Png $s) }
$fs = [IO.File]::Create($ico); $bw = New-Object IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$off = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $s = $sizes[$i]; $b = if ($s -ge 256) { 0 } else { $s }
  $bw.Write([byte]$b); $bw.Write([byte]$b); $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$off)
  $off += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Close(); $fs.Close()

# 4b) Font: Meslo LG M (Menlo-based, free). Per-user install, no admin needed.
#     The download is pinned to a commit and verified against a SHA-256 hash.
$fontDir   = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontReg   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontUrl   = 'https://raw.githubusercontent.com/andreberg/Meslo-Font/09a431d546d211130352c28eb0466e5d7d5aeaf0/dist/v1.2.1/Meslo%20LG%20v1.2.1.zip'
$fontSha   = 'D0BCB7668DDA8FA1A0F8162D626ADB434C32854E243B5BD52A717CF569AF08D0'
$fontFiles = @{ 'MesloLGM-Regular.ttf' = 'Meslo LG M Regular'; 'MesloLGM-Bold.ttf' = 'Meslo LG M Bold'; 'MesloLGM-Italic.ttf' = 'Meslo LG M Italic'; 'MesloLGM-BoldItalic.ttf' = 'Meslo LG M Bold Italic' }
$missing = $fontFiles.Keys | Where-Object { -not (Test-Path (Join-Path $fontDir $_)) }
if ($missing) {
  Write-Host '>> Installing Meslo LG M font'
  $fz = Join-Path $env:TEMP 'meslo.zip'; $fx = Join-Path $env:TEMP 'meslo-extract'
  Invoke-WebRequest -UseBasicParsing $fontUrl -OutFile $fz
  if ((Get-FileHash $fz -Algorithm SHA256).Hash -ne $fontSha) {
    Remove-Item -LiteralPath $fz -Force
    throw 'Font download failed the SHA-256 check; not installing it.'
  }
  if (Test-Path $fx) { Remove-Item $fx -Recurse -Force }
  Expand-Archive $fz -DestinationPath $fx -Force
  New-Item -ItemType Directory -Force $fontDir | Out-Null
  foreach ($n in $fontFiles.Keys) {
    $src = Get-ChildItem $fx -Recurse -Filter $n | Select-Object -First 1
    Copy-Item $src.FullName (Join-Path $fontDir $n) -Force
    New-ItemProperty -Path $fontReg -Name ($fontFiles[$n] + ' (TrueType)') -Value (Join-Path $fontDir $n) -PropertyType String -Force | Out-Null
  }
  Remove-Item -LiteralPath $fz -Force; Remove-Item $fx -Recurse -Force
  Add-Type @"
using System; using System.Runtime.InteropServices;
public class NacreFont {
  [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, IntPtr l, uint f, uint t, out UIntPtr r);
  [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResource(string p);
}
"@
  foreach ($n in $fontFiles.Keys) { [void][NacreFont]::AddFontResource((Join-Path $fontDir $n)) }
  $r = [UIntPtr]::Zero
  [void][NacreFont]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 3000, [ref]$r)
}

# 5) Windows Terminal: adds an "Ubuntu (Nacre)" profile and the iTerm2 color scheme.
#    Nothing else (default profile, key bindings, other profiles) is changed.
function Update-WindowsTerminal([string]$sp) {
  try { $j = Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch {
    Write-Warning 'Windows Terminal settings.json could not be parsed (comments?). Skipping the Windows Terminal profile.'
    return
  }
  if (-not (Test-Path "$sp.bak-nacre")) { Copy-Item $sp "$sp.bak-nacre" }   # keep the original once
  $scheme = [pscustomobject]@{
    name = 'iTerm2 Default'; background = '#000000'; foreground = '#C7C7C7'; cursorColor = '#C7C7C7'; selectionBackground = '#C1DDFF'
    black = '#000000'; red = '#C91B00'; green = '#00C200'; yellow = '#C7C400'; blue = '#2225C4'; purple = '#CA30C7'; cyan = '#00C5C7'; white = '#C7C7C7'
    brightBlack = '#686868'; brightRed = '#FF6E67'; brightGreen = '#5FFA68'; brightYellow = '#FFFC67'; brightBlue = '#6871FF'; brightPurple = '#FF77FF'; brightCyan = '#60FDFF'; brightWhite = '#FFFFFF'
  }
  $schemes = @()
  if ($j.PSObject.Properties['schemes']) { $schemes = @($j.schemes | Where-Object { $_.name -ne 'iTerm2 Default' }) }
  $j | Add-Member -NotePropertyName schemes -NotePropertyValue (@($schemes) + @($scheme)) -Force

  $prof = [pscustomobject]@{
    guid = $wtGuid; name = 'Ubuntu (Nacre)'; commandline = "wsl.exe -d $distro --cd ~"; icon = $ico
    font = [pscustomobject]@{ face = 'Meslo LG M, Malgun Gothic'; size = 12 }
    colorScheme = 'iTerm2 Default'; cursorShape = 'filledBox'; opacity = 100; useAcrylic = $false
    scrollbarState = 'hidden'; padding = '6, 4, 6, 4'
  }
  if (-not $j.PSObject.Properties['profiles'] -or -not $j.profiles) {
    $j | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{ list = @() }) -Force
  }
  if ($j.profiles -is [System.Array]) {                       # old settings format
    $j.profiles = @($prof) + @($j.profiles | Where-Object { $_.guid -ne $wtGuid })
  } else {
    $existing = @(); if ($j.profiles.PSObject.Properties['list']) { $existing = @($j.profiles.list | Where-Object { $_.guid -ne $wtGuid }) }
    $j.profiles | Add-Member -NotePropertyName list -NotePropertyValue (@($prof) + @($existing)) -Force
  }
  [IO.File]::WriteAllText($sp, ($j | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
}
$wtSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if ($wtSettings) {
  Write-Host '>> Adding the Nacre profile to Windows Terminal (backup: settings.json.bak-nacre)'
  Update-WindowsTerminal $wtSettings
}

# 6) Desktop shortcut -> wezterm-gui.exe (NOT wezterm.exe, which also opens a console window)
$desk = [Environment]::GetFolderPath('Desktop')
$ws = New-Object -ComObject WScript.Shell
$l = $ws.CreateShortcut((Join-Path $desk 'Ubuntu (WSL).lnk'))
$l.TargetPath = $wezGui
$l.WorkingDirectory = $env:USERPROFILE
$l.IconLocation = "$ico,0"
$l.Save()

# 7) Inside WSL: zsh, Node.js, tmux, dotfiles (run from the repo's wsl folder, so paths with spaces are fine)
Write-Host '>> Running WSL setup'
$code = Wsl-Run @('-d', $distro, '--cd', (Join-Path $repo 'wsl'), '--', 'bash', './install.sh')
if ($code -ne 0) { throw "WSL setup failed (exit code $code). Fix the error above and run this script again." }

Write-Host "`nDone. Open the 'Ubuntu (WSL)' shortcut on your desktop." -ForegroundColor Green
