# Microsoft Windows 10 22H2 x64

This document describes a **repeatable installation and configuration procedure** for a Windows 10 Pro virtual machine running on **Proxmox**, prepared as part of a larger VM farm.

The goal is:

- enable **OpenSSH Server**
- allow **key-based authentication only**
- disable password login
- ensure **correct ACLs**, which are critical on Windows
- restrict the SSH user from any interactive login (GUI / RDP)

## Contents

- [VM Overview](#vm-overview)
- [VM Classification and Management Scope](#vm-classification-and-management-scope)
- [Proxmox VM Reference Configuration](#proxmox-vm-reference-configuration)
- [Install Required Drivers and Tools](#install-required-drivers-and-tools)
  - [VirtIO Drivers](#virtio-drivers)
  - [Install PowerShell 7](#install-powershell-7)
- [Install OpenSSH Server](#install-openssh-server)
- [Enable and Configure SSH Service](#enable-and-configure-ssh-service)
  - [Enable service](#enable-service)
  - [Configure sshd_config](#configure-sshd_config)
- [Create Local User for SSH Access](#create-local-user-for-ssh-access)
- [Determine User Home Directory](#determine-user-home-directory)
- [Configure SSH Keys](#configure-ssh-keys)
- [Set Correct ACLs](#critical-set-correct-acls-windows-openssh-requirement)
- [Test Connection](#test-connection)
- [Restrict User Login to SSH Only](#restrict-user-login-to-ssh-only-disable-interactive-logon)
- [Result](#result)

## VM Overview

- **OS:** Microsoft Windows 10 Pro 22H2 x64  
- **Hostname:** `VM-WIN10`
- **Hypervisor:** Proxmox VE
- **Inventory group:** `vms.cfg`
- **Management domain:** Proxmox-managed virtual machines
- **Purpose:** Farm node / remote administration via SSH

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

## Proxmox VM Reference Configuration

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
```

## Install Required Drivers and Tools

### VirtIO Drivers

Mount and install drivers from:

```text
virtio-win-0.1.285.iso
```

Install:

- network
- storage
- balloon
- guest agent

### Install PowerShell 7

Download and install:

```text
PowerShell-7.5.4-win-x64.msi
```

Run **PowerShell as Administrator**.

## Install OpenSSH Server

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Verify installation:

```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
```

Expected state:

```powershell
OpenSSH.Client  Installed
OpenSSH.Server  Installed
```

## Enable and Configure SSH Service

### Enable service

```powershell
Set-Service sshd -StartupType Automatic
Start-Service sshd
```

### Configure `sshd_config`

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

## Create Local User for SSH Access

Create a dedicated automation / administration user:

```powershell
net user Worker /add /expires:never
net localgroup Administrators Worker /add
```

Set the password **manually** (required — profile is not created until first credentialed logon):

```text
WIN + R → lusrmgr.msc
```

- set password
- optionally set *Password never expires* (operational account)
- close the dialog

Verify account state:

```powershell
Get-LocalUser Worker | fl Name,Enabled,PasswordRequired,PasswordLastSet
```

Expected example:

```text
Name             : Worker
Enabled          : True
PasswordRequired : True
PasswordLastSet  : <timestamp>
```

### Force Creation of the User Profile Directory

Windows does **not create** `C:\Users\Worker` until the first logon with a loaded profile.
Because this account must never log in interactively, the profile must be initialized programmatically.

Run a one-time credentialed process to force profile materialization:

```powershell
$u="$env:COMPUTERNAME\Worker"
$p=Read-Host "Password" -AsSecureString
$c=New-Object PSCredential($u,$p)
Start-Process -FilePath "cmd.exe" -ArgumentList "/c exit" `
  -Credential $c -LoadUserProfile -Wait
```

This performs a non-interactive logon and immediately exits, but causes Windows to:

- create `C:\Users\Worker`
- generate the registry profile mapping
- establish the SID ↔ profile linkage required by OpenSSH

Verify profile existence:

```powershell
Test-Path "C:\Users\Worker"
```

Expected:

```text
True
```

Only after this step is it safe to continue with `.ssh` creation and ACL configuration.

## Determine User Home Directory

```powershell
$sid = (Get-LocalUser Worker).SID.Value
Get-ItemProperty `
  "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" |
  Select-Object ProfileImagePath
```

Expected result:

```powershell
C:\Users\Worker
```

## Configure SSH Keys

### Create `.ssh` structure

```powershell
New-Item -ItemType Directory -Force C:\Users\Worker\.ssh | Out-Null
echo "" > C:\Users\Worker\.ssh\authorized_keys
notepad C:\Users\Worker\.ssh\authorized_keys
```

Insert public keys:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBH9oiMFtQIMn9n6ljjiu+i9c2Z9qi7VnfXTlApTpe2e marelis@DESKTOP-MARELIS
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuEMOpt2H3hDrkkuzn8rPP4IY2BNNr+eOhyNp7yr+Al marelis@NTB-MARELIS
```

## Critical: Set Correct ACLs (Windows OpenSSH Requirement)

Incorrect permissions **will break SSH login**.

```powershell
icacls C:\Users\Worker\.ssh /inheritance:r
icacls C:\Users\Worker\.ssh `
  /grant "Worker:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F"

icacls C:\Users\Worker\.ssh\authorized_keys /inheritance:r
icacls C:\Users\Worker\.ssh\authorized_keys `
  /grant "Worker:F" "SYSTEM:F" "Administrators:F"
```

Restart SSH service:

```powershell
Restart-Service sshd
```

## Test Connection

From a Linux or WSL host:

```bash
ssh worker@192.168.88.100
```

Expected login:

```text
Microsoft Windows [Version 10.0.19045.xxxx]

worker@VM-WIN10 C:\Users\Worker> whoami
vm-win10\worker
```

Exit:

```text
exit
Connection closed.
```

## Restrict User Login to SSH Only (Disable Interactive Logon)

The `Worker` account is intended **only for remote administration via SSH**.
All other interactive logon methods (console, RDP, local GUI login) are explicitly disabled.

This restriction is enforced at the **Local Security Policy level**, not by SSH itself.

> ⚠️ On modern Windows versions (Windows 11 and hardened Windows 10 builds),
> user rights must be assigned using the **SID**, not the account name.

### 1) Obtain the SID of the Worker Account

```powershell
(Get-LocalUser Worker).SID.Value
```

Example result:

```text
S-1-5-21-1838155332-2738559885-318569030-1002
```

### 2) Export Current Security Policy

```powershell
secedit /export /cfg C:\Windows\Temp\secpol.cfg
notepad C:\Windows\Temp\secpol.cfg
```

### 3) Add (or Modify) These Entries Using the SID

> The `*` prefix is required by the INF security template format.

```ini
SeDenyInteractiveLogonRight = *S-1-5-21-1838155332-2738559885-318569030-1002
SeDenyRemoteInteractiveLogonRight = *S-1-5-21-1838155332-2738559885-318569030-1002
```

Do **not** use:

```text
Worker
.\Worker
COMPUTERNAME\Worker
```

Only the SID is reliable across Windows versions.

### 4) Save File with Correct Encoding

When saving in Notepad:

```text
Encoding: Unicode
```

(Security templates must remain UTF-16 LE. UTF-8 will cause `secedit` failure.)

### 5) Apply the Policy

Use the existing local security database:

```powershell
secedit /configure /db C:\Windows\Security\Database\local.sdb /cfg C:\Windows\Temp\secpol.cfg /areas USER_RIGHTS
```

### 6) Reboot (Recommended)

```powershell
shutdown /r /t 0
```

### Resulting Access Model

| Access method            | Worker     |
| ------------------------ | ---------- |
| SSH (OpenSSH)            | ✅ Allowed |
| Local console login      | ❌ Denied  |
| RDP                      | ❌ Denied  |
| GUI login                | ❌ Denied  |
| Service / scheduled task | ✅ Allowed |

## Result

- SSH access works using **ED25519 keys**
- Password login is disabled
- User is restricted from any interactive logon
- Configuration is suitable for **automated VM farm usage**
- Node is fully managed under the `vms.cfg` / Proxmox lifecycle model
