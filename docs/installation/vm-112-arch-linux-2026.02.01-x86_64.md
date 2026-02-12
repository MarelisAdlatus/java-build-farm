# Arch Linux 2026.02.01 x86_64

This document describes a **repeatable installation and configuration procedure** for an Arch Linux (snapshot 2026.02.01) virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The system is classified under the **`vms.cfg` inventory group** and follows the Proxmox lifecycle management model.

The goal is:

- install Arch Linux via `archinstall`
- configure a **desktop profile (KDE Plasma)**
- ensure network works reliably (NetworkManager)
- install **QEMU Guest Agent**
- enable and expose **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and administration
- configure firewall rules for SSH
- document Secure Boot state (disabled)

---

## Contents

1. [VM Overview](#vm-overview)
2. [VM Classification and Management Scope](#vm-classification-and-management-scope)
3. [Secure Boot and EFI Configuration](#secure-boot-and-efi-configuration)
4. [Pre-Install Notes (Networking)](#pre-install-notes-networking)
5. [OS Installation (archinstall)](#os-installation-archinstall)
6. [Post-Install Fixes (NetworkManager, Login Screen Language)](#post-install-fixes-networkmanager-login-screen-language)
7. [Proxmox VM Reference Configuration](#1-proxmox-vm-reference-configuration)
8. [System Update and Package Installation](#2-system-update-and-package-installation)
9. [Enable Services (SSHD, Firewalld)](#3-enable-services-sshd-firewalld)
10. [Configure Firewall for SSH](#4-configure-firewall-for-ssh)
11. [Configure Passwordless Sudo](#5-configure-passwordless-sudo)
12. [Configure SSH Access](#6-configure-ssh-access)
13. [Test Connection](#7-test-connection)
14. [Result](#result)

---

## VM Overview

- **OS:** Arch Linux 2026.02.01 x86_64  
- **Hostname:** `vm-arch-linux`
- **Desktop environment:** KDE Plasma
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **CPU model:** `x86-64-v2-AES`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Rolling Linux VM / desktop validation and development node

---

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and disposable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for rolling-release testing, toolchain validation, and development

Because Arch Linux is a **rolling distribution**, this VM is treated as
**non-persistent** and may be rebuilt when major transitions occur.

---

## Secure Boot and EFI Configuration

Secure Boot is explicitly disabled for this VM.

- **Secure Boot:** Off
- **EFI disk:** `pre-enrolled-keys = false`

This avoids Secure Boot key enrollment requirements and keeps the VM
reproducible in Proxmox environments.

---

## Pre-Install Notes (Networking)

During installation, verify network interfaces:

```bash
ip link
ip addr show ens18
````

If IPv6 causes issues (example observed during install environment),
disable IPv6 temporarily:

```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

---

## OS Installation (archinstall)

Run the guided installer:

```bash
archinstall
```

Selected options (baseline):

* **Localization:** `cz`, `cs_CZ.UTF-8`
* **Mirrors / Repositories region:** Czechia
* **Disk configuration:** Smart disk partitioning
* **Hostname:** `vm-arch-linux`
* **Profile / Type:** Desktop → KDE Plasma
* **Time zone:** `Europe/Prague`
* **Authentication:** Create a user account (example user: `marelis`)

---

## Post-Install Fixes (NetworkManager, Login Screen Language)

### Known issue: Login screen keyboard/language defaults to English

Observed: login screen uses English keyboard/layout even though the system
was configured for Czech localization.

This is typically a display manager / layout configuration issue.
Fix it via desktop settings (KDE) and/or system locale configuration as needed.

### NetworkManager may not be enabled automatically

After first boot and login, ensure NetworkManager is enabled:

```bash
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
```

Then configure:

* Czech keyboard layout
* auto-login (if required for the VM farm workflow)

Reboot to apply changes:

```bash
sudo reboot
```

---

## 1. Proxmox VM Reference Configuration

> Configuration snapshot provided for audit and rebuild reference.
> It is **not required** for daily operation.

```ini
agent: 1
audio0: device=ich9-intel-hda,driver=spice
balloon: 1024
bios: ovmf
boot: order=scsi0;ide2;net0
cores: 2
cpu: x86-64-v2-AES
efidisk0: ssd-data:112/vm-112-disk-0.qcow2,efitype=4m,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: ArchLinux
net0: virtio=BC:24:11:89:7C:F2,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:112/vm-112-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:112/vm-112-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
```

---

## 2. System Update and Package Installation

Update the system:

```bash
sudo pacman -Syu
```

Install required packages:

```bash
sudo pacman -S qemu-guest-agent openssh firewalld nano
```

---

## 3. Enable Services (SSHD, Firewalld)

Enable SSH and the firewall:

```bash
sudo systemctl enable --now sshd
sudo systemctl enable --now firewalld
```

Reboot to finalize service state:

```bash
sudo reboot
```

---

## 4. Configure Firewall for SSH

Allow SSH service through firewalld:

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

Verify active services:

```bash
sudo firewall-cmd --list-services
```

---

## 5. Configure Passwordless Sudo

For automation and administrative tasks, configure passwordless sudo
for the primary user.

Edit sudoers using `visudo`:

```bash
sudo EDITOR=nano visudo
```

Add the following line:

```text
marelis ALL=(ALL) NOPASSWD:ALL
```

---

### 5.1 Remove User from `wheel` Group

To avoid conflicts between group-based and user-specific sudo rules,
remove the user from the `wheel` group:

```bash
sudo gpasswd -d marelis wheel
```

Reboot to apply session changes:

```bash
sudo reboot
```

---

## 6. Configure SSH Access

### 6.1 Create SSH Directory and Keys

Ensure the `.ssh` directory exists and has correct permissions:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Edit the authorized keys file:

```bash
nano ~/.ssh/authorized_keys
```

Insert public keys:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBH9oiMFtQIMn9n6ljjiu+i9c2Z9qi7VnfXTlApTpe2e marelis@DESKTOP-MARELIS
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuEMOpt2H3hDrkkuzn8rPP4IY2BNNr+eOhyNp7yr+Al marelis@NTB-MARELIS
```

Set correct permissions:

```bash
chmod 600 ~/.ssh/authorized_keys
```

---

## 7. Test Connection

From a Linux or WSL host:

```bash
ssh marelis@192.168.88.112
```

Expected result:

```text
Arch Linux

marelis@vm-arch-linux:~$ whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

---

## Result

* VM is fully managed under **Proxmox** and listed in `vms.cfg`
* Secure Boot is explicitly disabled (EFI pre-enrolled keys disabled)
* System is installed via `archinstall` and uses KDE Plasma
* NetworkManager is enabled for reliable network configuration
* System is updated and integrated via **QEMU Guest Agent**
* SSH access uses **ED25519 key authentication**
* Firewall explicitly allows SSH
* Passwordless sudo is configured for automation
* VM is suitable for **rolling-release testing, development, and validation**
