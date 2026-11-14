#!/usr/bin/env bash
# ==============================================================================
# Fast AUR Helper Installer (yay-bin + paru-bin)
# ==============================================================================

set -Eeuo pipefail

# 1. Ensure base dependencies are installed
echo "==> Installing base dependencies (git, base-devel)..."
sudo pacman -S --needed --noconfirm git base-devel

# 2. Install yay-bin (Fast binary installation)
echo "==> Cloning and installing yay-bin..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm

cd ~
rm -rf "$TEMP_DIR"

# 3. Verify yay is working
if ! command -v yay &> /dev/null; then
    echo "ERROR: yay installation failed."
    exit 1
fi
echo "==> yay installed successfully: $(yay --version | head -n1)"

# 4. Use yay to install paru-bin (Fast binary installation)
echo "==> Installing paru-bin using yay..."
yay -S --noconfirm paru-bin

# 5. Verify paru is working
if ! command -v paru &> /dev/null; then
    echo "ERROR: paru installation failed."
    exit 1
fi
echo "==> paru installed successfully: $(paru --version | head -n1)"

echo ""
echo "=================================================="
echo "  SUCCESS: yay and paru are ready to use!"
echo "=================================================="
