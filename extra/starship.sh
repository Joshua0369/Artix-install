#!/usr/bin/env bash
#
# starship.sh — Bootstrap Zsh + Starship + Alacritty
# Safe to re-run. Backs up existing configs before overwriting.
#
set -euo pipefail

# ─── Colors & Helpers ────────────────────────────────────────────────
readonly C_RESET='\033[0m' C_INFO='\033[1;34m' C_OK='\033[1;32m' C_WARN='\033[1;33m' C_ERR='\033[1;31m'
info()  { printf "${C_INFO}[*]${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_OK}[+]${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_WARN}[!]${C_RESET} %s\n" "$*"; }
die()   { printf "${C_ERR}[x]${C_RESET} %s\n" "$*" >&2; exit 1; }

trap 'die "Unexpected failure on line $LINENO"' ERR

# ─── Preflight Checks ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do NOT run this as root. Run as your normal user; it will sudo when needed."
command -v pacman &>/dev/null || die "This script targets Arch/Artix (pacman). Aborting."
command -v sudo   &>/dev/null || die "sudo is required but not installed."

info "Requesting sudo privileges up front..."
sudo -v

# Keep sudo alive during long operations
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
readonly SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# ─── Config ─────────────────────────────────────────────────────────
readonly PACKAGES=(
  zsh git curl starship alacritty
  ttf-jetbrains-mono-nerd
  zsh-completions
)
readonly ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
readonly ZSHRC="$HOME/.zshrc"
readonly ALACRITTY_DIR="$HOME/.config/alacritty"
readonly ALACRITTY_CFG="$ALACRITTY_DIR/alacritty.toml"
readonly ZSH_PATH="$(command -v zsh || echo /usr/bin/zsh)"
readonly BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"

# ─── 1. Packages ────────────────────────────────────────────────────
install_packages() {
  info "Syncing package database and installing packages..."
  sudo pacman -Syu --noconfirm
  sudo pacman -S --noconfirm --needed "${PACKAGES[@]}"
  ok "Packages installed."
}

# ─── 2. Default shell ───────────────────────────────────────────────
set_default_shell() {
  info "Ensuring zsh is a valid login shell..."
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null

  local current
  current="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current" == "$ZSH_PATH" ]]; then
    ok "Login shell already set to $ZSH_PATH."
  else
    info "Changing login shell from $current to $ZSH_PATH..."
    sudo chsh -s "$ZSH_PATH" "$USER"
    ok "Login shell changed. (Takes effect on next login.)"
  fi
}

# ─── 3. Zinit ───────────────────────────────────────────────────────
install_zinit() {
  if [[ -d "$ZINIT_HOME/.git" ]]; then
    ok "Zinit already installed at $ZINIT_HOME."
  else
    info "Installing Zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    ok "Zinit installed."
  fi
}

# ─── 4. .zshrc ──────────────────────────────────────────────────────
write_zshrc() {
  if [[ -f "$ZSHRC" ]]; then
    warn "Existing $ZSHRC found — backing up to ${ZSHRC}${BACKUP_SUFFIX}"
    cp -a "$ZSHRC" "${ZSHRC}${BACKUP_SUFFIX}"
  fi

  info "Writing $ZSHRC..."
  cat > "$ZSHRC" <<'EOF'
# ── Zinit ───────────────────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab

autoload -Uz compinit && compinit

# ── History (persists across sessions) ──────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt INC_APPEND_HISTORY   # write each command immediately
setopt SHARE_HISTORY        # share across open terminals
setopt HIST_IGNORE_DUPS     # no consecutive duplicates
setopt HIST_IGNORE_SPACE    # ignore commands starting with space
setopt HIST_VERIFY          # show expanded history before running

# ── Prompt ──────────────────────────────────────────────────────────
eval "$(starship init zsh)"
EOF
  ok ".zshrc written."
}

# ─── 5. Alacritty ───────────────────────────────────────────────────
write_alacritty() {
  mkdir -p "$ALACRITTY_DIR"

  if [[ -f "$ALACRITTY_CFG" ]]; then
    warn "Existing $ALACRITTY_CFG found — backing up to ${ALACRITTY_CFG}${BACKUP_SUFFIX}"
    cp -a "$ALACRITTY_CFG" "${ALACRITTY_CFG}${BACKUP_SUFFIX}"
  fi

  info "Writing $ALACRITTY_CFG..."
  cat > "$ALACRITTY_CFG" <<EOF
[terminal.shell]
program = "$ZSH_PATH"

[font]
size = 12.0
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
EOF
  ok "Alacritty config written."
}

# ─── 6. Verify ──────────────────────────────────────────────────────
verify() {
  info "Verifying installation..."
  local failed=0

  for bin in zsh starship alacritty; do
    if command -v "$bin" &>/dev/null; then
      ok "$bin found at $(command -v "$bin")"
    else
      warn "$bin NOT found in PATH"
      ((failed++))
    fi
  done

  [[ -f "$ZSHRC" ]]        || { warn ".zshrc missing";        ((failed++)); }
  [[ -f "$ALACRITTY_CFG" ]] || { warn "alacritty.toml missing"; ((failed++)); }
  [[ -d "$ZINIT_HOME" ]]    || { warn "Zinit missing";         ((failed++)); }

  if (( failed > 0 )); then
    warn "Verification finished with $failed issue(s)."
  else
    ok "All checks passed."
  fi
}

# ─── Main ───────────────────────────────────────────────────────────
main() {
  info "Starting starship.sh bootstrap..."
  install_packages
  set_default_shell
  install_zinit
  write_zshrc
  write_alacritty
  verify

  echo
  ok "Done!"
  echo "  • Close ALL Alacritty windows and reopen."
  echo "  • Run: exec zsh   (or log out/in for the shell change to apply)"
  echo "  • History backups (if any): ${ZSHRC}${BACKUP_SUFFIX} / ${ALACRITTY_CFG}${BACKUP_SUFFIX}"
}

main "$@"
