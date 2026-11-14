#!/usr/bin/env bash
set -e

# 1. Install all packages (including JetBrainsMono Nerd Font)
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm --needed \
    zsh git curl starship alacritty \
    ttf-jetbrains-mono-nerd

# 2. Add zsh to valid shells and switch default login shell
ZSH_PATH="$(which zsh)"
grep -q "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
sudo chsh -s "$ZSH_PATH" "$USER"

# 3. Install Zinit
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[ -d "$ZINIT_HOME" ] || git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"

# 4. Write .zshrc
cat > "$HOME/.zshrc" <<'EOF'
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab
autoload -Uz compinit && compinit
eval "$(starship init zsh)"
EOF

# 5. Force Alacritty to launch zsh and use JetBrainsMono Nerd Font
ALACRITTY_DIR="$HOME/.config/alacritty"
mkdir -p "$ALACRITTY_DIR"
cat > "$ALACRITTY_DIR/alacritty.toml" <<EOF
[terminal.shell]
program = "/usr/bin/zsh"

[font]
size = 12.0
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
EOF

echo "Done. Close ALL Alacritty windows and reopen."
