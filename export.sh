#!/bin/bash

# Remote export post-process script (runs on export target)
# - optional chmod/chown
# - optional RPM signing
# - optional SHA256 generation
# - optional index.html generation in <EXPORT_RELEASE_DIR>/index.html
#
# index.html output (fragment for embedding, e.g. WordPress Gutenberg iframe/embed):
# - self-contained HTML fragment (no <html>/<head>/<body>)
# - does NOT rely on Bootstrap classes
# - uses <details>/<summary> expanders per platform (arrow + collapse)
# - uses system color keywords (Canvas/CanvasText) when supported
# - uses color-mix() for subtle borders/backgrounds (browser-dependent), with basic fallback for older browsers
# - no title header, no "base URL" row printed
# - platform folder name -> display label mapping via DISTRO_LABEL (fallback = folder name)
# - shows FULL sha256 hash when a sibling "*.sha256" file exists (reads first token of the first line)
# - renders a checksum link to the "*.sha256" file when present
#
# Notes:
# - EXPORT_URL_PREFIX is a base URL prefix WITHOUT the export-folder segment.
#   The final URL is built as:
#     <EXPORT_URL_PREFIX>/<basename(EXPORT_ROOT_DIR)>/<app>/<version>/<platform>/<file>
#   Example:
#     EXPORT_URL_PREFIX="https://marelis.cz/download"
#     EXPORT_ROOT_DIR="/var/www/download/release-test"
#     => https://marelis.cz/download/release-test/<app>/<ver>/...
# - The included script posts height changes via postMessage (type: "mrlIframeHeight") to support dynamic iframe sizing.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Required env:
#   EXPORT_RELEASE_DIR   - full path to <export_root>/<app>/<version> (where index.html will be generated)
#   EXPORT_ROOT_DIR      - full export root path (<export_root>), parent of <app>
#   EXPORT_URL_PREFIX    - base URL prefix WITHOUT export-root folder name
#                           (e.g. https://marelis.cz/download)
#
# Optional env:
#   EXPORT_SIGN_RPMS     - yes/no
#   EXPORT_SHA256        - yes/no
#   EXPORT_INDEX         - yes/no
#   EXPORT_CHMOD         - e.g. 775 (empty = skip)
#   EXPORT_CHOWN         - e.g. www-data:www-data (empty = skip)
#   EXPORT_GPG_KEY_ID    - key id/fingerprint for rpmsign

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${RED}Error: $1 not found on target.${NC}"
    exit 1
  }
}

# join URL parts safely
url_join() {
  local a="$1" b="$2"
  a="${a%/}"
  b="${b#/}"
  printf "%s/%s" "$a" "$b"
}

# -----------------------------------------------------------------------------
# PLATFORM LABELS (folder name -> display name)
# -----------------------------------------------------------------------------
declare -A DISTRO_LABEL=(
  ["debian-13.3-stable-x86_64"]="Debian 13.3 Stable x86_64"
  ["fedora-workstation-43-x86_64"]="Fedora Workstation 43 x86_64"
  ["kubuntu-24.04.3-lts-x86_64"]="Kubuntu 24.04.3 LTS x86_64"
  ["linux-mint-22.3-cinnamon-x86_64"]="Linux Mint 22.3 Cinnamon x86_64"
  ["microsoft-windows-10-22h2-x64"]="Microsoft Windows 10 22H2 x64"
  ["microsoft-windows-11-25h2-x64"]="Microsoft Windows 11 25H2 x64"
  ["opensuse-leap-16.0-x86_64"]="openSUSE Leap 16.0 x86_64"
  ["opensuse-tumbleweed-x86_64"]="openSUSE Tumbleweed x86_64"
  ["pop!_os-24.04-lts-x86_64"]="Pop!_OS 24.04 LTS x86_64"
  ["rocky-linux-10.1-x86_64"]="Rocky Linux 10.1 x86_64"
  ["ubuntu-24.04.3-lts-x86_64"]="Ubuntu 24.04.3 LTS x86_64"
  ["ubuntu-25.10-x86_64"]="Ubuntu 25.10 x86_64"
  ["xubuntu-24.04.3-lts-x86_64"]="Xubuntu 24.04.3 LTS x86_64"
)

