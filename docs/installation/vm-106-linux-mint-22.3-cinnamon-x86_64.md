# Linux Mint 22.3 (Cinnamon) x86_64

This document describes a **repeatable installation and configuration procedure** for a Linux Mint 22.3 (Cinnamon) virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The system is classified under the **`vms.cfg` inventory group** and follows the Proxmox lifecycle management model.

The goal is:

- perform **baseline system update**
- install **QEMU Guest Agent**
- enable **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and administration
- prepare a **desktop-capable Linux VM** suitable for interactive and service use

## Contents

- [VM Overview](#vm-overview)
- [VM Classification and Management Scope](#vm-classification-and-management-scope)
- [Proxmox VM Reference Configuration](#proxmox-vm-reference-configuration)
- [Initial System Setup](#initial-system-setup)
- [Install Required Packages](#install-required-packages)
- [Configure Passwordless Sudo](#configure-passwordless-sudo)
- [Configure SSH Access](#configure-ssh-access)
- [Test Connection](#test-connection)
- [Result](#result)

## VM Overview

- **OS:** Linux Mint 22.3 (Cinnamon) x86_64  
- **Hostname:** `vm-linux-mint`
- **Desktop environment:** Cinnamon
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **CPU model:** `x86-64-v2-AES`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Desktop-capable Linux VM / utility and automation node

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and replaceable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for desktop-oriented Linux workloads, testing, and automation

This classification distinguishes the system from host-level machines
listed under `hosts.cfg`.

## Proxmox VM Reference Configuration

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
efidisk0: ssd-data:106/vm-106-disk-0.qcow2,efitype=4m,ms-cert=2023w,pre-enrolled-keys=1,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: LinuxMint
net0: virtio=BC:24:11:7C:7A:B7,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:106/vm-106-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:106/vm-106-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
```

## Initial System Setup

Update the system to the latest patch level:

```bash
sudo apt update
sudo apt upgrade
```

Reboot to ensure kernel and system components are fully applied:

```bash
sudo reboot
```

## Install Required Packages

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

## Configure Passwordless Sudo

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

### Remove User from `sudo` Group

To avoid conflicts between group-based and user-specific sudo rules,
remove the user from the `sudo` group:

```bash
sudo deluser marelis sudo
```

Log out and back in, or reboot if required.

## Configure SSH Access

### Create SSH Directory and Keys

Create the `.ssh` directory if it does not exist:

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

## Test Connection

From a Linux or WSL host:

```bash
ssh marelis@192.168.88.106
```

Expected result:

```text
Linux Mint 22.3

marelis@vm-linux-mint:~$ whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

## Result

- VM is fully managed under **Proxmox** and listed in `vms.cfg`
- System is updated and integrated via **QEMU Guest Agent**
- SSH access uses **ED25519 key authentication**
- Passwordless sudo is configured for automation
- Desktop environment (Cinnamon) is available for interactive use
- VM is suitable for **desktop-oriented Linux workloads and automation**
