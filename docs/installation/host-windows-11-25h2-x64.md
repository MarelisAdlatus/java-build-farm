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
All other interactive logon methods (console, RDP, local GUI login) are explicitly denied.

This restriction is enforced by **Local Security Policy (User Rights Assignment)**, not by SSH itself.

> On Windows 11 (and hardened Windows 10 builds), these rights must be assigned using the **account SID**.
> Name-based assignment is unreliable and may fail with *“No mapping between account names and security IDs”*.

### Step 1 - Obtain the SID of the `Worker` Account

Run:

```powershell
(Get-LocalUser Worker).SID.Value
```

Example:

```powershell
S-1-5-21-1838155332-2738559885-318569030-1002
```

### Step 2 - Export the Current Security Policy

```powershell
secedit /export /cfg C:\Windows\Temp\secpol.cfg
```

Then open the file for editing:

```powershell
notepad C:\Windows\Temp\secpol.cfg
```

### Step 3 - Add the Deny Logon Rights Using the SID

Insert or modify the following lines (use your actual SID):

```ini
SeDenyInteractiveLogonRight = *S-1-5-21-1838155332-2738559885-318569030-1002
SeDenyRemoteInteractiveLogonRight = *S-1-5-21-1838155332-2738559885-318569030-1002
```

Important notes:

- The `*` prefix **is required** by the security template format.
- Do **not** use:
  - `Worker`
  - `.\Worker`
  - `COMPUTERNAME\Worker`
- Although later exports may display `Worker`, Windows internally stores only the SID.

### Step 4 - Save With Correct Encoding

Security templates must remain **UTF-16 LE**.
Saving as UTF-8 will cause `secedit` import errors.

### Step 5 - Apply the Modified Policy

Always apply to the existing local security database:

```powershell
secedit /configure ^
 /db C:\Windows\Security\Database\local.sdb ^
 /cfg C:\Windows\Temp\secpol.cfg ^
 /areas USER_RIGHTS
```

### Step 6 - Reboot (Recommended)

```powershell
shutdown /r /t 0
```

### Verification (Optional)

Re-export to confirm the assignment:

```powershell
secedit /export /cfg C:\Windows\Temp\check.cfg
```

You may now see `Worker` instead of the SID — this is normal.
Windows resolves the SID back to a readable name during export.

### Behavior Notes (Windows 11 Specific)

- `SeDenyRemoteInteractiveLogonRight` may **not appear in the first export** if it has never been configured before.
  Windows creates this right only after it is first referenced.

- On some Windows 11 systems, the first `secedit /configure` run initializes the internal record but still fails with:

  ```text
  No mapping between account names and security IDs
  ```

  This is a one-time initialization behavior of the Local Security Authority (LSA).

- If this happens, repeat the process using a fresh export:

  1. Export the policy again:

     ```powershell
     secedit /export /cfg C:\Windows\Temp\secpol.cfg
     ```

  2. Re-open the file and re-apply the same SID-based entries.

  3. Run `secedit /configure` again.

  The second pass succeeds because the user-right object now exists in the security database.

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
