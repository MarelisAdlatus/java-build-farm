#!/bin/bash

# Remote export post-process script (runs on export target)
# - optional chmod/chown
# - optional RPM signing
# - optional SHA256 generation
# - optional index.html generation in export root

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Required env:
#   EXPORT_RELEASE_DIR   - full path to <export_dir>/<app>/<version>
#   EXPORT_ROOT_DIR      - full export root (export_dir)
#   EXPORT_URL_PREFIX    - base URL prefix (e.g. https://marelis.cz/download/)
# Optional env:
#   EXPORT_SIGN_RPMS     - yes/no
#   EXPORT_SHA256        - yes/no
#   EXPORT_INDEX         - yes/no
#   EXPORT_CHMOD         - e.g. 775 (empty = skip)
#   EXPORT_CHOWN         - e.g. www-data:www-data (empty = skip)
#   EXPORT_GPG_KEY_ID    - key id/fingerprint for rpmsign

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}Error: $1 not found on target.${NC}"; exit 1; }
}

# sanity
[[ -n "$EXPORT_RELEASE_DIR" ]] || { echo -e "${RED}Error: EXPORT_RELEASE_DIR not set.${NC}"; exit 1; }
[[ -n "$EXPORT_ROOT_DIR"    ]] || { echo -e "${RED}Error: EXPORT_ROOT_DIR not set.${NC}"; exit 1; }
[[ -n "$EXPORT_URL_PREFIX"  ]] || { echo -e "${RED}Error: EXPORT_URL_PREFIX not set.${NC}"; exit 1; }

d="$EXPORT_RELEASE_DIR"
root="$EXPORT_ROOT_DIR"

if [[ ! -d "$d" ]]; then
  echo -e "${RED}Error: export dir not found: $d${NC}"
  exit 1
fi

# 1) chmod / chown (optional)
if [[ -n "$EXPORT_CHMOD" ]]; then
  chmod -R "$EXPORT_CHMOD" "$d" || true
fi

if [[ -n "$EXPORT_CHOWN" ]]; then
  chown -R "$EXPORT_CHOWN" "$d"
fi

# 2) RPM signing (optional)
if [[ "$EXPORT_SIGN_RPMS" == "yes" ]]; then
  require_cmd find
  require_cmd rpmsign

  if [[ -z "$EXPORT_GPG_KEY_ID" ]]; then
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

# 3) SHA256 (optional)
if [[ "$EXPORT_SHA256" == "yes" ]]; then
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

