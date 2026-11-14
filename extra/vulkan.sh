#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this script with sudo or as root."
  exit 1
fi

echo "[+] Checking for [multilib] repository in /etc/pacman.conf..."
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
  echo "[-] WARNING: [multilib] repository is not enabled in /etc/pacman.conf."
  echo "[-] 32-bit packages (lib32-*) will fail to install without it."
  echo "[-] Please enable [multilib] manually if you need 32-bit support."
  echo ""
fi

echo "[+] Synchronizing package databases and updating system..."
pacman -Syu --noconfirm

echo "[+] Installing Vulkan, Mesa, and Intel drivers (64-bit and 32-bit)..."
pacman -S --needed --noconfirm \
  mesa \
  vulkan-icd-loader \
  vulkan-intel \
  vulkan-tools \
  lib32-mesa \
  lib32-vulkan-icd-loader \
  lib32-vulkan-intel

echo "[+] Installation complete. Running verification..."
vulkaninfo --summary | head -n 25
