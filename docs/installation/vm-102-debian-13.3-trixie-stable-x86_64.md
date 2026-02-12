# Debian 13.3 (Trixie) stable x86_64

This document describes a **repeatable installation and configuration procedure** for a Debian 13 (Trixie) virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The system is classified under the **`vms.cfg` inventory group** and follows the Proxmox lifecycle management model.

The goal is:

- ensure **clean APT sources**
- perform **baseline system update**
- install **QEMU Guest Agent**
- enable **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and administration

## Contents

1. [VM Overview](#vm-overview)
2. [VM Classification and Management Scope](#vm-classification-and-management-scope)
3. [Proxmox VM Reference Configuration](#1-proxmox-vm-reference-configuration)
4. [Prepare APT Sources](#2-prepare-apt-sources)
5. [Initial System Update](#3-initial-system-update)
6. [Install Required Packages](#4-install-required-packages)
7. [Configure Passwordless Sudo](#5-configure-passwordless-sudo)
8. [Configure SSH Access](#6-configure-ssh-access)
9. [Test Connection](#7-test-connection)
10. [Result](#result)

## VM Overview

- **OS:** Debian 13.3 (Trixie) stable x86_64  
- **Hostname:** `vm-debian`
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Linux utility / build / automation node

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and replaceable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for automation, CI, build, and infrastructure tasks

This classification distinguishes the system from physical or host-level
machines listed under `hosts.cfg`.

## 1. Proxmox VM Reference Configuration

> Configuration snapshot provided for audit and rebuild reference.  
> Not required for daily operation.

```ini
agent: 1
audio0: device=ich9-intel-hda,driver=spice
balloon: 1024
bios: ovmf
boot: order=scsi0;ide2;net0
cores: 2
cpu: x86-64-v2-AES
efidisk0: ssd-data:102/vm-102-disk-0.qcow2,efitype=4m,ms-cert=2023w,pre-enrolled-keys=1,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: Debian
net0: virtio=BC:24:11:61:8E:F7,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:102/vm-102-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:102/vm-102-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
```

## 2. Prepare APT Sources

After installation from ISO, the CD-ROM repository entry must be disabled.

Verify presence of CD-ROM source:

```bash
grep cdrom /etc/apt/sources.list
```

Comment out the CD-ROM entry:

```bash
sudo sed -i 's|^deb cdrom:|# deb cdrom:|' /etc/apt/sources.list
```

Verify the change:

```bash
grep cdrom /etc/apt/sources.list
```

## 3. Initial System Update

Update the package index and upgrade installed packages:

```bash
sudo apt update
sudo apt upgrade
```

## 4. Install Required Packages

Install Proxmox integration and SSH server:

```bash
sudo apt install qemu-guest-agent ssh
```

Enable and start the guest agent:

```bash
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

Reboot to finalize integration:

```bash
sudo reboot
```

## 5. Configure Passwordless Sudo

For automation and administration, the primary user is granted
**passwordless sudo**.

Edit sudoers using `visudo`:

```bash
sudo EDITOR=nano visudo
```

Add the following line:

```text
marelis ALL=(ALL) NOPASSWD:ALL
```

> This rule provides explicit, user-scoped privilege escalation suitable
> for automation and scripted tasks.

## 6. Configure SSH Access

### 6.1 Add Authorized SSH Keys

Edit the authorized keys file:

```bash
nano ~/.ssh/authorized_keys
```

Insert public keys:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBH9oiMFtQIMn9n6ljjiu+i9c2Z9qi7VnfXTlApTpe2e marelis@DESKTOP-MARELIS
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuEMOpt2H3hDrkkuzn8rPP4IY2BNNr+eOhyNp7yr+Al marelis@NTB-MARELIS
```

Ensure correct permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

## 7. Test Connection

From a Linux or WSL host:

```bash
ssh marelis@192.168.88.102
```

Expected result:

```text
Linux vm-debian 6.x.x-amd64 #1 SMP Debian

marelis@vm-debian:~$ whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

## Result

- VM is fully managed under **Proxmox** and listed in `vms.cfg`
- APT sources are clean and ISO-based entries removed
- System is updated and integrated via **QEMU Guest Agent**
- SSH access uses **ED25519 key authentication**
- Passwordless sudo is configured for automation
- VM is suitable for **general-purpose Linux workloads**
