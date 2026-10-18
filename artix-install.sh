#!/usr/bin/env bash
# ==============================================================================
# Artix Linux Custom Interactive Installer (Fixed dwm & AUR handling)
# System: dinit + linux-zen | Optional: Zsh, PipeWire, WMs & Dotfiles, Ly, Fastfetch, Alacritty
# ==============================================================================

set -e

# ##################################################
# CATEGORY: PRE-INSTALLATION SYSTEM & NETWORK CHECKS
# ##################################################

echo "=================================================="
echo "    Artix Linux Custom Interactive Installer      "
echo "=================================================="
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
    echo "    - connmanctl (if running connman)"
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
# Welcome Sequence & Confirmation Gate
# --------------------------------------------------
echo "Hi, welcome to this installing script of artix."
sleep 3
echo "(gemini made this btw.)"
sleep 3
echo "I would rather AI handle my code than art."
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
# CATEGORY: USER PROMPTS & CONFIGURATION (FIRST THING)
# ##################################################

# --------------------------------------------------
# Section 1: User Identity, Timezone & WM Selection
# --------------------------------------------------
read -p "Enter hostname (PC name) [default: 58]: " HOSTNAME
HOSTNAME=${HOSTNAME:-58}

read -p "Enter your username [default: j]: " USERNAME
USERNAME=${USERNAME:-j}

read -p "Enter timezone [default: Asia/Manila]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Manila}

echo ""
echo "--------------------------------------------------"
echo " Section 1.1: Window Manager (WM) / Compositor"
echo "--------------------------------------------------"
echo "Which Window Manager would you like to install?"
echo "  1) dwm     (Lightweight X11 tiling window manager)"
echo "  2) oxwm    (Minimalist window manager)"
echo "  3) sway    (Wayland tiling compositor)"
echo "  4) mangowc (Minimalist Wayland compositor/WM)"
echo "  5) bspwm   (X11 tiling window manager with gh0stzk dotfiles)"
echo "  6) vxwm    (Minimalist window manager with ceapeapea dotfiles)"
echo "  7) ALL IN  (Install all of them: dwm, oxwm, sway, mangowc, bspwm, vxwm)"
read -p "Choose WM option (1-7) [default: 1]: " WM_CHOICE
WM_CHOICE=${WM_CHOICE:-1}

# --------------------------------------------------
# Section 1.2: Yes to All Optional Features Option
# --------------------------------------------------
echo ""
read -p "Do you want to enable ALL optional components automatically? (y/n) [default: n]: " YES_TO_ALL
YES_TO_ALL=${YES_TO_ALL:-n}

if [[ "$YES_TO_ALL" =~ ^[Yy]$ ]]; then
    INSTALL_DWM_CONFIG="y"
    INSTALL_BSPWM_CONFIG="y"
    INSTALL_VXWM_CONFIG="y"
    INSTALL_ZSH="y"
    INSTALL_PIPEWIRE="y"
    INSTALL_LY="y"
    INSTALL_FASTFETCH="y"
    INSTALL_ALACRITTY="y"
else
    INSTALL_DWM_CONFIG="n"
    INSTALL_BSPWM_CONFIG="n"
    INSTALL_VXWM_CONFIG="n"
    if [ "$WM_CHOICE" == "1" ] || [ "$WM_CHOICE" == "7" ]; then
        echo ""
        echo "Do you want to install mich-murphy's dwm dotfiles config?"
        read -p "Install dwm dotfiles (mich-murphy/dwm-dotfiles)? (y/n) [default: y]: " INSTALL_DWM_CONFIG
        INSTALL_DWM_CONFIG=${INSTALL_DWM_CONFIG:-y}
    fi
    if [ "$WM_CHOICE" == "5" ] || [ "$WM_CHOICE" == "7" ]; then
        echo ""
        echo "Do you want to install gh0stzk's bspwm dotfiles config?"
        read -p "Install bspwm dotfiles (gh0stzk/dotfiles)? (y/n) [default: y]: " INSTALL_BSPWM_CONFIG
        INSTALL_BSPWM_CONFIG=${INSTALL_BSPWM_CONFIG:-y}
    fi
    if [ "$WM_CHOICE" == "6" ] || [ "$WM_CHOICE" == "7" ]; then
        echo ""
        echo "Do you want to install ceapeapea's vxwm dotfiles config?"
        read -p "Install vxwm dotfiles (ceapeapea/vxwm-dotfiles)? (y/n) [default: y]: " INSTALL_VXWM_CONFIG
        INSTALL_VXWM_CONFIG=${INSTALL_VXWM_CONFIG:-y}
    fi
