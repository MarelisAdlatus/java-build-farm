# Fedora Workstation 43 x86_64

This document describes a **repeatable installation and configuration procedure** for a Fedora Workstation 43 virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The system is classified under the **`vms.cfg` inventory group** and follows the Proxmox lifecycle management model.

The goal is:

- set a consistent **hostname**
- perform **baseline system update**
- install **QEMU Guest Agent**
- enable **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and administration
- ensure compatibility with **x86-64-v3** CPU features
- provide a **desktop-capable Fedora Workstation VM**

## Contents

1. [VM Overview](#vm-overview)
2. [VM Classification and Management Scope](#vm-classification-and-management-scope)
3. [Proxmox VM Reference Configuration](#1-proxmox-vm-reference-configuration)
4. [Initial System Setup](#2-initial-system-setup)
5. [Install Required Packages](#3-install-required-packages)
6. [Configure Passwordless Sudo](#4-configure-passwordless-sudo)
7. [Configure SSH Access](#5-configure-ssh-access)
8. [Test Connection](#6-test-connection)
9. [Result](#result)

## VM Overview

- **OS:** Fedora Workstation 43 x86_64  
- **Hostname:** `vm-fedora`
- **Edition:** Workstation (GNOME)
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **CPU model:** `x86-64-v3`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Desktop-capable Fedora VM / development and testing node

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and replaceable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for desktop workloads, development, testing, and automation

This classification distinguishes the system from host-level machines
listed under `hosts.cfg`.

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
cpu: x86-64-v3
efidisk0: ssd-data:108/vm-108-disk-0.qcow2,efitype=4m,ms-cert=2023w,pre-enrolled-keys=1,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: Fedora
net0: virtio=BC:24:11:73:80:7C,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:108/vm-108-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:108/vm-108-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
```

## 2. Initial System Setup

Set the hostname explicitly:

```bash
sudo hostnamectl set-hostname vm-fedora
```

Update the system to the latest patch level:

```bash
sudo yum update
```

Reboot to ensure kernel and system components are fully applied:

```bash
sudo reboot
```

## 3. Install Required Packages

Install Proxmox integration and SSH server:

```bash
sudo yum install qemu-guest-agent openssh
```

Enable and start SSH service:

```bash
sudo systemctl enable --now sshd
```

Reboot to finalize integration:

```bash
sudo reboot
```

## 4. Configure Passwordless Sudo

For automation and administration tasks, configure passwordless sudo
for the primary user.

Edit sudoers using `visudo`:

```bash
sudo EDITOR=nano visudo
```

Add the following line:

```text
marelis ALL=(ALL) NOPASSWD:ALL
```

### 4.1 Remove User from `wheel` Group

To avoid conflicts between group-based and user-specific sudo rules,
remove the user from the `wheel` group:

```bash
sudo gpasswd -d marelis wheel
```

Reboot to apply session changes:

```bash
sudo reboot
```

## 5. Configure SSH Access

### 5.1 Create SSH Directory and Keys

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
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

## 6. Test Connection

From a Linux or WSL host:

```bash
ssh marelis@192.168.88.108
```

Expected result:

```text
Fedora release 43 (Workstation Edition)

marelis@vm-fedora:~$ whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

## Result

- VM is fully managed under **Proxmox** and listed in `vms.cfg`
- Hostname and CPU model (`x86-64-v3`) are explicitly defined
- System is updated and integrated via **QEMU Guest Agent**
- SSH access uses **ED25519 key authentication**
- Passwordless sudo is configured for automation
- Fedora Workstation (GNOME) desktop is available
- VM is suitable for **development, testing, and desktop Linux workloads**
