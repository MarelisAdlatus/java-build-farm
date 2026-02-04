# 🧱 TIER 1 – Production Baseline (Release Blockers)

These systems **define the baseline compatibility** for the project.

❌ Failure on any of these targets = **No Release**.

---

## 1) **Ubuntu LTS**

(GNOME · X11 + Wayland)

* **Download:** [Link](https://ubuntu.com/download/desktop)
* **Market Share:** ~30–35% of Linux desktops
* Primary target for most desktop users.
* GNOME reference implementation.
* Standard Flatpak environment.
* Locales: `cs`, `en`, `de`, `fr`, etc.

---

## 2) **Debian Stable**

(GNOME)

* **Download:** [Link](https://www.debian.org/releases/trixie/debian-installer)
* **Market Share:** ~15–20% (Desktop + Workstation)
* Conservative library versions.
* Unique installer stack.
* Target for long-term stability and servers.

---

## 3) **openSUSE Leap**

(KDE Plasma)

* **Download:** [Link](https://get.opensuse.org/leap)
* **Market Share:** ~2–3%
* Enterprise-grade environment.
* RPM ecosystem.
* YaST integration (specific system dialogs).

---

## 4) **Rocky Linux**

(GNOME)

* **Download:** [Link](https://rockylinux.org/cs-CZ/download)
* **Market Share:** ~1–2% (Enterprise Desktop/Workstation)
* RHEL binary compatibility.
* Very stable, "legacy" userspace.
* Ideal for testing binaries and RPM installers.
* **Comparison Point:** Serves as the polar opposite to Fedora (Oldest vs. Newest host).

---

# 🪟 TIER 2 – Desktop & UI (UX, Scaling, Dialogs)

Focused on catching issues with modal dialogs, High DPI scaling, tray icons, and file pickers.

---

## 5) **Kubuntu LTS**

(KDE Plasma)

* **Download:** [Link](https://kubuntu.org/download)
* **Market Share:** ~5–7%
* Qt-based environment.
* Distinct modal dialog behavior.
* Uses different file dialogs compared to GTK.

---

## 6) **Linux Mint**

(Cinnamon)

* **Download:** [Link](https://linuxmint.com/download.php)
* **Market Share:** ~10–15%
* Traditional desktop paradigm.
* Large casual user base.
* Primarily X11-focused.

---

## 7) **Xubuntu LTS**

(XFCE)

* **Download:** [Link](https://xubuntu.org/release/24.04)
* **Market Share:** ~3–5%
* Lightweight Window Manager.
* Legacy UX model.
* Helps identify implicit GNOME dependencies.

---

# 🧭 TIER 3 – Modern Stack (Early Warning)

Systems that **precede current LTS releases**.

---

## 8) **Fedora Workstation**

(GNOME · Wayland-first)

* **Download:** [Link](https://fedoraproject.org/workstation/download)
* **Market Share:** ~4–6%
* Cutting-edge GTK / Mesa / PipeWire.
* Flatpak as a primary standard.
* Often breaks "legacy" assumptions.

---

## 9) **Ubuntu (Non-LTS)**

(GNOME)

* **Download:** [Link](https://ubuntu.com/download/desktop)
* **Market Share:** ~2–3%
* Preview of future Ubuntu LTS behavior.
* Installer changes and Snap/Flatpak relationship shifts.

---

# 🔁 TIER 4 – Rolling Release Reality

Used to detect ABI changes, regressions, and update-related issues.

---

## 10) **openSUSE Tumbleweed**

(KDE + GNOME)

* **Download:** [Link](https://get.opensuse.org/tumbleweed)
* **Market Share:** ~2–3%
* Rolling release with rigorous QA.
* Strong Flatpak integration.

---

### 11) **Manjaro**

(KDE / XFCE)

* **Download:** [Link](https://manjaro.org/products/download/x86)
* **Market Share:** ~6–8%
* Arch-based ecosystem.
* Unique library paths and toolchain versions.

---

# 🧪 TIER 5 – Edge & Specialized Environments

Optional but **highly valuable for UI-specific bug hunting**.

---

## 12) **Pop!_OS**

(COSMIC)

* **Download:** [Link](https://system76.com/pop/download)
* **Market Share:** ~3–5%
* Non-traditional window management (Auto-tiling).
* High DPI and laptop-specific optimizations.
* Distinct workflow from vanilla GNOME/KDE.

---

## 13) **Ubuntu Budgie**

(Budgie)

* **Download:** [Link](https://ubuntubudgie.org/downloads)
* **Market Share:** ~1–2%
* Alternative panel and dialog implementation.
* Catches layout assumption bugs.

---

# 📊 Summary – The Optimal Test Matrix

| Area | Covered |
| --- | --- |
| GNOME / KDE / XFCE / Cinnamon / COSMIC / Budgie | ✅ |
| LTS + Stable Releases | ✅ |
| Latest "Bleeding Edge" | ✅ |
| Rolling Releases | ✅ |
| DEB + RPM + Arch Ecosystems | ✅ |
| Enterprise (RHEL-like) | ✅ |
| X11 + Wayland | ✅ |
| Flatpak Portals | ✅ |
| Localization (cs + others) | ✅ |

---

# 🎯 Operational Recommendations

* **Tier 1:** Always included in automated testing/CI.
* **Tier 2:** Mandatory manual verification before any GUI release.
* **Tier 3:** CI / Nightly builds (Early warning system).
* **Tier 4:** Monitor trends; failures should be investigated but are not necessarily release blockers.
* **Tier 5:** Test during significant UI/Window Management refactors.

---

# 🏗️ Architecture Naming Conventions

While various names exist for the 64-bit architecture, the industry follows specific standards based on the context.

## The Canonical Name

### ✅ **`x86_64`**

This is the **de-facto standard** in the Linux/Unix world.

* **Used by:** Linux Kernel, glibc, GNU toolchain, and most distributions.
* **Benefit:** Minimizes ambiguity across different build systems.

> **Recommendation:** Use **`x86_64`** for all internal logic and public-facing documentation.

---

## Equivalents (Technical Synonyms)

| Designation | Context | Note |
| --- | --- | --- |
| **`x86_64`** | Linux / GNU / POSIX | **Recommended Choice** |
| **`amd64`** | Debian / Ubuntu / .deb | Legacy but common |
| **`x64`** | Marketing / Windows | Vague, but understood |
| **`x86-64`** | Documentation | Typographical variant |
| **`EM64T`** | Intel (Historical) | **Deprecated** |
| **`Intel 64`** | Intel Marketing | **Deprecated** |

---

## Distribution-Specific Naming

| Distribution | Designation |
| --- | --- |
| Ubuntu / Debian | `amd64` |
| Fedora / RHEL / Rocky | `x86_64` |
| openSUSE | `x86_64` |
| Arch / Manjaro | `x86_64` |
| Flatpak | `x86_64` |

*Note: The difference is purely in the naming; the underlying architecture is identical.*

---

## Practical Implementation

### 📦 Package Artifacts

```text
myapp-1.2.3-linux-x86_64.tar.gz

```

### 🧾 Documentation / Support Tables

```text
Platform: Linux (x86_64)

```

### 🧪 CI / Build Variables

```bash
uname -m                    # Returns x86_64
dpkg --print-architecture   # Returns amd64

```

**Normalization Strategy:** Always normalize build outputs to `x86_64`.

---

## What to Avoid

❌ **`64-bit`** – Too ambiguous (could refer to ARM64/AArch64).

❌ **`intel64`** – Marketing term, not a technical standard.

❌ **`em64t`** – Obsolete.

❌ **`x86`** – **Incorrect** (refers to 32-bit).

---

## Final Verdict

* **Universal Name:** `x86_64`
* **Debian Ecosystem:** Map `amd64 → x86_64` internally if necessary.
* **Public/Long-term:** Stick to `x86_64`.

---
