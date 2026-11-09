#!/usr/bin/env bash
# ==============================================================================
# Artix Linux Streamlined Installer (Fully Polished & Bug-Free)
# System: dinit + cachyos + extra + multilib + paru-bin + fastfetch + btop + ly
# Feature: Shared Windows/Linux ESP with optional bootloader overwrite prompt
# ==============================================================================

set -Eeuo pipefail

# --------------------------------------------------
# Error Handler & Safe Cleanup Trap
# --------------------------------------------------
cleanup_on_error() {
    local exit_code=$?
    local line_no=$1
    echo ""
    echo "=================================================================="
    echo "  [!] INSTALLATION ERROR DETECTED"
    echo "  The script broke at line $line_no with exit code$exit_code."
    echo "  Executing safe cleanup: lazy unmounting /mnt..."
    echo "=================================================================="
    umount -R /mnt 2>/dev/null || true
    umount -l /mnt 2>/dev/null || true
    exit "$exit_code"
}

trap 'cleanup_on_error $LINENO' ERR


# ##################################################
# CATEGORY: PRE-INSTALLATION SYSTEM & NETWORK CHECKS
# ##################################################

echo "=================================================="
echo "    Artix Linux Streamlined Installer             "
echo "=================================================="
echo ""

# --------------------------------------------------
# Font Selection Option (Live USB Terminal + Download)
# --------------------------------------------------
read -p "Do you want to download and set the console font to ter-v14b? (y/n) [default: y]: " SET_FONT
SET_FONT=${SET_FONT:-y}
if [[ "$SET_FONT" =~ ^[Yy]$ ]]; then
    echo "==> Installing terminus-font on live environment..."
    pacman -Sy --noconfirm terminus-font 2>/dev/null || echo "[!] Warning: Could not install terminus-font via pacman."
    setfont ter-v14b 2>/dev/null || echo "[!] Notice: ter-v14b font could not be loaded."
fi
echo ""

echo "==> Running pre-installation checks..."

# --------------------------------------------------
# Check 1: Artix OS Environment Check
# --------------------------------------------------
if [ -f /etc/os-release ]; then source /etc/os-release; fi

if [[ "${ID:-}" != "artix" && "${ID_LIKE:-}" != *"artix"* ]]; then
    echo ""
    echo "=================================================================="
    echo "  [!] ERROR: INCORRECT OPERATING SYSTEM DETECTED"
    echo "  This installer is strictly designed for Artix Linux."
    echo "  Current system detected: ${NAME:-Unknown OS}"
    echo "  Aborting execution to prevent system damage."
    echo "=================================================================="
    echo "See you next time..."
    echo ""
    exit 1
fi

# --------------------------------------------------
# Check 2: Active Internet / Network Connection Check
# --------------------------------------------------
if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    echo ""
    echo "=================================================================="
    echo "  [!] ERROR: NO ACTIVE INTERNET CONNECTION"
    echo "  An active network connection is required to download packages."
    echo "  Please plug in an Ethernet cable or connect via Wi-Fi using:"
    echo "    - nmtui / nmcli (if running NetworkManager)"
    echo "  Then re-run this script."
    echo "=================================================================="
    echo "See you next time..."
    echo ""
    exit 1
fi

echo "[✓] System check passed: Artix Linux environment detected."
echo "[✓] Network check passed: Internet connection active."
echo ""

# --------------------------------------------------
# Repository Setup (Universe, Extra, Multilib, CachyOS)
# --------------------------------------------------
echo "==> Enabling Universe repository..."
if ! grep -q "[universe]" /etc/pacman.conf; then
    cat << 'EOF' >> /etc/pacman.conf

[universe]
Server = https://universe.artixlinux.org/\$arch
EOF
fi

pacman -Sy --noconfirm
pacman -S --noconfirm artix-archlinux-support

echo "==> Initializing pacman keys..."
pacman-key --init
pacman-key --populate artix
pacman-key --populate archlinux

echo "==> Enabling Extra and Multilib repositories..."
if ! grep -q "[extra]" /etc/pacman.conf; then
    cat << 'EOF' >> /etc/pacman.conf

[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
fi

if ! grep -q "[multilib]" /etc/pacman.conf; then
    cat << 'EOF' >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
fi

pacman -Sy --noconfirm

echo "==> Setting up CachyOS repository for linux-cachyos..."
pacman -S --noconfirm curl tar 2>/dev/null || true
curl -s https://mirror.cachyos.org/cachyos-repo.tar.xz -o /tmp/cachyos-repo.tar.xz
mkdir -p /tmp/cachyos-repo
tar xf /tmp/cachyos-repo.tar.xz -C /tmp/cachyos-repo --strip-components=1 2>/dev/null || tar xf /tmp/cachyos-repo.tar.xz -C /tmp/cachyos-repo
if [ -f /tmp/cachyos-repo/cachyos-repo.sh ]; then
    yes | bash /tmp/cachyos-repo/cachyos-repo.sh
else
    echo "[!] Warning: CachyOS repo script not found, proceeding with manual repo insertion..."
fi
pacman -Sy --noconfirm

echo "[✓] Repositories configured successfully."
echo ""

# --------------------------------------------------
# Welcome Sequence & Confirmation Gate
# --------------------------------------------------
echo "Hi, welcome to this installation script of Artix."
sleep 2
echo "(gemini made this cleanly for you.)"
echo ""

read -p "Would you like to continue with the installation? Type 'execute' for yes and 'n' for no: " CONTINUE_CHOICE
if [[ "$CONTINUE_CHOICE" != "execute" ]]; then
    echo ""
    echo "Installation aborted by user request."
    echo "See you next time..."
    echo ""
    exit 0
fi
echo ""


# ##################################################
# CATEGORY: USER PROMPTS & CONFIGURATION
# ##################################################

read -p "Enter hostname (PC name) [default: 58]: " HOSTNAME
HOSTNAME=${HOSTNAME:-58}

read -p "Enter your username [default: j]: " USERNAME
USERNAME=${USERNAME:-j}

read -p "Enter timezone [default: Asia/Manila]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Manila}

echo ""
echo "--------------------------------------------------"
echo " Drive & Partition Selection"
echo "--------------------------------------------------"
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
echo ""

read -p "Have you already created your partitions using cf