fi

echo ""
echo "--------------------------------------------------"
echo " Section 2: Drive & Partition Selection"
echo "--------------------------------------------------"
echo "Current disk layout on this machine:"
echo ""
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
echo ""

# --------------------------------------------------
# Section 3: Partition Readiness Check
# --------------------------------------------------
read -p "Have you already created your partitions using cfdisk/fdisk? (y/n) [default: y]: " PARTITIONS_READY
PARTITIONS_READY=${PARTITIONS_READY:-y}

if [[ ! "$PARTITIONS_READY" =~ ^[Yy]$ ]]; then
    echo ""
    echo "=================================================================="
    echo "  [!] CANCELLING INSTALLATION"
    echo "  Please use 'cfdisk /dev/your_drive' to set up your partitions"
    echo "  first, then re-run this script."
    echo "=================================================================="
    echo "See you next time..."
    echo ""
    exit 1
fi

# --------------------------------------------------
# Section 4: Dynamic Partition Device Selection
# --------------------------------------------------
read -p "Enter your BOOT/EFI partition (e.g. nvme0n1p4, sda1): " BOOT_PART
read -p "Enter your ROOT partition (e.g. nvme0n1p5, sda2): " ROOT_PART

# Ensure full path formatting (/dev/...)
[[ "$BOOT_PART" != /dev/* ]] && BOOT_PART="/dev/$BOOT_PART"
[[ "$ROOT_PART" != /dev/* ]] && ROOT_PART="/dev/$ROOT_PART"

# --------------------------------------------------
# Section 5: Swap Choice ("Swap or nah")
# --------------------------------------------------
echo ""
read -p "Do you want to use a Swap partition or nah? (y/n) [default: n]: " USE_SWAP
USE_SWAP=${USE_SWAP:-n}

if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    read -p "Enter your SWAP partition (e.g. nvme0n1p3, sda3): " SWAP_PART
    [[ "$SWAP_PART" != /dev/* ]] && SWAP_PART="/dev/$SWAP_PART"
fi

echo ""
echo "--------------------------------------------------"
echo " Section 6: Optional Component Selection"
echo "--------------------------------------------------"

# --------------------------------------------------
# Section 7: Bootloader Choice
# --------------------------------------------------
echo "Which bootloader would you like to install?"
echo "  1) Limine (Minimal, ultra-fast UEFI bootloader)"
echo "  2) GRUB   (Standard Linux bootloader)"
read -p "Choose bootloader (1 or 2) [default: 1]: " BOOTLOADER_CHOICE
BOOTLOADER_CHOICE=${BOOTLOADER_CHOICE:-1}

# --------------------------------------------------
# Individual Prompts (Skipped if Yes to All was selected)
# --------------------------------------------------
if [[ ! "$YES_TO_ALL" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Do you want Zsh as your default shell?"
    echo "  -> Includes gh0stzk's dotfiles, autosuggestions, eza, bat, and fzf-tab."
    read -p "Install Zsh and dotfiles? (y/n) [default: y]: " INSTALL_ZSH
    INSTALL_ZSH=${INSTALL_ZSH:-y}

    echo ""
    echo "Do you want PipeWire low-latency audio?"
    echo "  -> Includes pwvucontrol and a 64-sample (~1.33ms) gaming audio config."
    read -p "Install PipeWire audio stack? (y/n) [default: y]: " INSTALL_PIPEWIRE
    INSTALL_PIPEWIRE=${INSTALL_PIPEWIRE:-y}

    echo ""
    echo "Do you want to install Ly console display manager?"
    echo "  -> Configures custom dinit service file & resolves TTY2 agetty conflicts."
    read -p "Install Ly display manager? (y/n) [default: y]: " INSTALL_LY
    INSTALL_LY=${INSTALL_LY:-y}

    echo ""
    echo "Do you want Fastfetch with awesome-fastfetch configuration?"
    read -p "Install Fastfetch & awesome-fastfetch config? (y/n) [default: y]: " INSTALL_FASTFETCH
    INSTALL_FASTFETCH=${INSTALL_FASTFETCH:-y}

    echo ""
    echo "Do you want Alacritty terminal configured with JetBrains Mono (Size 14)?"
    read -p "Install Alacritty & config? (y/n) [default: y]: " INSTALL_ALACRITTY
    INSTALL_ALACRITTY=${INSTALL_ALACRITTY:-y}
fi

# --------------------------------------------------
# Section 13: Summary Review
# --------------------------------------------------
echo ""
echo "--------------------------------------------------"
echo " SUMMARY OF INSTALLATION SETTINGS:"
echo " Hostname      : $HOSTNAME"
echo " Username      : $USERNAME"
echo " Timezone      : $TIMEZONE"
case $WM_CHOICE in
    1) echo " Window Manager: dwm" ;;
    2) echo " Window Manager: oxwm" ;;
    3) echo " Window Manager: sway" ;;
    4) echo " Window Manager: mangowc" ;;
    5) echo " Window Manager: bspwm" ;;
    6) echo " Window Manager: vxwm" ;;
    7) echo " Window Manager: ALL IN (dwm, oxwm, sway, mangowc, bspwm, vxwm)" ;;
esac
echo " dwm Dotfiles  : $INSTALL_DWM_CONFIG"
echo " bspwm Dotfiles: $INSTALL_BSPWM_CONFIG"
echo " vxwm Dotfiles : $INSTALL_VXWM_CONFIG"
echo " Boot Partition: $BOOT_PART"
echo " Root Partition: $ROOT_PART"
if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    echo " Swap Partition: $SWAP_PART"
else
    echo " Swap          : Disabled (No swap)"
fi
if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    echo " Bootloader    : Limine (Timeout: Disabled / No autoboot)"
else
    echo " Bootloader    : GRUB"
fi
echo " Custom Zsh    : $INSTALL_ZSH"
echo " PipeWire      : $INSTALL_PIPEWIRE"
echo " Ly Display Mgr: $INSTALL_LY"
echo " Fastfetch     : $INSTALL_FASTFETCH"
echo " Alacritty     : $INSTALL_ALACRITTY"
echo " AUR Helpers   : yay & paru (Automated Build)"
echo "--------------------------------------------------"
echo ""
read -p "Press Enter to start formatting and installation, or Ctrl+C to cancel..."


# ##################################################
# CATEGORY: PACKAGE RESOLUTION
# ##################################################

BASE_PKGS="base base-devel dinit elogind-dinit linux-zen linux-zen-headers linux-firmware efibootmgr networkmanager networkmanager-dinit chrony chrony-dinit nano git"

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    BASE_PKGS="$BASE_PKGS limine"
else
    BASE_PKGS="$BASE_PKGS grub"
fi

if [[ "$INSTALL_ZSH" =~ ^[Yy]$ ]]; then
    BASE_PKGS="$BASE_PKGS zsh eza bat zsh-syntax-highlighting zsh-history-substring-search"
fi

if [[ "$INSTALL_PIPEWIRE" =~ ^[Yy]$ ]]; then
    BASE_PKGS="$BASE_PKGS pipewire pipewire-pulse pipewire-alsa wireplumber pwvucontrol"
fi

if [[ "$INSTALL_LY" =~ ^[Yy]$ ]]; then
    BASE_PKGS="$BASE_PKGS ly"
fi

if [[ "$INSTALL_FASTFETCH" =~ ^[Yy]$ ]]; then
    BASE_PKGS="$BASE_PKGS fastfetch"
fi

if [[ "$INSTALL_ALACRITTY" =~ ^[Yy]$ ]]; then
    BASE_PKGS="$BASE_PKGS alacritty ttf-jetbrains-mono"
fi

# Add official repository WMs & X11 prerequisites if selected
if [ "$WM_CHOICE" == "1" ] || [ "$WM_CHOICE" == "7" ]; then
    BASE_PKGS="$BASE_PKGS xorg-server xorg-xinit xf86-input-libinput"
fi
if [ "$WM_CHOICE" == "5" ] || [ "$WM_CHOICE" == "7" ]; then
    BASE_PKGS="$BASE_PKGS bspwm sxhkd polybar rofi feh picom xorg-server xorg-xinit xf86-input-libinput"
fi
if [ "$WM_CHOICE" == "3" ] || [ "$WM_CHOICE" == "7" ]; then
    BASE_PKGS="$BASE_PKGS sway swaybg swaylock swayidle foot"
fi


# ##################################################
# CATEGORY: DISK OPERATIONS & BOOTSTRAP
# ##################################################

# --------------------------------------------------
# Section 14: Formatting Selected Partitions
# --------------------------------------------------
echo ""
echo "[Step 1/34] Formatting selected drive partitions..."
mkfs.vfat -F 32 "$BOOT_PART"
mkfs.ext4 -F "$ROOT_PART"

if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    echo "[Step 2/34] Formatting and enabling Swap partition..."
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
else
    echo "[Step 2/34] Skipping Swap partition setup (Disabled)..."
fi

# --------------------------------------------------
# Section 15: Mounting Partitions
# --------------------------------------------------
echo "[Step 3/34] Mounting target file system drives..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

# --------------------------------------------------
# Section 16: Base System Installation (Basestrap)
# --------------------------------------------------
echo "[Step 4/34] Downloading and installing base system packages..."
basestrap /mnt $BASE_PKGS

# --------------------------------------------------
# Section 17: Global Zsh Plugin Setup
# --------------------------------------------------
if [[ "$INSTALL_ZSH" =~ ^[Yy]$ ]]; then
    echo "[Step 5/34] Cloning fzf-tab Zsh plugin..."
    mkdir -p /mnt/usr/share/zsh/plugins/fzf-tab-git
    git clone https://github.com/Aloxaf/fzf-tab.git /mnt/usr/share/zsh/plugins/fzf-tab-git
else
    echo "[Step 5/34] Skipping fzf-tab plugin setup..."
fi

# --------------------------------------------------
# Section 18: Filesystem Table Generation
# --------------------------------------------------
echo "[Step 6/34] Generating fstab file systems table..."
fstabgen -U /mnt >> /mnt/etc/fstab


# ##################################################
# CATEGORY: CHROOT SYSTEM CONFIGURATION
# ##################################################

echo "[Step 7/34] Preparing chroot system configuration script..."

cat << EOF > /mnt/root/chroot-setup.sh
#!/usr/bin/env bash
set -e

HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
TIMEZONE="$TIMEZONE"
INSTALL_ZSH="$INSTALL_ZSH"
INSTALL_PIPEWIRE="$INSTALL_PIPEWIRE"
INSTALL_LY="$INSTALL_LY"
INSTALL_FASTFETCH="$INSTALL_FASTFETCH"
INSTALL_ALACRITTY="$INSTALL_ALACRITTY"
INSTALL_DWM_CONFIG="$INSTALL_DWM_CONFIG"
INSTALL_BSPWM_CONFIG="$INSTALL_BSPWM_CONFIG"
INSTALL_VXWM_CONFIG="$INSTALL_VXWM_CONFIG"
WM_CHOICE="$WM_CHOICE"
ROOT_PART="$ROOT_PART"
BOOTLOADER_CHOICE="$BOOTLOADER_CHOICE"

# --------------------------------------------------
# Section 19: Time & Locale Configuration
# --------------------------------------------------
echo "[Step 8/34] Setting up system time and timezone (\$TIMEZONE)..."
ln -sf /usr/share/zoneinfo/\$TIMEZONE /etc/localtime
hwclock --systohc

echo "[Step 9/34] Generating US UTF-8 locale..."
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --------------------------------------------------
# Section 20: Hostname & Network Hosts Configuration
# --------------------------------------------------
echo "[Step 10/34] Setting system hostname to \$HOSTNAME..."
echo "\$HOSTNAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   \$HOSTNAME.localdomain   \$HOSTNAME
HOSTS

# --------------------------------------------------
# Section 21: User & Password Setup
# --------------------------------------------------
USER_SHELL="/bin/bash"
if [[ "\$INSTALL_ZSH" =~ ^[Yy]\$ ]]; then
    USER_SHELL="/bin/zsh"
fi

echo "[Step 11/34] Creating user account '\$USERNAME'..."
echo "-> Set root administrator password:"
passwd
useradd -m -G wheel -s \$USER_SHELL \$USERNAME
echo "-> Set password for user '\$USERNAME':"
passwd \$USERNAME

# --------------------------------------------------
# Section 22: Privilege Escalation & Sudoers Rules (Passwordless for Wheel)
# --------------------------------------------------
echo "[Step 12/34] Granting administrative (sudo) privileges..."
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//' /etc/sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "[Step 13/34] Configuring passwordless reboot and poweroff for \$USERNAME..."
echo "\$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/reboot, /usr/bin/poweroff, /usr/sbin/reboot, /usr/sbin/poweroff" > /etc/sudoers.d/reboot
chmod 440 /etc/sudoers.d/reboot

# --------------------------------------------------
# Section 23: Dinit Service Enablement (Chronyd & NetworkManager)
# --------------------------------------------------
echo "[Step 14/34] Enabling internet clock synchronization & network manager..."
dinitctl enable chronyd
dinitctl enable NetworkManager

# --------------------------------------------------
# Section 24: Ly Display Manager Configuration & Service
# --------------------------------------------------
if [[ "\$INSTALL_LY" =~ ^[Yy]\$ ]]; then
    echo "[Step 15/34] Creating Dinit service definition for Ly display manager..."
    mkdir -p /etc/dinit.d
    cat << 'LYSERVICE' > /etc/dinit.d/ly
type = process
restart = true
smooth-recovery = true
command = /usr/bin/ly
depends-on = login.target
termsignal = HUP
options = shares-console
LYSERVICE

    echo "[Step 16/34] Adjusting TTY console allocation to prevent Ly conflicts..."
    mkdir -p /etc/dinit.d/config
    cat << 'CONSOLECONF' > /etc/dinit.d/config/console.conf
ACTIVE_CONSOLES=/dev/tty1 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6
CONSOLECONF

    echo "[Step 17/34] Enabling Ly display manager in dinit..."
    dinitctl enable ly
else
    echo "[Step 15/34] Skipping Ly dinit service creation..."
    echo "[Step 16/34] Skipping console.conf TTY reallocation..."
    echo "[Step 17/34] Skipping Ly service enablement..."
fi

# --------------------------------------------------
# Section 25: PipeWire Low-Latency Configuration
# --------------------------------------------------
if [[ "\$INSTALL_PIPEWIRE" =~ ^[Yy]\$ ]]; then
    echo "[Step 18/34] Writing 64-sample (~1.33ms) low-latency PipeWire configuration..."
    mkdir -p /home/\$USERNAME/.config/pipewire/pipewire.conf.d
    cat << 'PIPEWIRE' > /home/\$USERNAME/.config/pipewire/pipewire.conf.d/10-low-latency.conf
context.properties = {
    default.clock.rate          = 48000
    default.clock.allowed-rates = [ 48000 96000 ]
    default.clock.quantum       = 64
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 128
}
PIPEWIRE
else
    echo "[Step 18/34] Skipping PipeWire configuration..."
fi

# --------------------------------------------------
# Section 26: Xinitrc Configuration for X11 WMs (Ly session support)
# --------------------------------------------------
if [ "\$WM_CHOICE" == "1" ] || [ "\$WM_CHOICE" == "2" ] || [ "\$WM_CHOICE" == "5" ] || [ "\$WM_CHOICE" == "6" ] || [ "\$WM_CHOICE" == "7" ]; then
    echo "[Step 19/34] Configuring .xinitrc session runner for X11 WMs..."
    DEFAULT_WM
