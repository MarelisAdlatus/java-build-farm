# openSUSE Leap 16.0 x86_64

This document describes a **repeatable installation and configuration procedure** for an openSUSE Leap 16 virtual machine running on **Proxmox**, prepared as part of a larger VM environment.

The system is classified under the **`cms.cfg` inventory group** and follows the Proxmox lifecycle management model.

The goal is:

- perform **baseline system refresh**
- install **QEMU Guest Agent**
- enable and expose **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and administration
- ensure firewall allows SSH access

## Contents

- [VM Overview](#vm-overview)
- [VM Classification and Management Scope](#vm-classification-and-management-scope)
- [Proxmox VM Reference Configuration](#proxmox-vm-reference-configuration)
- [Initial System Setup](#initial-system-setup)
- [Install Required Packages](#install-required-packages)
- [Configure Firewall for SSH](#configure-firewall-for-ssh)
- [Configure Passwordless Sudo](#configure-passwordless-sudo)
- [Configure SSH Access](#configure-ssh-access)
- [Test Connection](#test-connection)
- [Result](#result)

## VM Overview

- **OS:** openSUSE Leap 16.0 x86_64  
- **Hostname:** `vm-opensuse-leap`
- **Hypervisor:** Proxmox VE
- **Inventory group:** `cms.cfg`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** CMS / service / Linux workload node

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`cms.cfg` inventory group.

Characteristics of `cms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and replaceable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for CMS, service-oriented, and application workloads

This classification distinguishes the system from general-purpose build
nodes (`vms.cfg`) and host-level machines (`hosts.cfg`).

## Proxmox VM Reference Configuration

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
efidisk0: ssd-data:103/vm-103-disk-0.qcow2,efitype=4m,ms-cert=2023w,pre-enrolled-keys=1,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: openSUSELeap
net0: virtio=BC:24:11:70:51:31,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:103/vm-103-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:103/vm-103-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
```

## Initial System Setup

Refresh repositories and metadata:

```bash
sudo zypper refresh
```

Apply updates:

```bash
sudo zypper update
```

Reboot to ensure kernel and core components are fully applied:

```bash
sudo reboot
```

## Install Required Packages

Install Proxmox integration and SSH server:

```bash
sudo zypper install qemu-guest-agent openssh
```

Enable required services:

```bash
sudo systemctl enable --now qemu-guest-agent
sudo systemctl enable --now sshd
```

Reboot to finalize integration:

```bash
sudo reboot
```

## Configure Firewall for SSH

Allow SSH service through the firewall:

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

Verify active services:

```bash
sudo firewall-cmd --list-services
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

### Remove User from `wheel` Group

To avoid conflicts between group-based and user-specific sudo rules,
remove the user from the `wheel` group:

```bash
sudo gpasswd -d marelis wheel
```

Reboot to apply session changes:

```bash
sudo reboot
```

## Configure SSH Access

### Create SSH Directory and Keys

Create the `.ssh` directory if it does not exist:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Edit authorized keys:

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
ssh marelis@192.168.88.103
```

Expected result:

```text
Welcome to openSUSE Leap 16.0

marelis@vm-opensuse-leap:~> whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

## Result

- VM is fully managed under **Proxmox** and listed in `cms.cfg`
- System is refreshed and integrated via **QEMU Guest Agent**
- SSH access uses **ED25519 key authentication**
- Firewall explicitly allows SSH
- Passwordless sudo is configured for automation
- VM is suitable for **CMS and service-oriented workloads**