# 4) index.html (optional; in export root)
if [[ "$EXPORT_INDEX" == "yes" ]]; then
  require_cmd find
  require_cmd stat
  require_cmd head
  require_cmd cut
  require_cmd sort
  require_cmd basename

  echo "info: generate index.html in $root"

  og=$(stat -c "%U:%G" "$root")
  mode=$(stat -c "%a" "$root")

  out="$root/index.html"
  export_folder=$(basename "$root")
  url_base="${EXPORT_URL_PREFIX}${export_folder}"

  tpl_block_open="<section class=\"card\"><h2 class=\"app\">%s</h2>"
  tpl_ver="<h3 class=\"ver\">%s</h3>"
  tpl_plat_open="<div class=\"plat\"><div class=\"platname\">%s</div><div class=\"grid\">"
  tpl_plat_close="</div></div>"
  tpl_block_close="</section>"
  tpl_file="<article class=\"item\"><a class=\"dl\" href=\"%s\" download>%s</a><div class=\"meta\"><span>%s</span><span class=\"dot\">•</span><span class=\"hash\">%s</span><span class=\"dot\">•</span><span>%s</span></div></article>"

  cat > "$out" <<EOF
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Release</title><style>
:root{color-scheme:dark;--bg:#0b0f14;--card:#0f1620;--muted:#9da7b3;--line:#1f2a37;--hi:#e6edf3;--link:#7ee787;--mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace}
body{margin:0;background:var(--bg);color:var(--hi);font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;font-size:18px;line-height:1.35}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}
.wrap{max-width:1200px;margin:0 auto;padding:26px 18px 46px}
.top{display:flex;flex-direction:column;gap:8px;margin-bottom:18px}
h1{font-size:28px;margin:0;font-weight:800;letter-spacing:.2px}
.sub{font-size:14px;color:var(--muted)}
.pill{display:inline-block;font-family:var(--mono);font-size:13px;padding:3px 8px;border:1px solid var(--line);border-radius:999px;background:#111827;color:#cbd5e1}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px;margin:14px 0;box-shadow:0 10px 24px rgba(0,0,0,.25)}
.app{font-size:20px;margin:0 0 10px}
.ver{font-size:17px;margin:12px 0 8px;color:#cbd5e1}
.plat{margin:10px 0 14px}
.platname{font-size:15px;color:#b6c2cf;margin:0 0 10px}
.grid{display:grid;grid-template-columns:1fr;gap:10px}
.item{border:1px solid var(--line);border-radius:14px;padding:12px 12px;background:#0b1220}
.dl{display:block;font-weight:700;font-size:18px;word-break:break-word}
.meta{margin-top:6px;color:var(--muted);font-size:14px;display:flex;flex-wrap:wrap;gap:8px;align-items:baseline}
.hash{font-family:var(--mono);font-size:13px;color:#cbd5e1}
.dot{opacity:.7}
.foot{margin-top:18px;color:var(--muted);font-size:13px}
</style></head><body><div class="wrap"><div class="top"><h1>Release</h1><div class="sub">Base URL: <a href="${url_base}/">${url_base}/</a> <span class="dot">•</span> Root: <span class="pill">${root}</span></div></div>
EOF

  while IFS= read -r app_dir; do
    app=$(basename "$app_dir")
    printf "$tpl_block_open" "$app" >> "$out"

    while IFS= read -r ver_dir; do
      ver=$(basename "$ver_dir")
      printf "$tpl_ver" "$ver" >> "$out"

      while IFS= read -r plat_dir; do
        plat=$(basename "$plat_dir")
        printf "$tpl_plat_open" "$plat" >> "$out"

        while IFS= read -r f; do
          [[ "$f" == *.sha256 ]] && continue

          file=$(basename "$f")
          rel_path=${f#"$root"/}
          abs_url="${url_base}/${rel_path}"

          size_bytes=$(stat -c%s "$f")
          if [[ "$size_bytes" -lt 1024 ]]; then
            size="${size_bytes} B"
          elif [[ "$size_bytes" -lt 1048576 ]]; then
            size="$((size_bytes/1024)) kB"
          else
            size="$((size_bytes/1048576)) MB"
          fi

          sha_f="$f.sha256"
          sha_text="N/A"
          sha_link_text="checksum: -"

          if [[ -f "$sha_f" ]]; then
            sha_text=$(head -n 1 "$sha_f" 2>/dev/null | cut -d' ' -f1)
            [[ -z "$sha_text" ]] && sha_text="N/A"
            sha_rel=${sha_f#"$root"/}
            sha_abs="${url_base}/${sha_rel}"
            sha_name=$(basename "$sha_f")
            sha_link_text="<a href=\"${sha_abs}\" download>${sha_name}</a>"
          fi

          printf "$tpl_file" "$abs_url" "$file" "$size" "$sha_text" "$sha_link_text" >> "$out"
        done < <(find "$plat_dir" -maxdepth 1 -type f -print | sort)

        printf "%s" "$tpl_plat_close" >> "$out"
      done < <(find "$ver_dir" -mindepth 1 -maxdepth 1 -type d -print | sort)
    done < <(find "$app_dir" -mindepth 1 -maxdepth 1 -type d -print | sort)

    printf "%s" "$tpl_block_close" >> "$out"
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print | sort)

  cat >> "$out" <<EOF
<div class="foot">Generated automatically.</div></div></body></html>
EOF

  chown "$og" "$out" || true
  chmod "$mode" "$out" || true
fi
