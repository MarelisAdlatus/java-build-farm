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

- [Host Overview](#host-overview)
- [Install Required Tools](#install-required-tools)
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

## Host Overview

- **OS:** Microsoft Windows 11 Pro 25H2 x64  
- **Role:** Host system (non-VM)
- **Inventory group:** `hosts.cfg`
- **Access model:** SSH-only administration
- **Purpose:** Infrastructure host / automation / management node

## Install Required Tools

### Install PowerShell 7

Download and install:

```text
PowerShell-7.5.4-win-x64.msi
```

Run **PowerShell as Administrator** for all following steps.

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

Administrators key file remains disabled:

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
- Configuration is suitable for **host-level automation and management**
- Host is safely integrated under `hosts.cfg`
