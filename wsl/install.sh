#!/usr/bin/env bash
# WSL(Ubuntu) 안에서 실행: zsh / oh-my-zsh / Node / tmux 설정
set -e
export DEBIAN_FRONTEND=noninteractive
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ~

sudo apt-get update -y
sudo apt-get install -y zsh git curl wget tmux build-essential unzip fzf ripgrep jq xclip python3 gh

# oh-my-zsh + 플러그인
if [ ! -d ~/.oh-my-zsh ]; then
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZC=~/.oh-my-zsh/custom/plugins
[ -d $ZC/zsh-autosuggestions ] || git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions $ZC/zsh-autosuggestions
[ -d $ZC/zsh-syntax-highlighting ] || git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting $ZC/zsh-syntax-highlighting
sudo chsh -s "$(which zsh)" "$USER"

# nvm + Node LTS
export NVM_DIR="$HOME/.nvm"
[ -d "$NVM_DIR" ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | PROFILE=/dev/null bash
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'

mkdir -p ~/code

# dotfiles 연결 (저장소가 홈 아래면 심볼릭 링크, 아니면 복사). 기존 파일은 .bak 백업
link() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then cp "$dst" "$dst.bak"; fi
  rm -f "$dst"
  case "$HERE" in
    "$HOME"/*) ln -s "$src" "$dst" ;;
    *)         cp "$src" "$dst" ;;
  esac
}
link "$HERE/zshrc" ~/.zshrc
link "$HERE/tmux.conf" ~/.tmux.conf

git config --global init.defaultBranch main
git config --global core.autocrlf input

echo "=== versions ==="
node -v; npm -v; zsh --version; tmux -V
echo "DONE. 새 터미널을 여세요."
