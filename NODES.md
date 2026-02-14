# Nodes

This document contains the currently documented build nodes used by the Java Build Farm.

Detailed installation and provisioning procedures are available in:

- `docs/installation/*.md`

## Table of Contents

- [Node Inventory](#node-inventory)
- [Installation and Node Provisioning](#installation-and-node-provisioning)
- [SSH Key-Based Authentication](#ssh-key-based-authentication)

## Node Inventory

These are the currently documented nodes.

**Host nodes (`hosts.cfg`):**

- **Windows 11 Pro 25H2 x64 (host)**  
  [Documentation](docs/installation/host-windows-11-25h2-x64.md)

**VM nodes (`vms.cfg` / Proxmox-managed):**

- **VM 100 – Windows 10 Pro 22H2 x64**  
  [Documentation](docs/installation/vm-100-windows-10-22h2-x64.md)

- **VM 101 – Ubuntu 24.04.3 LTS x86_64**  
  [Documentation](docs/installation/vm-101-ubuntu-24.04.3-lts-x86_64.md)

- **VM 102 – Debian 13.3 (Trixie) stable x86_64**  
  [Documentation](docs/installation/vm-102-debian-13.3-trixie-stable-x86_64.md)

- **VM 103 – openSUSE Leap 16.0 x86_64**  
  [Documentation](docs/installation/vm-103-opensuse-leap-16.0-x86_64.md)

- **VM 104 – Rocky Linux 10.1 x86_64**  
  [Documentation](docs/installation/vm-104-rocky-linux-10.1-x86_64.md)

- **VM 105 – Kubuntu 24.04.3 LTS x86_64**  
  [Documentation](docs/installation/vm-105-kubuntu-24.04.3-lts-x86_64.md)

- **VM 106 – Linux Mint 22.3 (Cinnamon) x86_64**  
  [Documentation](docs/installation/vm-106-linux-mint-22.3-cinnamon-x86_64.md)

- **VM 107 – Xubuntu 24.04.3 LTS x86_64**  
  [Documentation](docs/installation/vm-107-xubuntu-24.04.3-lts-x86_64.md)

- **VM 108 – Fedora Workstation 43 x86_64**  
  [Documentation](docs/installation/vm-108-fedora-workstation-43-x86_64.md)

- **VM 109 – Ubuntu 25.10 (non-LTS) x86_64**  
  [Documentation](docs/installation/vm-109-ubuntu-25.10-x86_64.md)

- **VM 110 – openSUSE Tumbleweed x86_64**  
  [Documentation](docs/installation/vm-110-opensuse-tumbleweed-x86_64.md)

- **VM 111 – Pop!_OS 24.04 LTS x86_64**  
  [Documentation](docs/installation/vm-111-pop!_os-24.04-lts-x86_64.md)

## Installation and Node Provisioning

All installation and provisioning procedures are maintained in:

- `docs/installation/*.md`

This includes:

- Proxmox VM reference configs (`qm config ...`)
- OS installation steps
- PowerShell installation and OpenSSH setup on Windows nodes
- passwordless sudo configuration on Linux nodes
- distro-specific firewall and SSH enablement details

Use the per-node documents above as the source of truth.

## SSH Key-Based Authentication

The build farm relies on SSH for remote execution and artifact transfer.

### Generate an SSH key (on the machine running `farm.sh`)

```sh
ssh-keygen -t ed25519 -C "build-farm-key" -f ~/.ssh/id_ed25519
````

Copy the public key to nodes:

- Manual method: append to `~/.ssh/authorized_keys` on Linux nodes
- Automated method (Linux): `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host`

> Windows nodes use OpenSSH Server and Windows ACL rules.
> Exact steps are documented per node under `docs/installation/`.
