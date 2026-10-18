#!/usr/bin/env bash
# ==============================================================================
# Artix Linux Streamlined Installer (dinit + zen + fastfetch + btop + ly)
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
    echo "  The script broke at line $line_no with exit code $exit_code."
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

read -p "Have you already created your partitions using cfdisk/fdisk? (y/n) [default: y]: " PARTITIONS_READY
PARTITIONS_READY=${PARTITIONS_READY:-y}

if [[ ! "$PARTITIONS_READY" =~ ^[Yy]$ ]]; then
    echo "Please set up your partitions using 'cfdisk' first, then re-run."
    exit 1
fi

read -p "Enter your BOOT/EFI partition (e.g. nvme0n1p4, sda1): " BOOT_PART
read -p "Enter your ROOT partition (e.g. nvme0n1p5, sda2): " ROOT_PART

[[ "$BOOT_PART" != /dev/* ]] && BOOT_PART="/dev/$BOOT_PART"
[[ "$ROOT_PART" != /dev/* ]] && ROOT_PART="/dev/$ROOT_PART"

echo ""
read -p "Do you want to use a Swap partition or nah? (y/n) [default: n]: " USE_SWAP
USE_SWAP=${USE_SWAP:-n}

if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    read -p "Enter your SWAP partition (e.g. nvme0n1p3, sda3): " SWAP_PART
    [[ "$SWAP_PART" != /dev/* ]] && SWAP_PART="/dev/$SWAP_PART"
fi

echo ""
echo "Which bootloader would you like to install?"
echo "  1) Limine (Minimal, ultra-fast UEFI bootloader)"
echo "  2) GRUB   (Standard Linux bootloader)"
read -p "Choose bootloader (1 or 2) [default: 1]: " BOOTLOADER_CHOICE
BOOTLOADER_CHOICE=${BOOTLOADER_CHOICE:-1}

echo ""
echo "--------------------------------------------------"
echo " SUMMARY:"
echo " Hostname      : $HOSTNAME"
echo " Username      : $USERNAME"
echo " Timezone      : $TIMEZONE"
echo " Boot Partition: $BOOT_PART"
echo " Root Partition: $ROOT_PART"
echo " Bootloader    : $( [ "$BOOTLOADER_CHOICE" == "1" ] && echo "Limine" || echo "GRUB" )"
echo "--------------------------------------------------"
echo ""
read -p "Press Enter to start installation, or Ctrl+C to cancel..."


# ##################################################
# CATEGORY: PACKAGE RESOLUTION & BOOTSTRAP
# ##################################################

BASE_PKGS="base base-devel dinit elogind-dinit linux-zen linux-zen-headers linux-firmware efibootmgr networkmanager networkmanager-dinit chrony chrony-dinit nano git terminus-font fastfetch btop ly"

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    BASE_PKGS="$BASE_PKGS limine"
else
    BASE_PKGS="$BASE_PKGS grub"
fi

echo ""
echo "[Step 1/6] Formatting partitions..."
mkfs.vfat -F 32 "$BOOT_PART"
mkfs.ext4 -F "$ROOT_PART"

if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
fi

echo "[Step 2/6] Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

echo "[Step 3/6] Installing base system packages..."
basestrap /mnt $BASE_PKGS

echo "[Step 4/6] Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab


# ##################################################
# CATEGORY: CHROOT SYSTEM CONFIGURATION
# ##################################################

echo "[Step 5/6] Configuring system inside chroot..."

cat << 'EOF' > /mnt/root/chroot-setup.sh
#!/usr/bin/env bash
set -Eeuo pipefail

chroot_error() {
    local exit_code=$?
    local line_no=$1
    echo ""
    echo "=================================================================="
    echo "  [!] CHROOT INSTALLATION ERROR DETECTED"
    echo "  The chroot script broke at line $line_no with exit code $exit_code."
    echo "=================================================================="
    exit "$exit_code"
}
trap 'chroot_error $LINENO' ERR

HOSTNAME="__HOSTNAME__"
USERNAME="__USERNAME__"
TIMEZONE="__TIMEZONE__"
ROOT_PART="__ROOT_PART__"
BOOTLOADER_CHOICE="__BOOTLOADER_CHOICE__"

# Time & Locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
HOSTS

# User Creation
echo "-> Set root administrator password:"
passwd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "-> Set password for user '$USERNAME':"
passwd $USERNAME

# Fix home permissions immediately
chown -R $USERNAME:$USERNAME /home/$USERNAME

# Sudoers rules
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//' /etc/sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/reboot, /usr/bin/poweroff, /usr/sbin/reboot, /usr/sbin/poweroff" > /etc/sudoers.d/reboot
chmod 440 /etc/sudoers.d/reboot

# Dinit Services (Offline boot symlinks)
mkdir -p /etc/dinit.d/boot.d
ln -sf /etc/dinit.d/chronyd /etc/dinit.d/boot.d/
ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/
ln -sf /etc/dinit.d/ly /etc/dinit.d/boot.d/

# Ly TTY console config
mkdir -p /etc/dinit.d/config
cat << 'CONSOLECONF' > /etc/dinit.d/config/console.conf
ACTIVE_CONSOLES=/dev/tty1 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6
CONSOLECONF

# Bootloader Setup
if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    mkdir -p /boot/EFI/BOOT
    cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/

    ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
    cat << LIMINE > /boot/limine.conf
timeout: no

/Artix Linux (Zen Kernel)
    protocol: linux
    path: boot():/vmlinuz-linux-zen
    module_path: boot():/initramfs-linux-zen.img
    cmdline: root=UUID=$ROOT_UUID rw quiet
LIMINE

    DISK_DEV=$(echo "$BOOT_PART" | sed -E 's/p?[0-9]+$//')
    PART_NUM=$(echo "$BOOT_PART" | grep -o '[0-9]*$')
    efibootmgr --create --disk "$DISK_DEV" --part "$PART_NUM" --label "Limine" --loader '\\EFI\\BOOT\\BOOTX64.EFI'
else
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "Chroot configuration complete!"
EOF

# Inject variables into chroot script
sed -i "s|__HOSTNAME__|$HOSTNAME|g" /mnt/root/chroot-setup.sh
sed -i "s|__USERNAME__|$USERNAME|g" /mnt/root/chroot-setup.sh
sed -i "s|__TIMEZONE__|$TIMEZONE|g" /mnt/root/chroot-setup.sh
sed -i "s|__ROOT_PART__|$ROOT_PART|g" /mnt/root/chroot-setup.sh
sed -i "s|__BOOTLOADER_CHOICE__|$BOOTLOADER_CHOICE|g" /mnt/root/chroot-setup.sh

chmod +x /mnt/root/chroot-setup.sh

echo "==> Executing chroot system deployment..."
artix-chroot /mnt /root/chroot-setup.sh

echo "[Step 6/6] Cleaning up and unmounting..."
rm /mnt/root/chroot-setup.sh
umount -R /mnt

echo ""
echo "=================================================="
echo "      Installation Finished Successfully!         "
echo "  You can now remove your USB and type 'reboot'.  "
echo "=================================================="