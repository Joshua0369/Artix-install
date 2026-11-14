#!/usr/bin/env bash
# ==============================================================================
# Artix Linux Streamlined Installer (Zen Kernel / TUI Edition)
# System: dinit + linux-zen + fastfetch + btop + ly
# ==============================================================================

set -Eeuo pipefail

# --------------------------------------------------
# Error Handler & Safe Cleanup Trap
# --------------------------------------------------
cleanup_on_error() {
    local exit_code=$?
    local line_no=$1
    clear
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

# --------------------------------------------------
# Ensure whiptail is installed
# --------------------------------------------------
if ! command -v whiptail &> /dev/null; then
    echo "Installing whiptail for TUI..."
    pacman -Sy --noconfirm libnewt >/dev/null 2>&1
fi

# --------------------------------------------------
# Pre-Installation Checks
# --------------------------------------------------
if [ -f /etc/os-release ]; then source /etc/os-release; fi
if [[ "${ID:-}" != "artix" && "${ID_LIKE:-}" != *"artix"* ]]; then
    whiptail --title "ERROR" --msgbox "Incorrect OS. This script is strictly for Artix Linux." 10 60
    exit 1
fi

if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    whiptail --title "ERROR" --msgbox "No active internet connection detected.\nPlease connect and try again." 10 60
    exit 1
fi

# --------------------------------------------------
# TUI: Welcome
# --------------------------------------------------
whiptail --title "Artix Linux Installer (Zen)" --msgbox "Welcome to the Artix Linux TUI Installer.\n\nThis will install Artix with the Zen kernel, dinit, and the Ly display manager.\n\nWARNING: This will format the partitions you select." 15 60

# --------------------------------------------------
# TUI: User Info
# --------------------------------------------------
HOSTNAME=$(whiptail --title "Hostname" --inputbox "Enter a hostname for your PC:" 10 60 "60" 3>&1 1>&2 2>&3) || exit 1
USERNAME=$(whiptail --title "Username" --inputbox "Enter your primary username:" 10 60 "j" 3>&1 1>&2 2>&3) || exit 1
TIMEZONE=$(whiptail --title "Timezone" --inputbox "Enter your timezone (e.g., Asia/Manila):" 10 60 "Asia/Manila" 3>&1 1>&2 2>&3) || exit 1

# --------------------------------------------------
# TUI: Partition Selection
# --------------------------------------------------
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS > /tmp/lsblk_out.txt
whiptail --title "Available Drives" --textbox /tmp/lsblk_out.txt 20 70

BOOT_PART=$(whiptail --title "Boot Partition" --inputbox "Enter your BOOT/EFI partition (e.g., sda1, nvme0n1p1):" 10 60 "" 3>&1 1>&2 2>&3) || exit 1
[[ "$BOOT_PART" != /dev/* ]] && BOOT_PART="/dev/$BOOT_PART"

ROOT_PART=$(whiptail --title "Root Partition" --inputbox "Enter your ROOT partition (e.g., sda2, nvme0n1p4):" 10 60 "" 3>&1 1>&2 2>&3) || exit 1
[[ "$ROOT_PART" != /dev/* ]] && ROOT_PART="/dev/$ROOT_PART"

# --------------------------------------------------
# TUI: Formatting Confirmation
# --------------------------------------------------
if (whiptail --title "Format ROOT?" --yesno "Do you want to FORMAT $ROOT_PART as ext4?\n\nWARNING: All data on this partition will be lost!" 10 60); then
    FORMAT_ROOT="y"
else
    FORMAT_ROOT="n"
fi

if (whiptail --title "Format BOOT?" --yesno "Do you want to FORMAT $BOOT_PART as FAT32?\n\nWARNING: Say NO if this is your Windows EFI partition!" 10 60 --defaultno); then
    FORMAT_BOOT="y"
else
    FORMAT_BOOT="n"
fi

# --------------------------------------------------
# TUI: Bootloader Choice
# --------------------------------------------------
BOOTLOADER_CHOICE=$(whiptail --title "Bootloader" --menu "Choose your bootloader:" 15 60 2 \
"1" "Limine (Minimal, ultra-fast)" \
"2" "GRUB (Standard, RECOMMENDED for Windows dual-boot)" 3>&1 1>&2 2>&3) || exit 1

# --------------------------------------------------
# TUI: Summary Confirmation
# --------------------------------------------------
whiptail --title "Installation Summary" --yesno "Hostname: $HOSTNAME\nUsername: $USERNAME\nTimezone: $TIMEZONE\n\nBoot Partition: $BOOT_PART (Format: $FORMAT_BOOT)\nRoot Partition: $ROOT_PART (Format: $FORMAT_ROOT)\n\nBootloader: $( [ "$BOOTLOADER_CHOICE" == "1" ] && echo "Limine" || echo "GRUB" )\n\nProceed with installation?" 18 60 || exit 1

# --------------------------------------------------
# Installation Begins
# --------------------------------------------------
clear
BASE_PKGS="base base-devel dinit elogind-dinit linux-firmware efibootmgr networkmanager networkmanager-dinit chrony chrony-dinit nano git terminus-font fastfetch btop libxcb dosfstools ly ly-dinit xorg-server xorg-xinit xorg-xauth"

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    BASE_PKGS="$BASE_PKGS limine"
else
    BASE_PKGS="$BASE_PKGS grub os-prober"
fi

echo "[Step 1/6] Formatting partitions..."
if [[ "$FORMAT_BOOT" =~ ^[Yy]$ ]]; then mkfs.vfat -F 32 "$BOOT_PART"; fi
if [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]]; then mkfs.ext4 -F "$ROOT_PART"; fi

echo "[Step 2/6] Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

echo "[Step 3/6] Installing base system..."
basestrap /mnt $BASE_PKGS

echo "[Step 4/6] Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

echo "[Step 5/6] Configuring system inside chroot..."

cat << 'EOF' > /mnt/root/chroot-setup.sh
#!/usr/bin/env bash
set -Eeuo pipefail

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

echo "==> Installing linux-zen kernel..."
pacman -S --noconfirm --needed linux-zen linux-zen-headers

echo "==> Forcing NVMe driver into initramfs..."
sed -i 's/^MODULES=(\(.*\))/MODULES=(nvme \1)/' /etc/mkinitcpio.conf
sed -i 's/  */ /g' /etc/mkinitcpio.conf
mkinitcpio -P

echo "-> Set root password:"
passwd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "-> Set password for $USERNAME:"
passwd $USERNAME

chown -R $USERNAME:$USERNAME /home/$USERNAME
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//' /etc/sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

mkdir -p /etc/dinit.d/boot.d
ln -sf /etc/dinit.d/chronyd /etc/dinit.d/boot.d/
ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/

# --- Xorg and Ly Fixes ---
echo "==> Applying Xorg and Ly permission fixes..."
mkdir -p /etc/X11
printf "allowed_users = anybody\nneeds_root_rights = yes\n" > /etc/X11/Xwrapper.config
mkdir -p /etc/dinit.d/config
echo 'ACTIVE_CONSOLES="/dev/tty[2-6]"' > /etc/dinit.d/config/console.conf
ln -sf /etc/dinit.d/ly /etc/dinit.d/boot.d/

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    if [ ! -f /boot/EFI/BOOT/BOOTX64.EFI ]; then
        mkdir -p /boot/EFI/BOOT
        cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
    fi

    ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
    cat << LIMINE > /boot/limine.conf
timeout: no
/Artix Linux (Zen Kernel)
    protocol: linux
    path: boot():/vmlinuz-linux-zen
    module_path: boot():/initramfs-linux-zen.img
    cmdline: root=UUID=$ROOT_UUID rw quiet
LIMINE

    for entry in $(efibootmgr | grep "Limine" | sed -E 's/Boot([0-9A-Fa-f]{4}).*/\1/'); do
        efibootmgr -b "$entry" -B >/dev/null 2>&1 || true
    done

    DISK_DEV=$(echo "$BOOT_PART" | sed -E 's/p?[0-9]+$//')
    PART_NUM=$(echo "$BOOT_PART" | grep -o '[0-9]*$')
    efibootmgr --create --disk "$DISK_DEV" --part "$PART_NUM" --label "Limine" --loader '\\EFI\\BOOT\\BOOTX64.EFI'
else
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

echo "[Step 6/6] Running chroot configuration..."
artix-chroot /mnt /root/chroot-setup.sh

rm /mnt/root/chroot-setup.sh
umount -R /mnt

whiptail --title "Installation Complete" --msgbox "Installation Finished Successfully!\n\nYou can now remove your USB and type 'reboot'." 10 60
clear