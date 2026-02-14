# Java Build Farm

<p align="center">
  <img src="docs/images/app-image.png" width="640" alt="Application screenshot – main window with feature overview">
</p>

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Platforms and Test Matrix](#platforms-and-test-matrix)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Usage](#usage)
- [Build Nodes and Inventory](#build-nodes-and-inventory)
- [License](#license)

## Overview

Java Build Farm is a script-based automation system for building and packaging Java applications across multiple operating systems and distributions. It enables automatic dependency installation, building, and distribution of Java applications using Proxmox virtual machines and remote hosts.

> The RadioRec application is used as an example. More information can be found in the repository on **[GitHub](https://github.com/MarelisAdlatus/radiorec)**.

## Features

- Automated dependency installation for Linux and Windows hosts
- Support for multiple operating systems and distributions:
  - Windows (10/11)
  - Debian, Ubuntu (LTS and non-LTS), Fedora, Rocky Linux, openSUSE (Leap/Tumbleweed), Linux Mint, Pop!_OS
- SSH-based remote execution and deployment
- Java Runtime creation using `jlink`
- Application packaging using `jpackage`
- Native package generation depends on platform tooling availability.
  Some rolling distributions generate archive/app-image outputs only.
- Automated RPM package signing using GPG
- `.exe` installer builds using [Inno Setup Compiler](https://jrsoftware.org/isinfo.php)
- Remote VM/host provisioning via Proxmox (optional)
- Secure, passwordless SSH authentication
- Remote release export via SSH (incremental mirror upload)
- Automatic dark-themed HTML release index generation

## Platforms and Test Matrix

The supported platform tiers (baseline targets, UI/UX targets, rolling releases, etc.) are defined in:

- **[`PLATFORMS.md`](PLATFORMS.md)**

This document is the source of truth for:

- release blocker targets (Tier 1)
- extended desktop/UI coverage (Tier 2+)
- rolling release early warning targets
- naming conventions (normalize to `x86_64`)

## Prerequisites

### On Java Build Farm (local machine)

- **Linux with GNU Bash**
- **Internet access**
- **SSH client:** `ssh`, `scp` (optional: `rsync` for incremental mirror export)
- **Other utilities:** `sudo`, `bash`, `tar`, `find`, `awk`, `sed`, `cut`, `head`, `tr`, `rm`, `mkdir`, `chmod`
- **Proxmox:** (optional, only if using Proxmox for VM lifecycle actions in the menu)
- **PowerShell 7+:** (only needed if you build on Windows targets)

### On Build Nodes (remote machines)

- **Internet access**
- **SSH Server** with key-based authentication enabled
- **Linux nodes:** `sudo` configured for non-interactive execution (passwordless sudo is recommended for automation)
- **Windows nodes:** PowerShell 7+ and OpenSSH Server (key-based login recommended)

> Detailed per-node installation procedures (including PowerShell installation and passwordless sudo configuration) are documented under `docs/installation/`.

## Directory Structure

```text
java-build-farm/
├── LICENSE
├── NODES.md                         # Project documentation
├── PLATFORMS.md
├── README.md
├── RELEASE.md
├── apps/                            # Source code and metadata for applications
│   └── AppName/
│       └── 1.0/                     # Application version folder
│           ├── AppName.iss          # Windows installer (Inno Setup script)
│           ├── AppName.properties   # File association definitions
│           ├── AppName.ps1          # Build script for Windows
│           ├── AppName.sh           # Build script for Linux
│           ├── addons/              # Additional resources such as licenses
│           │   └── License.txt
│           ├── build/               # Compiled application JARs
│           │   ├── AppName-1.0.jar
│           │   └── libs/            # Required libraries
│           │       ├── *.jar
│           └── icons/               # Application icons
│               ├── *.ico
│               └── *.png
├── config/                          # Build environment definitions
│   ├── global.cfg
│   ├── hosts.cfg
│   └── vms.cfg
├── depends.ps1                      # Dependency setup for Windows
├── depends.sh                       # Dependency setup for Linux
├── docs/
│   ├── images/
│   └── installation/                # Node setup documentation (VMs and hosts)
├── export.sh                        # Remote export post-process script
├── farm.sh                          # Central build and packaging script
└── release/                         # Output directory for generated packages
    └── appname/                     # normalized lowercase app id
        └── 1.0/
            └── *-*/                 # Platform-specific folders (OS + version + arch)
                ├── *.deb            # Debian packages
                ├── *.rpm            # RPM packages
                ├── *.exe            # Windows installers
                ├── *.zip            # Portable builds
                └── *.tar.gz         # Archive versions
```

## Usage

### Running `farm.sh`

Execute the main script to access the menu:

```sh
./farm.sh
```

Example output:

```text
This script is for building applications on remote VMs and hosts

Proxmox VM Manager (192.168.88.3)

Action ?
1) Check
2) Dependencies
3) Clean
4) Build
5) Download (URL paths)
6) Export
7) VMs Status
8) VMs Start
9) VMs Stop
q) Quit
#?
```

Select an action by entering the corresponding number or <kbd>q</kbd> for exit.

### Menu Options (high level)

- **1) Check**
  Verifies SSH connectivity and basic prerequisites on all configured nodes.

- **2) Dependencies**
  Installs required OS packages/tools on remote nodes by running:

  - `depends.sh` on Linux targets
  - `depends.ps1` on Windows targets

- **3) Clean**
  Deletes remote build artifacts and local release outputs for a selected app/version.

- **4) Build**
  Copies app sources to targets and runs platform-specific build scripts (`.sh` / `.ps1`).

- **5) Download**
  Downloads produced artifacts via SSH/SCP into the local `release/` structure.
  Optionally normalizes directory names when `release_url_paths=yes`.

- **6) Export**  
  Exports the local `release/` directory to a remote Linux export target via SSH.  
  The export step can perform remote RPM signing, generate SHA256 checksums, and create a publish-ready HTML release index.

  See: **[RELEASE.md](RELEASE.md)** for full workflow and configuration details.

- **7–9) VM lifecycle (optional)**
  Available only when Proxmox is configured in `config/global.cfg`.
  Used for VM status/start/stop operations.

## Build Nodes and Inventory

The build farm can use:

- **Proxmox virtual machines** (defined in `config/vms.cfg`)
- **Remote hosts** (defined in `config/hosts.cfg`)

Configuration files:

- `config/global.cfg`
  Global settings (paths, optional Proxmox access, GPG key ID, etc.)

- `config/vms.cfg`
  Proxmox-managed VMs (VM ID + SSH endpoint). Used by VM lifecycle menu actions.

- `config/hosts.cfg`
  Non-Proxmox machines reachable via SSH (workstations, servers, etc.)

### Current node set (documentation reference)

The current list of documented build nodes is maintained in:

- **[NODES.md](NODES.md)**

Detailed installation and provisioning steps for each node live in `docs/installation/`.

## License

This project is licensed under the [Apache License 2.0](LICENSE).

:arrow_up: [Back to top](#java-build-farm)
