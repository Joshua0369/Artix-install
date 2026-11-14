#!/bin/bash
set -e

echo "=== Artix Linux PipeWire + pwvucontrol Installer (dinit) ==="

# ---------- Check user-level dinit availability ----------
USER_DINIT_SOCKET="/run/user/$(id -u)/dinitctl"

if [ ! -S "$USER_DINIT_SOCKET" ]; then
    echo ""
    echo "[!] User-level dinit is NOT running."
    echo "    This is why 'dinitctl enable' fails with 'No such file or directory'."
    echo ""
    echo "[*] Installing turnstile to manage user services..."
    sudo pacman -S --needed --noconfirm turnstile turnstile-dinit

    echo "[*] Enabling turnstiled system service..."
    sudo dinitctl enable turnstiled

    echo ""
    echo "============================================================"
    echo "  Turnstile has been installed and enabled."
    echo "  You MUST log out and log back in (or reboot) NOW."
    echo "  After logging back in, run this script again."
    echo "============================================================"
    exit 0
fi

# ---------- Install PipeWire packages ----------
echo "[*] User-level dinit detected. Installing PipeWire packages..."
sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    pipewire-dinit \
    pipewire-pulse-dinit \
    wireplumber-dinit \
    pwvucontrol

# ---------- Enable and start user services ----------
echo "[*] Enabling and starting PipeWire user services..."

# dinitctl enable will also start the service
dinitctl enable pipewire
dinitctl enable pipewire-pulse
dinitctl enable wireplumber

# ---------- Verify ----------
echo ""
echo "[*] Service status:"
dinitctl list | grep -E "(pipewire|wireplumber)" || true

echo ""
echo "[*] Testing PipeWire..."
if pw-cli info 0 &>/dev/null; then
    echo "[+] PipeWire daemon is responding."
else
    echo "[!] PipeWire not responding yet. A re-login may be needed."
fi

if command -v pwvucontrol &>/dev/null; then
    echo "[+] pwvucontrol is installed."
fi

echo ""
echo "=== Done ==="
echo "You can now launch 'pwvucontrol' from your application menu or terminal."
