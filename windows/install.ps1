# Windows side setup: WSL2 + Ubuntu, WezTerm, Windows Terminal profile, icon, desktop shortcut.
# Run in Windows PowerShell (5.1 OK). WSL feature install needs admin and a reboot;
# if it asks for a reboot, reboot and run this script again.
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo   = Split-Path -Parent $root
$user   = $env:USERNAME.ToLower()
$iconDir = Join-Path $env:USERPROFILE '.wsl-icon'
$ico    = Join-Path $iconDir 'iterm-like.ico'
$wtGuid = '{a1b2c3d4-0000-4000-8000-00000000ab01}'

function Wsl-Text { param([string[]]$a) (& wsl.exe @a 2>&1 | Out-String) -replace "`0", '' }

# 1) WSL2 + Ubuntu
$list = Wsl-Text @('-l', '-q')
if ($list -notmatch 'Ubuntu') {
  Write-Host '>> Installing WSL2 + Ubuntu (admin required; reboot may be needed)'
  wsl.exe --install -d Ubuntu --no-launch
  $list = Wsl-Text @('-l', '-q')
  if ($list -notmatch 'Ubuntu') {
    Write-Host 'Reboot Windows, then run this script again.' -ForegroundColor Yellow
    exit 0
  }
}

# 2) Passwordless default user (same name as the Windows user)
$hasUser = (Wsl-Text @('-d', 'Ubuntu', '-u', 'root', '--', 'id', '-u', $user)) -match '^\d+'
if (-not $hasUser) {
  Write-Host ">> Creating WSL user '$user' (no password, passwordless sudo)"
  $s = "useradd -m -s /bin/bash -G sudo $user && passwd -d $user && echo '$user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$user && chmod 440 /etc/sudoers.d/$user && printf '[user]\ndefault=$user\n' > /etc/wsl.conf"
  wsl.exe -d Ubuntu -u root -- bash -c $s | Out-Null
  wsl.exe --terminate Ubuntu
}

# 3) WezTerm
if (-not (Test-Path 'C:\Program Files\WezTerm\wezterm-gui.exe')) {
  Write-Host '>> Installing WezTerm via winget'
  winget install --id wez.wezterm -e --accept-source-agreements --accept-package-agreements
}
Copy-Item (Join-Path $root 'wezterm.lua') (Join-Path $env:USERPROFILE '.wezterm.lua') -Force

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

# 5) Windows Terminal profile (iTerm2 colors, keys); skipped if Windows Terminal is missing
$sp = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if ($sp) {
  Write-Host '>> Patching Windows Terminal settings (backup: settings.json.bak-dotfiles)'
  Copy-Item $sp "$sp.bak-dotfiles" -Force
  $j = Get-Content $sp -Raw | ConvertFrom-Json
  $scheme = [pscustomobject]@{
    name = 'iTerm2 Default'; background = '#000000'; foreground = '#C7C7C7'; cursorColor = '#C7C7C7'; selectionBackground = '#C1DDFF'
    black = '#000000'; red = '#C91B00'; green = '#00C200'; yellow = '#C7C400'; blue = '#2225C4'; purple = '#CA30C7'; cyan = '#00C5C7'; white = '#C7C7C7'
    brightBlack = '#686868'; brightRed = '#FF6E67'; brightGreen = '#5FFA68'; brightYellow = '#FFFC67'; brightBlue = '#6871FF'; brightPurple = '#FF77FF'; brightCyan = '#60FDFF'; brightWhite = '#FFFFFF'
  }
  $j.schemes = @($j.schemes | Where-Object name -ne 'iTerm2 Default') + $scheme
  $prof = [pscustomobject]@{
    guid = $wtGuid; name = 'Ubuntu'; commandline = "wsl.exe -d Ubuntu --cd ~"; icon = $ico
    font = [pscustomobject]@{ face = 'Lucida Console, Malgun Gothic'; size = 12 }
    colorScheme = 'iTerm2 Default'; cursorShape = 'filledBox'; opacity = 100; useAcrylic = $false
    scrollbarState = 'hidden'; padding = '6, 4, 6, 4'
  }
  $j.profiles.list = @($prof) + @($j.profiles.list | Where-Object guid -ne $wtGuid)
  foreach ($p in $j.profiles.list) { if ($p.source -eq 'Microsoft.WSL') { $p | Add-Member -NotePropertyName hidden -NotePropertyValue $true -Force } }
  $j.defaultProfile = $wtGuid
  foreach ($kv in @{ copyOnSelect = $true; tabWidthMode = 'titleLength'; confirmCloseAllTabs = $false; 'warning.multiLinePaste' = $false }.GetEnumerator()) {
    $j | Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value -Force
  }
  function A($keys, $cmd) { [pscustomobject]@{ command = $cmd; keys = $keys } }
  $j.actions = @(
    (A 'shift+enter' ([pscustomobject]@{ action = 'sendInput'; input = "$([char]27)`r" })),
    (A 'ctrl+shift+v' ([pscustomobject]@{ action = 'splitPane'; split = 'right'; splitMode = 'duplicate' })),
    (A 'ctrl+shift+h' ([pscustomobject]@{ action = 'splitPane'; split = 'down'; splitMode = 'duplicate' })),
    (A 'ctrl+shift+w' 'closePane'),
    (A 'ctrl+shift+k' ([pscustomobject]@{ action = 'clearBuffer'; clear = 'all' })),
    (A 'ctrl+shift+left' ([pscustomobject]@{ action = 'moveFocus'; direction = 'left' })),
    (A 'ctrl+shift+right' ([pscustomobject]@{ action = 'moveFocus'; direction = 'right' })),
    (A 'ctrl+shift+up' ([pscustomobject]@{ action = 'moveFocus'; direction = 'up' })),
    (A 'ctrl+shift+down' ([pscustomobject]@{ action = 'moveFocus'; direction = 'down' })),
    (A 'ctrl+shift+enter' 'toggleFocusMode'),
    (A 'alt+left' 'unbound'), (A 'alt+right' 'unbound'), (A 'alt+up' 'unbound'), (A 'alt+down' 'unbound'),
    (A 'alt+shift+d' 'unbound'), (A 'alt+shift+minus' 'unbound'), (A 'alt+shift+plus' 'unbound')
  )
  $j | ConvertTo-Json -Depth 20 | Set-Content $sp -Encoding utf8
}

# 6) Desktop shortcut -> wezterm-gui.exe (NOT wezterm.exe, which also opens a console window)
$desk = [Environment]::GetFolderPath('Desktop')
$ws = New-Object -ComObject WScript.Shell
$l = $ws.CreateShortcut((Join-Path $desk 'Ubuntu (WSL).lnk'))
$l.TargetPath = 'C:\Program Files\WezTerm\wezterm-gui.exe'
$l.WorkingDirectory = $env:USERPROFILE
$l.IconLocation = "$ico,0"
$l.Save()

# 7) Inside WSL: zsh, Node, tmux, dotfiles
Write-Host '>> Running WSL setup'
$wslScript = (Wsl-Text @('-d', 'Ubuntu', '--cd', '~', '--', 'wslpath', '-a', (Join-Path $repo 'wsl\install.sh').Replace('\', '/'))).Trim()
wsl.exe -d Ubuntu --cd '~' -- bash $wslScript

Write-Host "`nDone. Open the 'Ubuntu (WSL)' shortcut, " -ForegroundColor Green
