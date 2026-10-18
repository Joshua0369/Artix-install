# Artix-install
An interactive, automated installation script for **Artix Linux** utilizing the **dinit** init system and the **linux-zen** kernel, designed for quick custom setups with optional window managers, audio stacks, and rice configurations.

---

## 🚀 What's Inside the Script?

This script handles the entire installation pipeline interactively:
1. **Pre-installation Checks:** Verifies you are running on an Artix Live environment with an active internet connection.
2. **Interactive Configuration:** Prompts you for your hostname, username, timezone, disk partitions, and swap preference.
3. **Flexible Component Selection:** Lets you pick a primary Window Manager or install multiple options, along with toggles for optional rices, shells, and audio tools.
4. **Automated Partitioning & Bootstrap:** Formats your EFI and Root partitions, mounts them, runs `basestrap`, and generates the `fstab`.
5. **Chroot System Deployment:** Configures users, locales, sudoers rules (including passwordless power/reboot), enables core services, builds AUR helpers (`yay` and `paru`), and deploys your chosen bootloader.

---

## 📦 What It Installs

### Core System
* **Init System:** `dinit` + `elogind-dinit`
* **Kernel:** `linux-zen` & `linux-zen-headers` + `linux-firmware`
* **Networking & Time:** `NetworkManager` (+dinit), `chrony` (+dinit)
* **Utilities:** `nano`, `git`, `efibootmgr`

### Bootloader (Your Choice)
* **Limine** (Default: Minimal, ultra-fast UEFI bootloader with timeout disabled)
* **GRUB** (Standard UEFI bootloader)

### Window Managers & Compositors (Optional / Selectable)
* **dwm** (+ optional `mich-murphy/dwm-dotfiles`)
* **bspwm** (+ `sxhkd`, `polybar`, `rofi`, `feh`, `picom`, + optional `gh0stzk/dotfiles`)
* **sway** (Wayland compositor + `swaybg`, `swaylock`, `swayidle`, `foot`)
* **oxwm** (Installed from AUR)
* **mangowc** (Installed from AUR)
* **vxwm** (+ optional `ceapeapea/vxwm-dotfiles` via AUR)

### Optional Components & Rices
* **Shell:** `zsh` configured with `eza`, `bat`, syntax highlighting, history search, and `fzf-tab` (plus `gh0stzk`'s dotfiles & power aliases).
* **Audio:** `PipeWire` low-latency audio stack (`pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`, `pwvucontrol`) pre-configured with a 64-sample (~1.33ms) gaming audio profile.
* **Display Manager:** `Ly` console display manager configured as a native dinit service with TTY reallocation to avoid conflicts.
* **Terminal & Aesthetics:** `Alacritty` (styled with JetBrains Mono) and `Fastfetch` (pre-configured with the `awesome-fastfetch` preset).
* **AUR Helpers:** Automatic source compilation and installation of both **yay** and **paru**.

---

## 📥 How to Use

1. Boot into the Artix Linux Live ISO and connect to the internet (`nmtui`).
2. Set up your partitions using `cfdisk`.
3. Clone the repository using **git** and run the script:

```bash
git clone https://github.com/Joshua0369/Artix-install.git
cd Artix-install
chmod +x artix-install.sh
sudo ./artix-install.sh