distro_label() {
  local key="$1"
  if [[ -n "${DISTRO_LABEL[$key]+x}" ]]; then
    printf "%s" "${DISTRO_LABEL[$key]}"
  else
    printf "%s" "$key"
  fi
}

# -----------------------------------------------------------------------------
# SANITY
# -----------------------------------------------------------------------------
[[ -n "${EXPORT_RELEASE_DIR:-}" ]] || { echo -e "${RED}Error: EXPORT_RELEASE_DIR not set.${NC}"; exit 1; }
[[ -n "${EXPORT_ROOT_DIR:-}"    ]] || { echo -e "${RED}Error: EXPORT_ROOT_DIR not set.${NC}"; exit 1; }
[[ -n "${EXPORT_URL_PREFIX:-}"  ]] || { echo -e "${RED}Error: EXPORT_URL_PREFIX not set.${NC}"; exit 1; }

d="$EXPORT_RELEASE_DIR"
root="$EXPORT_ROOT_DIR"

if [[ ! -d "$d" ]]; then
  echo -e "${RED}Error: export dir not found: $d${NC}"
  exit 1
fi

# -----------------------------------------------------------------------------
# 1) chmod / chown (optional)
# -----------------------------------------------------------------------------
if [[ -n "${EXPORT_CHMOD:-}" ]]; then
  chmod -R "$EXPORT_CHMOD" "$d" || true
fi

if [[ -n "${EXPORT_CHOWN:-}" ]]; then
  chown -R "$EXPORT_CHOWN" "$d"
fi

