# Ubuntu 24.04.3 LTS x86_64

This document describes a **repeatable installation and configuration procedure** for an Ubuntu 24.04 LTS virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The system is classified under the **`vms.cfg` inventory group** and is fully managed by the Proxmox lifecycle model.

The goal is:

- ensure **baseline system update**
- install **QEMU Guest Agent**
- enable **SSH access**
- configure **key-based authentication**
- allow **passwordless sudo** for automation and build tasks

---

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

---

## VM Overview

- **OS:** Ubuntu 24.04.3 LTS x86_64  
- **Hostname:** `vm-ubuntu-lts`
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Linux build station / automation node

---

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the
`vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- lifecycle managed by **Proxmox**
- expected to be **rebuildable and replaceable**
- configuration stored and auditable at the hypervisor level
- accessed primarily via **SSH**
- suitable for CI, build, automation, and service workloads

This classification distinguishes the system from physical or host-level
machines listed under `hosts.cfg`.

---

## 1. Proxmox VM Reference Configuration

> This configuration snapshot is provided for reference and auditability.  
> It is **not required** for daily operation.

```ini
agent: 1
audio0: device=ich9-intel-hda,driver=spice
balloon: 1024
bios: ovmf
boot: order=scsi0;ide2;net0
cores: 2
cpu: x86-64-v2-AES
efidisk0: ssd-data:101/vm-101-disk-0.qcow2,efitype=4m,ms-cert=2023w,pre-enrolled-keys=1,size=528K
ide2: none,media=cdrom
machine: q35
memory: 2048
name: UbuntuLTS
net0: virtio=BC:24:11:F2:A1:44,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: ssd-data:101/vm-101-disk-1.qcow2,iothread=1,size=32G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: ssd-data:101/vm-101-disk-2.qcow2,size=4M,version=v2.0
vga: qxl
````

---

## 2. Initial System Setup

Update the system to the latest patch level:

```bash
sudo apt update
sudo apt upgrade
```

Reboot if required:

```bash
sudo reboot
```

---

## 3. Install Required Packages

Install the Proxmox integration and SSH services:

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

---

## 4. Configure Passwordless Sudo

On Linux build and automation nodes, `sudo` is configured to allow
**passwordless execution** of required commands.

### 4.1 Edit sudoers configuration

Open the sudoers file using `visudo`:

```bash
sudo EDITOR=nano visudo
```

Locate the rule for `root` and **add the user-specific rule directly below**:

```text
root        ALL=(ALL) ALL
marelis     ALL=(ALL) NOPASSWD:ALL
```

---

### 4.2 Remove User from `sudo` Group

To avoid conflicts between group-based and user-specific sudo rules,
remove the user from the `sudo` group:

```bash
sudo deluser marelis sudo
```

> **Note**
> Membership in the `sudo` group grants elevated privileges that may
> override user-specific `NOPASSWD` rules. Removing the user ensures
> predictable, explicit behavior.

---

## 5. Configure SSH Access

### 5.1 Add Authorized SSH Keys

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

---

## 6. Test Connection

From a Linux or WSL host:

```bash
ssh marelis@192.168.88.101
```

Expected result:

```text
Welcome to Ubuntu 24.04.3 LTS

marelis@vm-ubuntu-lts:~$ whoami
marelis
```

Verify passwordless sudo:

```bash
sudo id
```

---

## Result

* VM is fully managed under **Proxmox** and listed in `vms.cfg`
* System is updated and integrated via **QEMU Guest Agent**
* SSH access uses **ED25519 key authentication**
* Passwordless sudo is configured for automation
* VM is suitable for **build, CI, and infrastructure workloads**
