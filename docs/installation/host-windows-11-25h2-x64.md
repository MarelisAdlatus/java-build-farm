# Microsoft Windows 11 25H2 x64

This document describes a **repeatable installation and configuration procedure** for a Windows 11 Pro system acting as a **host**, not a virtual machine.

The system is part of the infrastructure inventory under **`hosts.cfg`**, not `vms.cfg`, and is accessed and administered **exclusively via SSH**.

The goal is:

- enable **OpenSSH Server**
- allow **key-based authentication only**
- disable password login
- ensure **correct ACLs**, which are critical on Windows
- restrict the SSH user from any interactive login (GUI / RDP)

## Contents

1. [Host Overview](#host-overview)
2. [Install Required Tools](#1-install-required-tools)
   - [Install PowerShell 7](#11-install-powershell-7)
3. [Install OpenSSH Server](#2-install-openssh-server)
4. [Enable and Configure SSH Service](#3-enable-and-configure-ssh-service)
   - [Enable service](#31-enable-service)
   - [Configure sshd_config](#32-configure-sshd_config)
5. [Create Local User for SSH Access](#4-create-local-user-for-ssh-access)
6. [Determine User Home Directory](#5-determine-user-home-directory)
7. [Configure SSH Keys](#6-configure-ssh-keys)
8. [Set Correct ACLs](#7-critical-set-correct-acls-windows-openssh-requirement)
9. [Test Connection](#8-test-connection)
10. [Restrict User Login to SSH Only](#9-restrict-user-login-to-ssh-only-disable-interactive-logon)
11. [Result](#result)

## Host Overview

- **OS:** Microsoft Windows 11 Pro 25H2 x64  
- **Role:** Host system (non-VM)
- **Inventory group:** `hosts.cfg`
- **Access model:** SSH-only administration
- **Purpose:** Infrastructure host / automation / management node

## 1. Install Required Tools

### 1.1 Install PowerShell 7

Download and install:

```text
PowerShell-7.5.4-win-x64.msi
```

Run **PowerShell as Administrator** for all following steps.

## 2. Install OpenSSH Server

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

## 3. Enable and Configure SSH Service

### 3.1 Enable service

```powershell
Set-Service sshd -StartupType Automatic
Start-Service sshd
```

### 3.2 Configure `sshd_config`

Open configuration file:

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

Set or verify:

```text
PubkeyAuthentication yes
PasswordAuthentication no
```

Administrators key file remains disabled:

```text
#Match Group administrators
#    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

Restart service:

```powershell
Restart-Service sshd
```

## 4. Create Local User for SSH Access

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

### 4.1 Force Creation of the User Profile Directory

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

## 5. Determine User Home Directory

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

## 6. Configure SSH Keys

### 6.1 Create `.ssh` structure

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

## 7. Critical: Set Correct ACLs (Windows OpenSSH Requirement)

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

## 8. Test Connection

From a Linux or WSL host:

```bash
ssh worker@<HOST-IP>
```

Expected login:

```text
Microsoft Windows [Version 11.0.xxxxx]

worker@<HOSTNAME> C:\Users\Worker> whoami
<hostname>\worker
```

Exit:

```text
exit
Connection closed.
```

## 9. Restrict User Login to SSH Only (Disable Interactive Logon)

The `Worker` account is intended **only for remote administration via SSH**.
All other interactive logon methods (console, RDP, local GUI login) are explicitly disabled.

This is enforced at the **local security policy level**, not by SSH itself.

### 9.1 Deny Local and Remote Interactive Logon

```powershell
secedit /export /cfg C:\Windows\Temp\secpol.cfg
notepad C:\Windows\Temp\secpol.cfg
```

Add or verify:

```ini
SeDenyInteractiveLogonRight = Worker
SeDenyRemoteInteractiveLogonRight = Worker
```

Apply policy:

```powershell
secedit /configure /db secedit.sdb /cfg C:\Windows\Temp\secpol.cfg /areas USER_RIGHTS
```

Reboot is recommended.

### 9.2 Resulting Access Model

| Access method            | Worker    |
| ------------------------ | --------- |
| SSH (OpenSSH)            | ✅ Allowed |
| Local console login      | ❌ Denied  |
| RDP                      | ❌ Denied  |
| GUI login                | ❌ Denied  |
| Service / scheduled task | ✅ Allowed |

## Result

- SSH access works using **ED25519 keys**
- Password login is disabled
- User is restricted from any interactive logon
- Configuration is suitable for **host-level automation and management**
- Host is safely integrated under `hosts.cfg`
