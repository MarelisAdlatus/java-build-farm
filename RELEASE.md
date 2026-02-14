# Release Publishing and Signing

## Table of Contents

- [Release Export (Remote Signing & Index Generation)](#release-export-remote-signing--index-generation)
- [RPM Signing (GPG)](#rpm-signing-gpg)
- [Embedding `index.html` into a WordPress (TT5) Gutenberg Post](#embedding-indexhtml-into-a-wordpress-tt5-gutenberg-post)
- [Summary](#summary)

## Release Export (Remote Signing & Index Generation)

The export step publishes releases to a remote Linux server (export target) via SSH.

The export step can:

- mirror release artifacts to a remote server (incremental upload)
- sign RPM packages using a GPG key stored on the target machine
- generate SHA256 checksum files on the target
- optionally adjust permissions/ownership
- generate an `index.html` release listing with download links

Export behavior is controlled via `config/global.cfg`
(`export_target`, `export_dir`, `export_url_prefix`, etc.).

The export target is intentionally a **Linux host**, even when build nodes include Windows systems. This keeps signing and publishing centralized and secure.

### Workflow

1. Build artifacts are downloaded locally into `release/`.

2. Action **6) Export** mirrors the release directory to a remote target.

3. On the target, the following optional steps are executed:

   - RPM signing (`rpmsign`) using a GPG key available on the target
   - SHA256 checksum generation
   - permission and ownership normalization
   - generation of an `index.html` file for browsing releases

4. The resulting files remain on the export server and are immediately available for download.

### Key Configuration (global.cfg)

```cfg
export_target="user@server"
export_dir="/var/www/download/release"
export_url_prefix="https://example.com/download/"

export_sign_rpms="yes"
export_generate_sha256="yes"
export_generate_index="yes"

export_chmod="775"
export_chown="www-data:www-data"
```

#### Important Variables

- `export_target`
  SSH target used for publishing and signing.

- `export_dir`
  Absolute directory on the export server where releases are stored.

- `export_url_prefix`
  Public base URL used when generating download links.

- `export_sign_rpms`
  Enables remote RPM signing.

- `export_generate_sha256`
  Generates `*.sha256` files beside artifacts.

- `export_generate_index`
  Creates HTML index pages for browsing releases.

- `export_chmod` / `export_chown`
  Optional normalization for web-server access.

### Export Behavior

The export operation is intentionally **incremental**:

- only changed files are transferred
- unchanged artifacts remain untouched
- previously signed RPMs are not modified unless replaced

This makes repeated exports fast and safe.

### Result

A browsable release index is generated at:

```text
<export_dir>/index.html
```

The script automatically scans all subdirectories and creates
absolute download links based on:

```text
export_url_prefix + export folder name
```

Example structure:

```text
release/
└── radiorec/
    └── 1.0/
        ├── radiorec_1.0-1_amd64.deb
        ├── radiorec-1.0-1.x86_64.rpm
        ├── radiorec-1.0-1.x86_64.rpm.sha256
        └── index.html
```

### Generated index.html

The generated page is:

- WordPress Gutenberg friendly (HTML fragment)
- independent of Bootstrap or external frameworks
- compatible with light and dark themes
- based on native HTML (`<details>` blocks for platform sections)
- optimized for embedding via iframe if desired

The index includes:

- file name
- file size
- SHA256 checksum (full hash)
- direct download link

### Security Model

The design intentionally separates responsibilities:

- build nodes do **not** contain signing keys
- the private GPG key exists only on the export target
- signing happens after artifacts are transferred
- exported files can be served directly from the target

Recommended:

- restrict SSH access
- use key-based authentication
- dedicate a non-root user for export
- limit write access to `export_dir`

## RPM Signing (GPG)

When using the **6) Export** step with remote signing enabled, RPM signing is performed on the export target.

The target machine must have:

- `rpmsign`
- `gpg`
- the private signing key imported
- properly configured `~/.rpmmacros`

### 1. Generate a New GPG Key

Start the interactive key generation process:

```bash
gpg --full-generate-key
```

Use the following recommended options:

- **Key type:** `RSA and RSA`
- **Key size:** `4096`
- **Key expiration:** `0` (does not expire) or set according to your policy
- **Real name:** Your name or project name (e.g. `RPM Signing`)
- **Email address:** Project or maintainer email
- **Comment:** Optional (can be left empty)

Confirm the entered details and choose a **strong passphrase** when prompted.

> Note: The passphrase will be required during RPM signing unless an agent or unattended signing setup is used.

#### List and Identify the Key ID

After creation, list your secret keys:

```bash
gpg --list-secret-keys --keyid-format long
```

Example output:

```text
sec   rsa4096/9E736AF1D162F3F6 2026-02-08 [SC]
      9E736AF1D162F3F6FF21E3659A1A41C5DDF5A11A
uid   [ultimate] RPM Signing <signing@example.com>
```

Use the **full fingerprint** (recommended) in all configuration files.

#### Export the Private Key (Optional, for Backup or CI)

```bash
gpg --export-secret-keys --armor 9E736AF1D162F3F6FF21E3659A1A41C5DDF5A11A > private-key.asc
```

**Keep this file secret.**

> Never copy the private signing key to build nodes.
> The key should exist only on a dedicated signing or export target that is physically secured and access-controlled.

#### Export the Public Key (for Repository Users)

```bash
gpg --export --armor 9E736AF1D162F3F6FF21E3659A1A41C5DDF5A11A > RPM-GPG-KEY-user
```

This key is published so users can verify RPM signatures.

### 2. Importing the Private Key

Verify the private key exists:

```sh
gpg --list-secret-keys --keyid-format long
```

If missing, import it:

```sh
gpg --import /path/to/your/private-key.asc
```

### 3. Configuring `~/.rpmmacros`

Create or modify `~/.rpmmacros`:

```sh
nano ~/.rpmmacros
```

Add:

```cfg
%__gpg /usr/bin/gpg
%_gpg_name 9E736AF1D162F3F6FF21E3659A1A41C5DDF5A11A
```

Optional but recommended:

```cfg
%_signature gpg
%_gpg_path ~/.gnupg
```

### 4. Setting the Key ID in `global.cfg`

Verify `config/global.cfg`:

```cfg
gpg_key_id="9E736AF1D162F3F6FF21E3659A1A41C5DDF5A11A"
```

This value is used by the export step when invoking `rpmsign`.

### 5. Testing Signing Manually (Recommended)

Before using automated export, test signing directly:

```bash
rpmsign --addsign package.rpm
```

Verify signature:

```bash
rpm --checksig package.rpm
```

Expected output:

```text
package.rpm: digests signatures OK
```

### 6. Publishing the Public Key

Make the public key available to users, for example:

```text
https://example.com/keys/RPM-GPG-KEY-user
```

Repository configuration can then reference this key for automatic verification.

### Operational Recommendations

- Keep signing isolated from build infrastructure.
- Back up private keys securely.
- Consider using a dedicated signing VM.
- Use SSH keys instead of passwords.
- Restrict file permissions on `~/.gnupg`.

## Embedding `index.html` into a WordPress (TT5) Gutenberg Post

The generated `index.html` is designed as a **self-contained HTML fragment** that can be embedded into a WordPress post using an iframe. Twenty Twenty-Five (TT5) renders Gutenberg content well with native HTML elements like `<details>/<summary>` and does not require Bootstrap.

This integration has three parts:

1. **Server-side export output** (`export.sh`) generates `index.html` including:
   - scoped CSS (under `.mrl-release`)
   - an internal script that reports its current height via `postMessage`
2. **WordPress iframe plugin + shortcode** embeds the page in a post.
3. **A small script in the post** listens for the height messages and resizes the iframe (grow + shrink) to avoid whitespace and layout jumps.

### 1) `export.sh` generates Gutenberg-friendly `index.html`

`export.sh` writes an `index.html` fragment that contains:

- `<div class="mrl-release"> ... </div>`
- `<style>...</style>` scoped CSS
- `<script>...</script>` that sends `{ type: "mrlIframeHeight", height: <px> }` to the parent window

Key point: the page **does not include** `<html>/<head>/<body>`, so it can be embedded safely and styled locally without clashing with WordPress / TT5.

(Your `export.sh` already includes the required CSS and the height `postMessage` script.)

### 2) Install an iframe plugin (shortcode provider)

Use the WordPress plugin:

- **Iframe**: [https://wordpress.org/plugins/iframe/](https://wordpress.org/plugins/iframe/)

This plugin provides the `[iframe ...]` shortcode needed to embed external HTML into a Gutenberg post.

### 3) Add the iframe shortcode into the Gutenberg post

Insert a **Shortcode** block in Gutenberg and paste:

```text
[iframe id="mrl-release" class="mrl-iframe" src="https://marelis.cz/download/release/radiorec/1.0/index.html" height="900" loading="eager" scrolling="no"]
```

Notes:

- `id="mrl-release"` is required (the JS targets this element)
- `scrolling="no"` is enforced again by the JS (defensive)
- `height="900"` is just an initial fallback before auto-resize kicks in

### 4) Add the parent-page JavaScript (Gutenberg “Custom HTML” block)

Below the shortcode, insert a **Custom HTML** block and paste this script:

```html
<script>
(() => {
  const ID = "mrl-release", TYPE = "mrlIframeHeight";
  const OFF = 20, TOL = 10, MIN = 100;
  let last = 0;
  const apply = h => {
    const f = document.getElementById(ID);
    if (!f) return;
    h = Math.max(MIN, +h || 0);
    if (Math.abs(h - last) < TOL) return;
    last = h;
    f.style.cssText = `height:${h + OFF}px;width:100%;display:block;overflow:hidden;border:0`;
    f.setAttribute("scrolling", "no");
  };
  addEventListener("message", e => {
    const d = e.data;
    if (d && d.type === TYPE) apply(d.height);
  });
})();
</script>
```

What it does:

- listens for `postMessage` events coming from the embedded `index.html`
- applies iframe height updates with:

  - `OFF` (padding/extra whitespace under content)
  - `TOL` (ignore jitter from rounding/font swaps)
  - `MIN` (safety minimum)
- supports both **growth and shrink** (important for `<details>` toggling)

### 5) Optional: iframe wrapper styling in TT5 (post-level)

If you want consistent spacing or max width behavior inside TT5, add a small CSS snippet in the same Custom HTML block (or site-level CSS). This is optional because `index.html` is already scoped and styled.

```html
<style>
/* Optional: keep iframe visually aligned with TT5 content width */
.mrl-iframe{
  width:100%;
  border:0;
  display:block;
}
</style>
```

### Cross-site considerations (why `postMessage` is used)

The parent WordPress page **cannot** directly read the embedded document height via DOM APIs when the iframe is cross-origin. The `index.html` script generated by `export.sh` works around this by:

- measuring its own height internally
- sending the height value to the parent with `window.parent.postMessage(...)`

The parent page does not need to access iframe content; it only reacts to the height messages.

## Summary

The release export system provides:

- centralized release publishing
- remote RPM signing
- automatic checksum generation
- reproducible release indexing
- secure separation of build and signing environments

This design enables safe multi-platform builds while keeping signing keys confined to a controlled Linux export target.
