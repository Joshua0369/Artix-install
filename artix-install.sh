#!/usr/bin/env bash
# ==============================================================================
# Artix Linux Streamlined Installer (Max Performance / Dual-Boot Safe)
# System: dinit + linux-cachyos + fastfetch + btop + ly
# Default hostname: 60
# ==============================================================================

set -Eeuo pipefail

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

echo "=================================================="
echo "    Artix Linux Streamlined Installer (Dual-Boot) "
echo "=================================================="
echo ""

read -r -p "Do you want to download and set the console font to ter-v14b? (y/n) [default: y]: " SET_FONT
SET_FONT=${SET_FONT:-y}
if [[ "$SET_FONT" =~ ^[Yy]$ ]]; then
    echo "==> Installing terminus-font on live environment..."
    pacman -Sy --noconfirm terminus-font 2>/dev/null || echo "[!] Warning: Could not install terminus-font via pacman."
    setfont ter-v14b 2>/dev/null || echo "[!] Notice: ter-v14b font could not be loaded."
fi
echo ""

echo "==> Running pre-installation checks..."

if [ -f /etc/os-release ]; then source /etc/os-release; fi

if [[ "${ID:-}" != "artix" && "${ID_LIKE:-}" != *"artix"* ]]; then
    echo ""
    echo "=================================================================="
    echo "  [!] ERROR: INCORRECT OPERATING SYSTEM DETECTED"
    echo "  This installer is strictly designed for Artix Linux."
    echo "  Current system detected: ${NAME:-Unknown OS}"
    echo "  Aborting execution to prevent system damage."
    echo "=================================================================="
    exit 1
fi

if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    echo ""
    echo "=================================================================="
    echo "  [!] ERROR: NO ACTIVE INTERNET CONNECTION"
    echo "  An active network connection is required to download packages."
    echo "=================================================================="
    exit 1
fi

echo "[✓] System check passed: Artix Linux environment detected."
echo "[✓] Network check passed: Internet connection active."
echo ""

read -r -p "Would you like to continue with the installation? Type 'execute' for yes and 'n' for no: " CONTINUE_CHOICE
if [[ "$CONTINUE_CHOICE" != "execute" ]]; then
    echo "Installation aborted by user request."
    exit 0
fi
echo ""

read -r -p "Enter hostname (PC name) [default: 60]: " HOSTNAME
HOSTNAME=${HOSTNAME:-60}

read -r -p "Enter your username [default: j]: " USERNAME
USERNAME=${USERNAME:-j}

read -r -p "Enter timezone [default: Asia/Manila]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Manila}

echo ""
echo "--------------------------------------------------"
echo " Drive & Partition Selection"
echo "--------------------------------------------------"
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
echo ""

read -r -p "Have you already created your partitions using cfdisk/fdisk? (y/n) [default: y]: " PARTITIONS_READY
PARTITIONS_READY=${PARTITIONS_READY:-y}

if [[ ! "$PARTITIONS_READY" =~ ^[Yy]$ ]]; then
    echo "Please set up your partitions using 'cfdisk' first, then re-run."
    exit 1
fi

read -r -p "Enter your BOOT/EFI partition (e.g. nvme0n1p1, sda1): " BOOT_PART
read -r -p "Enter your ROOT partition (e.g. nvme0n1p5, sda2): " ROOT_PART

