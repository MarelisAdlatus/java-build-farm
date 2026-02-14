# Supported Linux Platforms & Validation Matrix

## Table of Contents

- [TIER 1 – Production Baseline (Release Blockers)](#tier-1--production-baseline-release-blockers)
- [TIER 2 – Desktop & UI (UX, Scaling, Dialogs)](#tier-2--desktop--ui-ux-scaling-dialogs)
- [TIER 3 – Modern Stack (Early Warning)](#tier-3--modern-stack-early-warning)
- [TIER 4 – Rolling Release Reality](#tier-4--rolling-release-reality)
- [TIER 5 – Edge & Specialized Environments](#tier-5--edge--specialized-environments)
- [Summary – The Optimal Test Matrix](#summary--the-optimal-test-matrix)
- [Operational Recommendations](#operational-recommendations)
- [Architecture Naming Conventions](#architecture-naming-conventions)

## TIER 1 – Production Baseline (Release Blockers)

These systems **define the baseline compatibility** for the project.

Failure on any of these targets = **No Release**.

### 1) **Ubuntu LTS**

(GNOME · X11 + Wayland)

- **Download:** [https://ubuntu.com/download/desktop](https://ubuntu.com/download/desktop)
- **Market Share:** ~30–35% of Linux desktops
- Primary target for most desktop users.
- GNOME reference implementation.
- Locales: `cs`, `en`, `de`, `fr`, etc.

### 2) **Debian Stable**

(GNOME)

- **Download:** [https://www.debian.org/releases/trixie/debian-installer](https://www.debian.org/releases/trixie/debian-installer)
- **Market Share:** ~15–20% (Desktop + Workstation)
- Conservative library versions.
- Unique installer stack.
- Target for long-term stability and servers.

### 3) **openSUSE Leap**

(KDE Plasma)

- **Download:** [https://get.opensuse.org/leap](https://get.opensuse.org/leap)
- **Market Share:** ~2–3%
- Enterprise-grade environment.
- RPM ecosystem.
- YaST integration (specific system dialogs).

### 4) **Rocky Linux**

(GNOME)

- **Download:** [https://rockylinux.org/cs-CZ/download](https://rockylinux.org/cs-CZ/download)
- **Market Share:** ~1–2% (Enterprise Desktop/Workstation)
- RHEL binary compatibility.
- Very stable, “legacy” userspace.
- Ideal for testing binaries and RPM installers.
- **Comparison Point:** Polar opposite to Fedora (Oldest vs. Newest host).

## TIER 2 – Desktop & UI (UX, Scaling, Dialogs)

Focused on modal dialogs, High DPI scaling, tray icons, and file pickers.

### 5) **Kubuntu LTS**

(KDE Plasma)

- **Download:** [https://kubuntu.org/download](https://kubuntu.org/download)
- **Market Share:** ~5–7%
- Qt-based environment.
- Distinct modal dialog behavior.
- Different file dialogs than GTK.

### 6) **Linux Mint**

(Cinnamon)

- **Download:** [https://linuxmint.com/download.php](https://linuxmint.com/download.php)
- **Market Share:** ~10–15%
- Traditional desktop paradigm.
- Large casual user base.
- Primarily X11-focused.

### 7) **Xubuntu LTS**

(XFCE)

- **Download:** [https://xubuntu.org/release/24.04](https://xubuntu.org/release/24.04)
- **Market Share:** ~3–5%
- Lightweight WM.
- Legacy UX model.
- Detects implicit GNOME assumptions.

## TIER 3 – Modern Stack (Early Warning)

Systems that **precede current LTS releases**.

### 8) **Fedora Workstation**

(GNOME · Wayland-first)

- **Download:** [https://fedoraproject.org/workstation/download](https://fedoraproject.org/workstation/download)
- **Market Share:** ~4–6%
- Cutting-edge GTK / Mesa / PipeWire.
- Frequently breaks legacy assumptions.

### 9) **Ubuntu (Non-LTS)**

(GNOME)

- **Download:** [https://ubuntu.com/download/desktop](https://ubuntu.com/download/desktop)
- **Market Share:** ~2–3%
- Preview of future Ubuntu LTS behavior.
- Installer and Snap/Flatpak shifts.

## TIER 4 – Rolling Release Reality

Used to detect ABI changes, regressions, and update-related issues.

### 10) **openSUSE Tumbleweed**

(KDE + GNOME)

- **Download:** [https://get.opensuse.org/tumbleweed](https://get.opensuse.org/tumbleweed)
- **Market Share:** ~2–3%
- Rolling release with strong QA.

## TIER 5 – Edge & Specialized Environments

Optional but **high-value for UI/WM-specific bugs**.

### 11) **Pop!_OS**

(COSMIC)

- **Download:** [https://system76.com/pop/download](https://system76.com/pop/download)
- **Market Share:** ~3–5%
- Non-traditional tiling-first workflow.
- Laptop + HiDPI optimizations.
- Diverges significantly from GNOME/KDE assumptions.

## Summary – The Optimal Test Matrix

| Area                                   | Covered |
| -------------------------------------- | ------- |
| GNOME / KDE / XFCE / Cinnamon / COSMIC | ✅      |
| LTS + Stable Releases                  | ✅      |
| Latest “Bleeding Edge”                 | ✅      |
| Rolling Releases                       | ✅      |
| DEB + RPM Ecosystems                   | ✅      |
| Enterprise (RHEL-like)                 | ✅      |
| X11 + Wayland                          | ✅      |
| Localization (cs + others)             | ✅      |

## Operational Recommendations

- **Tier 1:** Mandatory for CI and release gating.
- **Tier 2:** Mandatory manual GUI validation.
- **Tier 3:** Nightly / early warning CI.
- **Tier 4:** Investigate failures; not automatic blockers.
- **Tier 5:** Test during UI / WM refactors.

## Architecture Naming Conventions

While various names exist for the 64-bit architecture, the industry follows specific standards based on the context.

### The Canonical Name

#### ✅ **`x86_64`**

This is the **de-facto standard** in the Linux/Unix world.

- **Used by:** Linux Kernel, glibc, GNU toolchain, and most distributions.
- **Benefit:** Minimizes ambiguity across different build systems.

> **Recommendation:** Use **`x86_64`** for all internal logic and public-facing documentation.

### Equivalents (Technical Synonyms)

| Designation    | Context                | Note                   |
| -------------- | ---------------------- | ---------------------- |
| **`x86_64`**   | Linux / GNU / POSIX    | **Recommended Choice** |
| **`amd64`**    | Debian / Ubuntu / .deb | Legacy but common      |
| **`x64`**      | Marketing / Windows    | Vague, but understood  |
| **`x86-64`**   | Documentation          | Typographical variant  |
| **`EM64T`**    | Intel (Historical)     | **Deprecated**         |
| **`Intel 64`** | Intel Marketing        | **Deprecated**         |

### Distribution-Specific Naming

| Distribution          | Designation |
| --------------------- | ----------- |
| Ubuntu / Debian       | `amd64`     |
| Fedora / RHEL / Rocky | `x86_64`    |
| openSUSE              | `x86_64`    |

*Note: The difference is purely in the naming; the underlying architecture is identical.*

### Practical Implementation

#### Package Artifacts

```text
myapp-1.2.3-linux-x86_64.tar.gz
```

#### Documentation / Support Tables

```text
Platform: Linux (x86_64)
```

#### CI / Build Variables

```bash
uname -m                    # Returns x86_64
dpkg --print-architecture   # Returns amd64
```

**Normalization Strategy:** Always normalize build outputs to `x86_64`.

### What to Avoid

**`64-bit`** – Too ambiguous (could refer to ARM64/AArch64).

**`intel64`** – Marketing term, not a technical standard.

**`em64t`** – Obsolete.

**`x86`** – **Incorrect** (refers to 32-bit).

### Final Verdict

- **Universal Name:** `x86_64`
- **Debian Ecosystem:** Map `amd64 → x86_64` internally if necessary.
- **Public/Long-term:** Stick to `x86_64`.

:arrow_up: [Back to top](#supported-linux-platforms--validation-matrix)
