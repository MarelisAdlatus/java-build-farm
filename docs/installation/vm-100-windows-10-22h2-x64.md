# Microsoft Windows 10 22H2 x64

This document describes a **repeatable installation and configuration procedure** for a Windows 10 Pro virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The goal is:

- enable **OpenSSH Server**
- allow **key-based authentication only**
- disable password login
- ensure **correct ACLs**, which are critical on Windows
- restrict the SSH user from any interactive login (GUI / RDP)

---

## Contents

1. [VM Overview](#vm-overview)
2. [VM Classification and Management Scope](#vm-classification-and-management-scope)
3. [Proxmox VM Reference Configuration](#1-proxmox-vm-reference-configuration)
4. [Install Required Drivers and Tools](#2-install-required-drivers-and-tools)
   - [VirtIO Drivers](#21-virtio-drivers)
   - [Install PowerShell 7](#22-install-powershell-7)
5. [Install OpenSSH Server](#3-install-openssh-server)
6. [Enable and Configure SSH Service](#4-enable-and-configure-ssh-service)
   - [Enable service](#41-enable-service)
   - [Configure sshd_config](#42-configure-sshd_config)
7. [Create Local User for SSH Access](#5-create-local-user-for-ssh-access)
8. [Determine User Home Directory](#6-determine-user-home-directory)
9. [Configure SSH Keys](#7-configure-ssh-keys)
10. [Set Correct ACLs](#8-critical-set-correct-acls-windows-openssh-requirement)
11. [Test Connection](#9-test-connection)
12. [Restrict User Login to SSH Only](#10-restrict-user-login-to-ssh-only-disable-interactive-logon)
13. [Result](#result)

---

## VM Overview

- **OS:** Microsoft Windows 10 Pro 22H2 x64  
- **Hostname:** `VM-WIN10`
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Farm node / remote administration via SSH

---

## VM Classification and Management Scope

This system is classified as a **virtual machine** and is part of the `vms.cfg` inventory group.

Characteristics of `vms.cfg` nodes:

- managed and lifecycle-controlled by **Proxmox**
- expected to be **rebuildable and replaceable**
- configuration stored and auditable at the hypervisor level
- access primarily via **SSH**, not interactive login
- suitable for automation, orchestration, and VM farm workloads

This classification distinguishes the system from physical or host-level
machines listed under `hosts.cfg`, which are **not** managed by Proxmox
and follow a different persistence and trust model.

---

## 1. Proxmox VM Reference Configuration

> This is a reference snapshot of the VM configuration used for this node.  
> It is **not required** for daily operation, but useful for auditing, cloning, or rebuilding the farm.

```ini
agent: 1
audio0: device=ich9-intel-hda,driver=spice
balloon: 2048
bios: ovmf
boot: order=scsi0;ide2;net0
cores: 4
cpu: x86-64-v2-AES
efidisk0: local-lvm:vm-100-disk-0,efitype=4m,ms-cert=2023,pre-enrolled-keys=1,size=4M
ide2: none,media=cdrom
machine: pc-q35-10.1
memory: 4096
name: Win10
net0: virtio=BC:24:11:55:0B:B1,bridge=vmbr0,firewall=1
onboot: 1
ostype: win10
scsi0: local-lvm:vm-100-disk-1,iothread=1,size=96G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tpmstate0: local-lvm:vm-100-disk-2,size=4M,version=v2.0
vga: qxl
````

---

## 2. Install Required Drivers and Tools

### 2.1 VirtIO Drivers

Mount and install drivers from:

```
virtio-win-0.1.285.iso
```

Install:

* network
* storage
* balloon
* guest agent

---

### 2.2 Install PowerShell 7

Download and install:

```
PowerShell-7.5.4-win-x64.msi
```

Run **PowerShell as Administrator**.

---

## 3. Install OpenSSH Server

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Verify installation:

```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
```

Expected state:

```
OpenSSH.Client  Installed
OpenSSH.Server  Installed
```

---

## 4. Enable and Configure SSH Service

### 4.1 Enable service

```powershell
Set-Service sshd -StartupType Automatic
Start-Service sshd
```

---

### 4.2 Configure `sshd_config`

Open configuration file:

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

Set or verify:

```text
PubkeyAuthentication yes
PasswordAuthentication no
```

Administrators key file left disabled:

```text
#Match Group administrators
#    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

Restart service:

```powershell
Restart-Service sshd
```

---

## 5. Create Local User for SSH Access

Create user:

```powershell
net user Worker /add /expires:never
net localgroup Administrators Worker /add
```

Set password manually:

```
WIN + R → lusrmgr.msc
```

* set password
* password never expires

---

## 6. Determine User Home Directory

```powershell
$sid = (Get-LocalUser Worker).SID.Value
Get-ItemProperty `
  "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" |
  Select-Object ProfileImagePath
```

Expected result:

```
C:\Users\worker.VM-WIN10
```

---

## 7. Configure SSH Keys

### 7.1 Create `.ssh` structure

```powershell
New-Item -ItemType Directory -Force C:\Users\worker.VM-WIN10\.ssh | Out-Null
echo "" > C:\Users\worker.VM-WIN10\.ssh\authorized_keys
notepad C:\Users\worker.VM-WIN10\.ssh\authorized_keys
```

Insert public keys:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBH9oiMFtQIMn9n6ljjiu+i9c2Z9qi7VnfXTlApTpe2e marelis@DESKTOP-MARELIS
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuEMOpt2H3hDrkkuzn8rPP4IY2BNNr+eOhyNp7yr+Al marelis@NTB-MARELIS
```

---

## 8. Critical: Set Correct ACLs (Windows OpenSSH Requirement)

Incorrect permissions **will break SSH login**.

```powershell
icacls C:\Users\worker.VM-WIN10\.ssh /inheritance:r
icacls C:\Users\worker.VM-WIN10\.ssh `
  /grant "Worker:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F"

icacls C:\Users\worker.VM-WIN10\.ssh\authorized_keys /inheritance:r
icacls C:\Users\worker.VM-WIN10\.ssh\authorized_keys `
  /grant "Worker:F" "SYSTEM:F" "Administrators:F"
```

Restart SSH service:

```powershell
Restart-Service sshd
```

---

## 9. Test Connection

From a Linux or WSL host:

```bash
ssh worker@192.168.88.100
```

Expected login:

```text
Microsoft Windows [Version 10.0.19045.xxxx]

worker@VM-WIN10 C:\Users\worker.VM-WIN10> whoami
vm-win10\worker
```

Exit:

```text
exit
Connection closed.
```

---

## 10. Restrict User Login to SSH Only (Disable Interactive Logon)

The `Worker` account is intended **only for remote administration via SSH**.
All other interactive logon methods (console, RDP, local GUI login) are explicitly disabled.

This is enforced at the **local security policy level**, not by SSH itself.

---

### 10.1 Deny Local and Remote Interactive Logon

```powershell
secedit /export /cfg C:\Windows\Temp\secpol.cfg
notepad C:\Windows\Temp\secpol.cfg
```

Add or verify:

```ini
SeDenyInteractiveLogonRight = Worker
SeDenyRemoteInteractiveLogonRight = Worker
```

Apply the policy:

```powershell
secedit /configure /db secedit.sdb /cfg C:\Windows\Temp\secpol.cfg /areas USER_RIGHTS
```

Reboot is recommended but not strictly required.

---

### 10.2 Resulting Access Model

| Access method            | Worker    |
| ------------------------ | --------- |
| SSH (OpenSSH)            | ✅ Allowed |
| Local console login      | ❌ Denied  |
| RDP                      | ❌ Denied  |
| GUI login                | ❌ Denied  |
| Service / scheduled task | ✅ Allowed |

---

## Result

* SSH access works using **ED25519 keys**
* Password login is disabled
* User is restricted from any interactive logon
* Configuration is suitable for **automated VM farm usage**
* Node is fully managed under the `vms.cfg` / Proxmox lifecycle model
