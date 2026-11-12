# Artix-install

An interactive, automated installation script suite for **Artix Linux** using the **dinit** init system — designed for fast, custom setups with optional window managers, audio stacks, and rice configurations.

This repository contains **three installer scripts**. They share the same core installation flow and differ mainly in their **kernel** and performance tuning. Pick the one that matches your preference.

---

## 🧭 Which script should I use?

| Script | Best for | Kernel | Init | Bootloader | Extras |
|---|---|---|---|---|---|
| **`artix-install-zen.sh`** | Balanced performance + responsiveness (recommended default) | `linux-zen` | dinit | Limine (default) or GRUB | See below |
| **`artix-install-bore.sh`** | Low-latency / desktop-oriented scheduling | `linux-bore` *(confirm from script)* | dinit | Limine or GRUB | See below |
| **`artix-install-cachyos.sh`** | CachyOS-style tuned kernel & performance packages | `linux-cachyos` *(confirm from script)* | dinit | Limine or GRUB | See below |

> **Not sure which to pick?** → Use **`artix-install-zen.sh`**. It is the most documented and the safest general-purpose choice.

### Quick chooser
- **Want the most tested, all-rounder path?** → `artix-install-zen.sh`
- **Want a desktop-optimized / low-latency kernel?** → `artix-install-bore.sh`
- **Want CachyOS-tuned performance packages?** → `artix-install-cachyos.sh`

All three scripts share the same core installer (partitioning, base system, dinit services, bootloader choice) and differ primarily in the **kernel** and related performance packages.

---

## 📦 What's inside each script

### Common core (all scripts)

- **Init system:** `dinit` + `elogind-dinit`
- **Networking & time:** `NetworkManager` (dinit), `chrony` (dinit)
- **Utilities:** `nano`, `git`, `efibootmgr`
- **Display manager:** `Ly`
- **Firmware:** `linux-firmware`

**Bootloader (your choice):**
- **Limine** — *default*; minimal, ultra-fast UEFI bootloader with timeout disabled
- **GRUB** — standard UEFI bootloader

---

### `artix-install-zen.sh`

- **Kernel:** `linux-zen`, `linux-zen-headers`
- **Focus:** balanced desktop performance and responsiveness
- **Notes:** *(add any extra packages/rices this script installs)*

---

### `artix-install-bore.sh`

- **Kernel:** *(confirm exact package name from the script — likely `linux-bore` / `linux-bore-headers`)*
- **Focus:** lower-latency, desktop-oriented scheduling (BORE scheduler)
- **Notes:** *(add extras)*

---

### `artix-install-cachyos.sh`

- **Kernel:** *(confirm exact package name from the script — likely `linux-cachyos` / `linux-cachyos-headers`)*
- **Focus:** CachyOS-style tuned kernel and related performance packages
- **Notes:** *(add extras)*

---

## 📥 How to install

You can grab the scripts either with **`git`** (get the whole repo) or with **`curl -L -O`** (grab just the script you need). Both work from the Artix Live ISO.

### 0. Prepare the live environment

1. **Boot into the Artix Linux Live ISO** and connect to the internet:
   ```bash
   nmtui
