#!/usr/bin/env bash
# ==============================================================================
# Setup Dunst Notification System & OS Control Scripts for OXWM
# Target: Artix Linux + dinit (user services via turnstile/userspawn)
# ==============================================================================

set -Eeuo pipefail

# --- 1. Install packages -----------------------------------------------------
# Includes the dinit user-service wrappers for PipeWire/WirePlumber.
echo "==> [1/6] Installing packages..."
sudo pacman -S --needed --noconfirm \
    libnotify dunst brightnessctl \
    pipewire pipewire-pulse wireplumber \
    pipewire-dinit pipewire-pulse-dinit wireplumber-dinit

# Ensure the user-service spawner is available (turnstile is the usual choice).
# If you already use userspawn instead, install that package and skip turnstile.
sudo pacman -S --needed --noconfirm turnstile turnstile-dinit

# --- 2. Create script and config directories ---------------------------------
echo "==> [2/6] Creating user directories..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config/dunst"
mkdir -p "$HOME/.config/oxwm"

# --- 3. Brightness helper ----------------------------------------------------
echo "==> [3/6] Setting up brightness helper..."
cat << 'BRIGHT_EOF' > "$HOME/.local/bin/change-brightness.sh"
#!/usr/bin/env bash
# Adjust brightness with brightnessctl.
brightnessctl set "$1" > /dev/null

# Extract the percentage from machine-readable output.
BRIGHTNESS=$(brightnessctl -m | awk -F, '{print $4}')

# Replace the previous brightness notification (tag: brightness).
notify-send \
    -a "brightness" \
    -h string:x-canonical-private-synchronous:brightness \
    -h "int:value:${BRIGHTNESS%\%}" \
    -t 1500 \
    "Brightness: ${BRIGHTNESS}"
BRIGHT_EOF
chmod +x "$HOME/.local/bin/change-brightness.sh"

# --- 4. Volume helper --------------------------------------------------------
echo "==> [4/6] Setting up volume helper (over-amplification capped at 150%)..."
cat << 'VOL_EOF' > "$HOME/.local/bin/change-volume.sh"
#!/usr/bin/env bash
# Perform volume action via WirePlumber.
case "$1" in
    raise)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${2:-5%}+"
        ;;
    lower)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${2:-5%}-"
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac

# Read current volume state.
VOLUME_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)

if echo "$VOLUME_RAW" | grep -q "MUTED"; then
    notify-send \
        -a "volume" \
        -h string:x-canonical-private-synchronous:volume \
        -t 1500 \
        "Volume: Muted"
else
    VOL=$(echo "$VOLUME_RAW" | awk '{print int($2 * 100)}')
    notify-send \
        -a "volume" \
        -h string:x-canonical-private-synchronous:volume \
        -h "int:value:${VOL}" \
        -t 1500 \
        "Volume: ${VOL}%"
fi
VOL_EOF
chmod +x "$HOME/.local/bin/change-volume.sh"

# --- 5. Dunst configuration --------------------------------------------------
echo "==> [5/6] Configuring Dunst (icons off for brightness and volume)..."
DUNST_CONF="$HOME/.config/dunst/dunstrc"

if [ ! -f "$DUNST_CONF" ]; then
    if [ -f "/etc/dunst/dunstrc" ]; then
        cp /etc/dunst/dunstrc "$DUNST_CONF"
    else
        touch "$DUNST_CONF"
    fi
fi

# Critical: ensure a [global] section exists before appending rule blocks.
# Without this, Dunst treats the appended rules as part of the global settings
# and may fail to start.
if ! grep -q '^\[global\]' "$DUNST_CONF"; then
    printf '\n[global]\n' >> "$DUNST_CONF"
fi

# Append brightness rule only if not already present.
if ! grep -q '^\[brightness\]' "$DUNST_CONF"; then
    cat << 'DUNST_BRIGHT_EOF' >> "$DUNST_CONF"

[brightness]
    appname = "brightness"
    icon_position = off
DUNST_BRIGHT_EOF
fi

# Append volume rule only if not already present.
if ! grep -q '^\[volume\]' "$DUNST_CONF"; then
    cat << 'DUNST_VOL_EOF' >> "$DUNST_CONF"

[volume]
    appname = "volume"
    icon_position = off
DUNST_VOL_EOF
fi

# --- 6. dinit user services & environment ------------------------------------
echo "==> [6/6] Enabling dinit user services and setting X11 environment..."

# These are USER services. Do not use sudo here.
# dinitctl enable both enables and starts the service immediately.
# If the service is already enabled, this is a harmless no-op.
dinitctl enable pipewire
dinitctl enable pipewire-pulse
dinitctl enable wireplumber

# Make DISPLAY and XAUTHORITY available to the dinit user-service environment.
# This is the dinit-native equivalent of the systemd import-environment line.
# It is safe to run even if the variables are already set.
dinitctl setenv DISPLAY "${DISPLAY:-}" > /dev/null 2>&1 || true
dinitctl setenv XAUTHORITY "${XAUTHORITY:-}" > /dev/null 2>&1 || true

# If dbus-update-activation-environment exists, also update the D-Bus session
# environment so notification daemons and other session services see the display.
if command -v dbus-update-activation-environment > /dev/null 2>&1; then
    dbus-update-activation-environment DISPLAY XAUTHORITY 2>/dev/null || true
fi

# Reload Dunst if it is running; otherwise start it so notifications work
# immediately in the current session. Dunst has no dinit user service by default,
# so it is managed as a session process (e.g. from OXWM autostart or here).
if command -v dunstctl > /dev/null 2>&1; then
    dunstctl reload 2>/dev/null || true
fi

if ! pgrep -x dunst > /dev/null 2>&1; then
    dunst > /dev/null 2>&1 &
fi

echo "==> Setup completed successfully!"
