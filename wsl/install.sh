#!/usr/bin/env bash
# Runs inside WSL (Ubuntu/Debian based): zsh, oh-my-zsh, Node.js (nvm), tmux and the Nacre dotfiles.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ~

sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zsh git curl ca-certificates tmux fzf

# Keep the user's original files once (never overwrite an existing backup)
backup_once() {
  if [ -f "$1" ] && [ ! -L "$1" ] && [ ! -e "$1.nacre-bak" ]; then cp "$1" "$1.nacre-bak"; fi
  return 0
}
backup_once ~/.zshrc
backup_once ~/.tmux.conf

# oh-my-zsh + plugins
if [ ! -d ~/.oh-my-zsh ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZC=~/.oh-my-zsh/custom/plugins
[ -d "$ZC/zsh-autosuggestions" ] || git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZC/zsh-autosuggestions"
[ -d "$ZC/zsh-syntax-highlighting" ] || git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZC/zsh-syntax-highlighting"

# zsh as the login shell
ME="$(id -un)"
if [ "$(getent passwd "$ME" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  sudo chsh -s "$(command -v zsh)" "$ME"
fi

# nvm + Node.js LTS
export NVM_DIR="$HOME/.nvm"
[ -d "$NVM_DIR" ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | PROFILE=/dev/null bash
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'

mkdir -p ~/code

# Dotfiles: symlink when the repo lives under $HOME (edits apply immediately), otherwise copy
link() {
  local src="$1" dst="$2"
  rm -f "$dst"
  case "$HERE" in
    "$HOME"/*) ln -s "$src" "$dst" ;;
    *)         cp "$src" "$dst" ;;
  esac
}
link "$HERE/zshrc" ~/.zshrc
link "$HERE/tmux.conf" ~/.tmux.conf

echo "=== versions ==="
node -v; npm -v; zsh --version; tmux -V
echo "Done. Open a new terminal."
