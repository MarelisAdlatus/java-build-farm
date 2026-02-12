# openSUSE Tumbleweed (rolling) x86_64

This document describes a **repeatable installation and configuration procedure** for an openSUSE Tumbleweed (rolling release) virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The system is classified under the **`vms.cfg` inventory group** and follows the Proxmox lifecycle management model.

The goal is:

- perform **rolling system refresh and update**
- install **QEMU Guest Agent**
- enable and expose **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and administration
- ensure firewall rules allow SSH
- validate operation on **x86-64-v3** CPU architecture
- provide a **fast-moving rolling Linux VM** for testing and development

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

- **OS:** openSUSE Tumbleweed (rolling) x86_64  
- **Hostname:** `vm-opensuse-weed`
- **Release model:** Rolling
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **CPU model:** `x86-64-v3`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Rolling Linux VM / development and validation node

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and disposable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for rolling-release testing, toolchain validation, and development

Because openSUSE Tumbleweed is a **rolling distribution**, this VM is
treated as **non-persistent** and may be rebuilt if major transitions
or regressions occur.

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
cpu: x86-64-v3
efidisk0: ssd-data:110/vm-110-disk-0.qcow2,efitype=4m,ms-cert=2023w,pre-enrolled-keys=1,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: openSUSEWeed
net0: virtio=BC:24:11:B7:B7:8B,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:110/vm-110-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:110/vm-110-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
```

## Initial System Setup

Refresh repositories and metadata:

```bash
sudo zypper refresh
```

Apply rolling updates:

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

For automation, CI, and administrative tasks, configure passwordless
sudo for the primary user.

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

## Test Connection

From a Linux or WSL host:

```bash
ssh marelis@192.168.88.110
```

Expected result:

```text
Welcome to openSUSE Tumbleweed

marelis@vm-opensuse-weed:~> whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

## Result

- VM is fully managed under **Proxmox** and listed in `vms.cfg`
- System follows the **rolling-release update model**
- SSH access uses **ED25519 key authentication**
- Firewall explicitly allows SSH
- Passwordless sudo is configured for automation
- CPU model `x86-64-v3` is explicitly validated
- VM is suitable for **cutting-edge testing, development, and validation**