# -----------------------------------------------------------------------------
# 2) RPM signing (optional)
# -----------------------------------------------------------------------------
if [[ "${EXPORT_SIGN_RPMS:-no}" == "yes" ]]; then
  require_cmd find
  require_cmd rpmsign

  if [[ -z "${EXPORT_GPG_KEY_ID:-}" ]]; then
    echo -e "${RED}Error: EXPORT_GPG_KEY_ID not set.${NC}"
    exit 1
  fi

  mapfile -t rpms < <(find "$d" -type f -name "*.rpm")
  if [[ ${#rpms[@]} -gt 0 ]]; then
    echo "Found ${#rpms[@]} RPMs to sign:"
    for f in "${rpms[@]}"; do echo " - $f"; done
    echo ""
    echo "Using GPG key: $EXPORT_GPG_KEY_ID"
    rpmsign --addsign --key-id "$EXPORT_GPG_KEY_ID" "${rpms[@]}"
    echo ":: RPM signing completed."
  else
    echo "No RPMs found to sign."
  fi
fi

# -----------------------------------------------------------------------------
# 3) SHA256 (optional)
# -----------------------------------------------------------------------------
if [[ "${EXPORT_SHA256:-no}" == "yes" ]]; then
  require_cmd find
  require_cmd sha256sum
  require_cmd cut
  require_cmd basename

  mapfile -t files < <(find "$d" -type f ! -name "*.sha256")
  if [[ ${#files[@]} -gt 0 ]]; then
    echo "Found ${#files[@]} files to hash:"
    for f in "${files[@]}"; do echo " - $f"; done

    for f in "${files[@]}"; do
      h=$(sha256sum "$f" | cut -d' ' -f1)
      printf "%s  %s\n" "$h" "$(basename "$f")" > "$f.sha256"
    done
    echo ":: SHA256 generation completed."
  else
    echo "No files found to hash."
  fi
fi

# -----------------------------------------------------------------------------
# 4) index.html (optional; generated in EXPORT_RELEASE_DIR/index.html)
# -----------------------------------------------------------------------------
if [[ "${EXPORT_INDEX:-no}" == "yes" ]]; then
  require_cmd find
  require_cmd stat
  require_cmd head
  require_cmd cut
  require_cmd sort
  require_cmd basename

  echo "info: generate index.html in $d"

  # Preserve owner/mode from release dir (to apply to index.html)
  og=$(stat -c "%U:%G" "$d")
  mode=$(stat -c "%a" "$d")

  out="$d/index.html"

  app="$(basename "$(dirname "$d")")"
  ver="$(basename "$d")"

  # Base URL (used only to build file links; not printed in HTML)
  # Final URL structure:
  #   <EXPORT_URL_PREFIX>/<basename(EXPORT_ROOT_DIR)>/<app>/<ver>/<platform>/<file>
  export_folder="$(basename "$root")"
  url_base="$(url_join "$(url_join "$EXPORT_URL_PREFIX" "$export_folder")" "$(url_join "$app" "$ver")")"

  # Platforms as expanders (Gutenberg-friendly)
  tpl_plat_open='<details class="mrl-plat"><summary class="mrl-platname">%s</summary><div class="mrl-grid">'
  tpl_plat_close='</div></details>'

  # Use &middot; to avoid encoding issues seen with "•"
  tpl_file='<article class="mrl-item"><a class="mrl-dl" href="%s">%s</a><div class="mrl-meta"><span>%s</span><span class="mrl-sep">&middot;</span><span class="mrl-hash">%s</span><span class="mrl-sep">&middot;</span>%s</div></article>'

  # Gutenberg-friendly fragment + CSS scoped under .mrl-release
  cat > "$out" <<'EOF'
<div class="mrl-release">
<style>
  .mrl-release{
    font-family: "Manrope", system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
    font-size: 1.08rem;
    line-height: 1.55;
    color: CanvasText;
  }

  .mrl-release a{
    text-decoration:none;
  }
  .mrl-release a:hover{
    text-decoration:underline;
  }

  /* ------------------------------------------------------------------
     Platform container (<details>)
     ------------------------------------------------------------------ */
  .mrl-plat{
    margin:14px 0;
    border:1px solid color-mix(in srgb, CanvasText 18%, transparent);
    border-radius:14px;
    background: color-mix(in srgb, Canvas 50%, transparent);
    padding:6px;
    backdrop-filter: blur(2px);
    box-shadow: 0 1px 2px rgba(0,0,0,.04);
  }

  /* ------------------------------------------------------------------
     Platform header (<summary>)
     - marker is hidden and replaced by a custom arrow via ::before
     - summary uses flex to keep arrow + label aligned
     ------------------------------------------------------------------ */
  .mrl-platname{
    cursor:pointer;
    font-size:1.08rem;
    margin:0;
    font-weight:600;
    padding:8px 10px;
    list-style:none;
    user-select:none;

    display:flex;
    align-items:center;
    gap:.35rem;
    line-height:1.35;
  }

  .mrl-platname::-webkit-details-marker{
    display:none;
  }

  /* ------------------------------------------------------------------
     Arrow (collapsed ▸ / expanded ▾)
     ------------------------------------------------------------------ */
  .mrl-platname::before{
    content:"\25B8";  /* ▸ */
    display:inline-flex;
    align-items:center;
    justify-content:center;
    width:1.25em;
    font-size:1.55em;
    line-height:1;
    opacity:.72;
    transform: translateY(1px);
    flex-shrink:0;
  }

  .mrl-plat[open] .mrl-platname::before{
    content:"\25BE";  /* ▾ */
  }

  /* ------------------------------------------------------------------
     File grid + cards
     ------------------------------------------------------------------ */
  .mrl-grid{
    display:grid;
    grid-template-columns:1fr;
    gap:10px;
    padding:8px 10px 10px;
  }

  .mrl-item{
    border:1px solid color-mix(in srgb, CanvasText 14%, transparent);
    border-radius:12px;
    padding:11px 13px;
    background: color-mix(in srgb, Canvas 92%, transparent);
  }

  .mrl-dl{
    display:block;
    font-weight:600;
    word-break:break-word;
    line-height:1.45;
    font-size:1.02rem;
  }

  .mrl-meta{
    margin-top:6px;
    font-size:0.88rem;
    opacity:.82;
    display:flex;
    flex-wrap:wrap;
    gap:8px;
    align-items:baseline;
  }

  .mrl-sep{
    opacity:.6;
  }

  /* sha256 full hash + checksum link use monospace and allow wrapping */
  .mrl-hash,
  .mrl-chk{
    font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;
    font-size:0.78rem;
    word-break:break-all;
  }

  /* ------------------------------------------------------------------
     Fallback for older browsers without system color keywords
     (does not fully emulate color-mix(), but keeps layout readable)
     ------------------------------------------------------------------ */
  @supports not (color: CanvasText){
    .mrl-release{ color:#111; }

    .mrl-plat{
      background: rgba(255,255,255,.72);
      border:1px solid rgba(0,0,0,.15);
    }

    .mrl-item{
      background: rgba(255,255,255,.82);
      border:1px solid rgba(0,0,0,.15);
    }
  }
</style>
EOF

  # Platforms = immediate subfolders of <app>/<version>
  while IFS= read -r plat_dir; do
    plat="$(basename "$plat_dir")"
    plat_label="$(distro_label "$plat")"

    printf "$tpl_plat_open" "$plat_label" >> "$out"

    while IFS= read -r f; do
      [[ "$f" == *.sha256 ]] && continue

      file="$(basename "$f")"
      rel_path="${f#"$d"/}"
      abs_url="$(url_join "$url_base" "$rel_path")"

      size_bytes=$(stat -c%s "$f")
      if [[ "$size_bytes" -lt 1024 ]]; then
        size="${size_bytes} B"
      elif [[ "$size_bytes" -lt 1048576 ]]; then
        size="$((size_bytes/1024)) kB"
      else
        size="$((size_bytes/1048576)) MB"
      fi

      sha_f="$f.sha256"
      sha_text="sha256: -"
      sha_link='<span class="mrl-chk">checksum: -</span>'

      # If checksum file exists, show full hash and link to "*.sha256"
      if [[ -f "$sha_f" ]]; then
        sha_full="$(head -n 1 "$sha_f" 2>/dev/null | cut -d' ' -f1)"
        [[ -n "$sha_full" ]] && sha_text="$sha_full"

        sha_rel="${sha_f#"$d"/}"
        sha_abs="$(url_join "$url_base" "$sha_rel")"
        sha_name="$(basename "$sha_f")"
        sha_link="<a class=\"mrl-chk\" href=\"${sha_abs}\">${sha_name}</a>"
      fi

      printf "$tpl_file" "$abs_url" "$file" "$size" "$sha_text" "$sha_link" >> "$out"
    done < <(find "$plat_dir" -maxdepth 1 -type f -print | sort)

    printf "%s" "$tpl_plat_close" >> "$out"
  done < <(find "$d" -mindepth 1 -maxdepth 1 -type d -print | sort)

cat >> "$out" <<'EOF'
<script>
(function () {
  // Posts height to parent window for iframe auto-resize
  // Parent page (WordPress/plugin) should listen for:
  //   postMessage({ type: "mrlIframeHeight", height: <number> }, "*")
  const MSG_TYPE = "mrlIframeHeight";

  // Ignore tiny jitter (fonts/layout rounding)
  const TOL = 10;

  let lastSent = 0;
  let debounceTimer = null;
  let rafPending = false;

  function contentHeight() {
    const root = document.querySelector(".mrl-release") || document.body || document.documentElement;
    const r = root.getBoundingClientRect();
    return Math.ceil(r.height);
  }

  function post(h) {
    if (!window.parent || window.parent === window) return;
    window.parent.postMessage({ type: MSG_TYPE, height: h }, "*");
  }

  function maybeSend() {
    rafPending = false;
    const h = contentHeight();

    // allow grow+shrink; ignore tiny jitter
    if (Math.abs(h - lastSent) < TOL) return;

    lastSent = h;
    post(h);
  }

  function scheduleSend() {
    if (rafPending) return;
    rafPending = true;
    requestAnimationFrame(maybeSend);
  }

  function scheduleDebounced() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(scheduleSend, 80);
  }

  // initial
  window.addEventListener("load", function () {
    scheduleDebounced();
    setTimeout(scheduleDebounced, 200); // after font swap/layout settle
  });

  window.addEventListener("resize", scheduleDebounced);

  // details toggle: measure after layout settles (important for shrink)
  document.addEventListener("toggle", function (e) {
    if (e && e.target && e.target.tagName === "DETAILS") {
      scheduleDebounced();
      setTimeout(scheduleDebounced, 120);
      setTimeout(scheduleDebounced, 300);
    }
  }, true);

  // fonts can change size after load
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(function () {
      scheduleDebounced();
      setTimeout(scheduleDebounced, 200);
    }).catch(function(){});
  }

  // mutation observer: debounced (no pumping)
  if ("MutationObserver" in window) {
    const mo = new MutationObserver(scheduleDebounced);
    mo.observe(document.documentElement, { childList: true, subtree: true, attributes: true });
  }

  // kick
  setTimeout(scheduleDebounced, 50);
})();
</script>
</div>
EOF

  # Restore ownership/mode like original did
  chown "$og" "$out" || true
  chmod "$mode" "$out" || true
fi