[[ "$BOOT_PART" != /dev/* ]] && BOOT_PART="/dev/$BOOT_PART"
[[ "$ROOT_PART" != /dev/* ]] && ROOT_PART="/dev/$ROOT_PART"

echo ""
read -r -p "Do you want to use a Swap partition? (y/n) [default: n]: " USE_SWAP
USE_SWAP=${USE_SWAP:-n}

if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    read -r -p "Enter your SWAP partition (e.g. nvme0n1p3, sda3): " SWAP_PART
    [[ "$SWAP_PART" != /dev/* ]] && SWAP_PART="/dev/$SWAP_PART"
fi

echo ""
echo "Which bootloader would you like to install?"
echo "  1) Limine (Minimal, ultra-fast UEFI bootloader)"
echo "  2) GRUB   (Standard Linux bootloader - RECOMMENDED FOR WINDOWS DUAL-BOOT)"
read -r -p "Choose bootloader (1 or 2) [default: 1]: " BOOTLOADER_CHOICE
BOOTLOADER_CHOICE=${BOOTLOADER_CHOICE:-1}

# --- NEW FORMATTING PROMPTS ---
echo ""
echo "--------------------------------------------------"
echo " Formatting Options (Dual-Boot Safe)"
echo "--------------------------------------------------"
read -r -p "Format ROOT partition ($ROOT_PART)? This WILL erase all data on it. (y/n) [default: y]: " FORMAT_ROOT
FORMAT_ROOT=${FORMAT_ROOT:-y}

read -r -p "Format BOOT partition ($BOOT_PART)? WARNING: Say 'n' if this is your Windows EFI! (y/n) [default: n]: " FORMAT_BOOT
FORMAT_BOOT=${FORMAT_BOOT:-n}

read -r -p "Enter filesystem type for BOOT (e.g. vfat, ext4) [default: vfat]: " BOOT_FS
BOOT_FS=${BOOT_FS:-vfat}

read -r -p "Enter filesystem type for ROOT (e.g. ext4, btrfs) [default: ext4]: " ROOT_FS
ROOT_FS=${ROOT_FS:-ext4}


echo ""
echo "--------------------------------------------------"
echo " SUMMARY:"
echo " Hostname      : $HOSTNAME"
echo " Username      : $USERNAME"
echo " Timezone      : $TIMEZONE"
echo " Boot Partition: $BOOT_PART ($BOOT_FS) - Format: $FORMAT_BOOT"
echo " Root Partition: $ROOT_PART ($ROOT_FS) - Format: $FORMAT_ROOT"
echo " Kernel        : linux-cachyos (AUR)"
echo " Bootloader    : $( [ "$BOOTLOADER_CHOICE" == "1" ] && echo "Limine" || echo "GRUB" )"
echo "--------------------------------------------------"
echo ""
read -r -p "Press Enter to start installation, or Ctrl+C to cancel..."

BASE_PKGS="base base-devel dinit elogind-dinit linux-firmware efibootmgr networkmanager networkmanager-dinit chrony chrony-dinit nano git terminus-font fastfetch btop ly libxcb dosfstools"

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    BASE_PKGS="$BASE_PKGS limine"
else
    BASE_PKGS="$BASE_PKGS grub os-prober"
fi

echo ""
echo "[Step 1/7] Formatting partitions (if selected)..."
if [[ "$FORMAT_BOOT" =~ ^[Yy]$ ]]; then
    mkfs.vfat -F 32 "$BOOT_PART" || { echo "Failed to format BOOT"; exit 1; }
else
    echo "Skipping format for BOOT partition ($BOOT_PART)."
fi

if [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]]; then
    mkfs.ext4 -F "$ROOT_PART" || { echo "Failed to format ROOT"; exit 1; }
else
    echo "Skipping format for ROOT partition ($ROOT_PART)."
fi

if [[ "$USE_SWAP" =~ ^[Yy]$ ]]; then
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
fi

echo "[Step 2/7] Mounting partitions..."
mount -t "$ROOT_FS" "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount -t "$BOOT_FS" "$BOOT_PART" /mnt/boot

echo "[Step 3/7] Installing base system packages..."
basestrap /mnt $BASE_PKGS

echo "[Step 4/7] Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

echo "[Step 5/7] Configuring system inside chroot..."

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
BOOT_PART="__BOOT_PART__"
BOOTLOADER_CHOICE="__BOOTLOADER_CHOICE__"

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
HOSTS

echo "==> Preparing to build linux-cachyos from AUR..."
useradd -m -G wheel -s /bin/bash builder 2>/dev/null || true
echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder

echo "==> Installing kernel build dependencies..."
pacman -S --noconfirm --needed base-devel bc pahole rust rust-bindgen rust-src clang llvm lld inetutils gnupg

echo "==> Cloning and compiling linux-cachyos (Using max CPU cores)..."
su - builder -c '
set -Eeuo pipefail
cd ~
git clone https://aur.archlinux.org/linux-cachyos.git
cd linux-cachyos
sed -i "s/pahole=[0-9:.-]*/pahole/g" PKGBUILD
# Compilation will now use ALL available CPU cores and RAM
makepkg -si --noconfirm --nodeps --skippgpcheck
'

userdel -r builder 2>/dev/null || true
rm -f /etc/sudoers.d/builder

echo "-> Set root administrator password:"
passwd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "-> Set password for user '$USERNAME':"
passwd $USERNAME

chown -R $USERNAME:$USERNAME /home/$USERNAME

sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//' /etc/sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/reboot, /usr/bin/poweroff, /usr/sbin/reboot, /usr/sbin/poweroff" > /etc/sudoers.d/reboot
chmod 440 /etc/sudoers.d/reboot

mkdir -p /etc/dinit.d/boot.d
ln -sf /etc/dinit.d/chronyd /etc/dinit.d/boot.d/
ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/

cat << 'LYSERVICE' > /etc/dinit.d/ly
type = process
command = /usr/bin/ly-dm
depends-on = login.target
restart = true
smooth-recovery = true
term-signal = HUP
options = shares-console
LYSERVICE

ln -sf /etc/dinit.d/ly /etc/dinit.d/boot.d/

mkdir -p /etc/dinit.d/config
cat << 'CONSOLECONF' > /etc/dinit.d/config/console.conf
ACTIVE_CONSOLES=/dev/tty1 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6
CONSOLECONF

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    mkdir -p /boot/EFI/BOOT
    cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/

    ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
    cat << LIMINE > /boot/limine.conf
timeout: no

/Artix Linux (CachyOS Kernel)
    protocol: linux
    path: boot():/vmlinuz-linux-cachyos
    module_path: boot():/initramfs-linux-cachyos.img
    cmdline: root=UUID=$ROOT_UUID rw quiet
LIMINE

    DISK_DEV=$(echo "$BOOT_PART" | sed -E 's/p?[0-9]+$//')
    PART_NUM=$(echo "$BOOT_PART" | grep -o '[0-9]*$')
    efibootmgr --create --disk "$DISK_DEV" --part "$PART_NUM" --label "Limine" --loader '\\EFI\\BOOT\\BOOTX64.EFI'
else
    # Enable os-prober to detect Windows
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "Chroot configuration complete!"
EOF

sed -i "s|__HOSTNAME__|$HOSTNAME|g" /mnt/root/chroot-setup.sh
sed -i "s|__USERNAME__|$USERNAME|g" /mnt/root/chroot-setup.sh
sed -i "s|__TIMEZONE__|$TIMEZONE|g" /mnt/root/chroot-setup.sh
sed -i "s|__ROOT_PART__|$ROOT_PART|g" /mnt/root/chroot-setup.sh
sed -i "s|__BOOT_PART__|$BOOT_PART|g" /mnt/root/chroot-setup.sh
sed -i "s|__BOOTLOADER_CHOICE__|$BOOTLOADER_CHOICE|g" /mnt/root/chroot-setup.sh

chmod +x /mnt/root/chroot-setup.sh

echo "[Step 6/7] Executing chroot system deployment (Building CachyOS kernel)..."
artix-chroot /mnt /root/chroot-setup.sh

echo "[Step 7/7] Cleaning up and unmounting..."
rm /mnt/root/chroot-setup.sh
umount -R /mnt

echo ""
echo "================================================--"
echo "      Installation Finished Successfully!         "
echo "  You can now remove your USB and type 'reboot'.  "
echo "================================================--"
