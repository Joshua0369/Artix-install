#!/bin/bash
set -e

# 1. Install Artix's Arch support package (provides keyring and mirrorlist-arch)
echo ">>> Installing artix-archlinux-support..."
pacman -S --needed --noconfirm artix-archlinux-support

# 2. Download Arch mirrorlist (if mirrorlist-arch does not exist or is empty)
if [ ! -s /etc/pacman.d/mirrorlist-arch ]; then
    echo ">>> Downloading Arch mirrorlist..."
    wget https://archlinux.org/mirrorlist/all/ -O /etc/pacman.d/mirrorlist-arch
    # Uncomment all Servers so pacman can use them directly (optional, will try all mirrors)
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist-arch
fi

# 3. Populate Arch keyring
echo ">>> Populating Arch keyring..."
pacman-key --populate archlinux

# 4. Safely append [extra] and [multilib] to the end of pacman.conf (if not already present)
if ! grep -q '^\[extra\]' /etc/pacman.conf; then
    echo ">>> Adding [extra] and [multilib] repositories..."
    cat >> /etc/pacman.conf <<'EOF'

# Arch repositories (added by script)
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
else
    echo ">>> [extra] already exists, skipping addition."
fi

# 5. Synchronize databases
echo ">>> Synchronizing databases..."
pacman -Syy

echo "Done. You can now install packages from [extra] or [multilib]."
