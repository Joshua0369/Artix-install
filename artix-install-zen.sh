#!/usr/bin/env bash
# ==============================================================================
# Artix Linux Streamlined Installer (Zen Kernel / Dual-Boot Safe)
# System: dinit + linux-zen + fastfetch + btop + ly
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
echo "    Artix Linux Streamlined Installer (Zen)       "
echo "=================================================="
echo ""

read -r -p "Do you want to download and set the console font to ter-22b? (y/n) [default: y]: " SET_FONT
SET_FONT=${SET_FONT:-y}
if [[ "$SET_FONT" =~ ^[Yy]$ ]]; then
    echo "==> Installing terminus-font on live environment..."
    pacman -Sy --noconfirm terminus-font 2>/dev/null || echo "[!] Warning: Could not install terminus-font."
    setfont ter-22b 2>/dev/null || echo "[!] Notice: ter-22b font could not be loaded."
fi
echo ""

echo "==> Running pre-installation checks..."
if [ -f /etc/os-release ]; then source /etc/os-release; fi

if [[ "${ID:-}" != "artix" && "${ID_LIKE:-}" != *"artix"* ]]; then
    echo "ERROR: Incorrect OS. This script is strictly for Artix Linux."
    exit 1
fi

if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    echo "ERROR: No active internet connection."
    exit 1
fi

read -r -p "Would you like to continue? Type 'execute' for yes and 'n' for no: " CONTINUE_CHOICE
if [[ "$CONTINUE_CHOICE" != "execute" ]]; then
    exit 0
fi
echo ""

read -r -p "Enter hostname [default: 60]: " HOSTNAME
HOSTNAME=${HOSTNAME:-60}

read -r -p "Enter your username [default: j]: " USERNAME
USERNAME=${USERNAME:-j}

read -r -p "Enter timezone [default: Asia/Manila]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Manila}

echo ""
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
echo ""

read -r -p "Enter your BOOT/EFI partition (e.g. nvme0n1p1): " BOOT_PART
read -r -p "Enter your ROOT partition (e.g. nvme0n1p4): " ROOT_PART

[[ "$BOOT_PART" != /dev/* ]] && BOOT_PART="/dev/$BOOT_PART"
[[ "$ROOT_PART" != /dev/* ]] && ROOT_PART="/dev/$ROOT_PART"

# --- FORMATTING PROMPTS ---
echo ""
echo "--------------------------------------------------"
echo " Formatting Options (Dual-Boot Safe)"
echo "--------------------------------------------------"
read -r -p "Format ROOT partition ($ROOT_PART)? (y/n) [default: y]: " FORMAT_ROOT
FORMAT_ROOT=${FORMAT_ROOT:-y}

read -r -p "Format BOOT partition ($BOOT_PART)? (y/n) [default: n]: " FORMAT_BOOT
FORMAT_BOOT=${FORMAT_BOOT:-n}

read -r -p "Choose bootloader (1=Limine, 2=GRUB) [default: 1]: " BOOTLOADER_CHOICE
BOOTLOADER_CHOICE=${BOOTLOADER_CHOICE:-1}

BASE_PKGS="base base-devel dinit elogind-dinit linux-firmware efibootmgr networkmanager networkmanager-dinit chrony chrony-dinit nano git terminus-font fastfetch btop libxcb dosfstools ly ly-dinit"

if [ "$BOOTLOADER_CHOICE" == "1" ]; then
    BASE_PKGS="$BASE_PKGS limine"
else
    BASE_PKGS="$BASE_PKGS grub os-prober"
fi

echo ""
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

echo "[Step 5/6] Configuring system & installing Zen kernel..."

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

# --- ZEN KERNEL INSTALL ---
echo "==> Installing linux-zen kernel..."
pacman -S --noconfirm --needed linux-zen linux-zen-headers

# --- CRITICAL FIX: FORCE NVME DRIVER ---
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

# --- LY SETUP ---
mkdir -p /etc/dinit.d/config
cat << 'CONSOLECONF' > /etc/dinit.d/config/console.conf
ACTIVE_CONSOLES="/dev/tty[2-6]"
CONSOLECONF
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

    # Cleanup old Limine UEFI entries to prevent duplicates
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

echo ""
echo "================================================--"
echo "      Installation Finished Successfully!         "
echo "  You can now remove your USB and type 'reboot'.  "
echo "================================================--"