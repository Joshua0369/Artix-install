#!/usr/bin/env bash
# ==============================================================================
# Artix UUID / NVMe Emergency Fixer
# Fixes: "ERROR: device 'UUID=...' not found" dropping to emergency shell
# ==============================================================================

set -Eeuo pipefail

# Error trap
cleanup_on_error() {
    local exit_code=$?
    echo -e "\n[!] ERROR: Script failed at line $1 with exit code $exit_code."
    echo "    Attempting to unmount /mnt safely..."
    umount -R /mnt 2>/dev/null || true
    exit "$exit_code"
}
trap 'cleanup_on_error $LINENO' ERR

echo "=================================================="
echo "    Artix UUID / NVMe Boot Fixer                  "
echo "=================================================="
echo ""

# 1. Identify Root Partition
echo "Looking for Linux root partitions..."
echo "--------------------------------------------------"
lsblk -f | grep -E "ext4|btrfs" || true
echo "--------------------------------------------------"

read -r -p "Enter your ROOT partition (e.g., /dev/nvme0n1p4): " ROOT_PART
read -r -p "Enter your BOOT partition (e.g., /dev/nvme0n1p3, leave blank if none): " BOOT_PART

if [ -z "$ROOT_PART" ]; then
    echo "Root partition is required. Exiting."
    exit 1
fi

# 2. Mount
echo ""
echo "==> Mounting $ROOT_PART to /mnt..."
mount "$ROOT_PART" /mnt

if [ -n "$BOOT_PART" ]; then
    echo "==> Mounting $BOOT_PART to /mnt/boot..."
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot
fi

# 3. Chroot and Fix
echo ""
echo "==> Chrooting into the system to apply fixes..."

cat << 'EOF' > /mnt/root/fix-boot.sh
#!/usr/bin/env bash
set -Eeuo pipefail

echo "  -> Forcing 'nvme' module into initramfs configuration..."
# Backup original config
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
# Add nvme to MODULES if not present
if ! grep -q "MODULES=.*nvme" /etc/mkinitcpio.conf; then
    sed -i 's/^MODULES=(\(.*\))/MODULES=(nvme \1)/' /etc/mkinitcpio.conf
    # Clean up double spaces
    sed -i 's/  */ /g' /etc/mkinitcpio.conf
fi

echo "  -> Rebuilding initramfs (this may take a minute)..."
mkinitcpio -P

echo "  -> Reading the actual UUID of the root partition..."
# We need to pass the root partition into the chroot script to get its UUID
# Since we are in chroot, /dev is mounted, so blkid works
ACTUAL_UUID=$(blkid -s UUID -o value "$1")
echo "  -> Actual Root UUID detected: $ACTUAL_UUID"

echo "  -> Updating /etc/fstab..."
sed -i "s|UUID=[a-zA-Z0-9-]*|UUID=$ACTUAL_UUID|g" /etc/fstab

echo "  -> Updating Bootloader Configuration..."
if [ -f /boot/limine.conf ]; then
    echo "     Found Limine. Updating cmdline..."
    sed -i "s|cmdline:.*root=UUID=[a-zA-Z0-9-]*|cmdline: root=UUID=$ACTUAL_UUID rw quiet|g" /boot/limine.conf
elif [ -f /boot/grub/grub.cfg ]; then
    echo "     Found GRUB. Re-generating config..."
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "     [!] Warning: Could not find Limine or GRUB config. You may need to update it manually."
fi

echo "  -> Fix complete!"
EOF

chmod +x /mnt/root/fix-boot.sh

# Run the fix script inside the chroot, passing the root partition as an argument
artix-chroot /mnt /root/fix-boot.sh "$ROOT_PART"

# Cleanup
rm /mnt/root/fix-boot.sh

echo ""
echo "==> Unmounting drives..."
umount -R /mnt

echo ""
echo "=================================================="
echo "      FIX COMPLETE! You can now reboot."
echo "=================================================="
