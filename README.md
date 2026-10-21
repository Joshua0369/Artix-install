# Artix-install
An interactive, automated installation script for **Artix Linux** utilizing the **dinit** init system and the **linux-zen** kernel, designed for quick custom setups with optional window managers, audio stacks, and rice configurations.

---

## 🚀 What's Inside the Script?

* **Display Manager:** `Ly`

## 📦 What It Installs

### Core System
* **Init System:** `dinit` + `elogind-dinit`
* **Kernel:** `linux-zen` & `linux-zen-headers` + `linux-firmware`
* **Networking & Time:** `NetworkManager` (+dinit), `chrony` (+dinit)
* **Utilities:** `nano`, `git`, `efibootmgr`

### Bootloader (Your Choice)
* **Limine** (Default: Minimal, ultra-fast UEFI bootloader with timeout disabled)
* **GRUB** (Standard UEFI bootloader)



## 📥 How to Use

1. Boot into the Artix Linux Live ISO and connect to the internet (`nmtui`).
2. Set up your partitions using `cfdisk`.
3. Clone the repository using **git** and run the script:

```bash
git clone https://github.com/Joshua0369/Artix-install.git
cd Artix-install
chmod +x artix-install.sh
sudo ./artix-install.sh
