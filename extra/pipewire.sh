#!/bin/bash
set -e

echo "=== Artix Linux PipeWire + pwvucontrol Installer (dinit) ==="

# 1. Install required packages
# pipewire-dinit, pipewire-pulse-dinit, and wireplumber-dinit provide the user service files
echo "[*] Installing PipeWire packages and pwvucontrol..."
sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    pipewire-dinit \
    pipewire-pulse-dinit \
    wireplumber-dinit \
    pwvucontrol

# 2. Enable and start user services via dinit
# In Artix dinit, user services are enabled/started with dinitctl (as user)
echo "[*] Enabling and starting PipeWire user services..."

# Enable the services (this also starts them immediately per dinit behavior)
# We start wireplumber last as it depends on pipewire
dinitctl enable pipewire
dinitctl enable pipewire-pulse
dinitctl enable wireplumber

# 3. Verify services are running
echo "[*] Checking service status..."
dinitctl list | grep -E "(pipewire|wireplumber)" || true

# 4. Quick functional test
echo "[*] Testing PipeWire audio server..."
if command -v pw-cli &>/dev/null; then
    # Just check if we can list nodes; this confirms the daemon is reachable
    if pw-cli ls Node &>/dev/null; then
        echo "[+] PipeWire is responding."
    else
        echo "[!] Warning: PipeWire daemon is not responding yet. You may need to re-login."
    fi
else
    echo "[!] pw-cli not found (unexpected)."
fi

# 5. Check pwvucontrol
if command -v pwvucontrol &>/dev/null; then
    echo "[+] pwvucontrol is installed."
else
    echo "[!] pwvucontrol binary not found in PATH."
fi

echo ""
echo "=== Installation Complete ==="
echo "If this is your first time setting up PipeWire, please log out and log back in"
echo "(or reboot) to ensure the user session picks up all environment variables."
echo ""
echo "After re-login, you can launch 'pwvucontrol' from your application menu or terminal."
