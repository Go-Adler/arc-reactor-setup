#!/usr/bin/env bash
# ============================================================================
#  Arc Reactor — shared helpers, sourced by install.sh / uninstall.sh / verify.sh
# ============================================================================

# --------------------------------------------------------------------- output
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_CYN=$'\033[36m'; C_BLD=$'\033[1m';  C_OFF=$'\033[0m'
else
  C_RED=; C_GRN=; C_YEL=; C_CYN=; C_BLD=; C_OFF=
fi

step()  { printf '\n%s▸ %s%s\n' "$C_BLD$C_CYN" "$*" "$C_OFF"; }
ok()    { printf '  %s✓%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
warn()  { printf '  %s!%s %s\n' "$C_YEL" "$C_OFF" "$*"; }
bad()   { printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$*"; }
info()  { printf '    %s\n' "$*"; }
die()   { printf '\n%sERROR:%s %s\n' "$C_RED$C_BLD" "$C_OFF" "$*" >&2; exit 1; }

DRY_RUN=${DRY_RUN:-0}
run() {  # run a command, or just print it under --dry-run
  if [ "$DRY_RUN" = "1" ]; then printf '    [dry-run] %s\n' "$*"; return 0; fi
  "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------ downloads
CURL_OPTS=(--fail --silent --show-error --location
           --connect-timeout 15 --retry 3 --retry-delay 2)

dl() {  # dl <url> <dest>   -> 0 on success
  [ "$DRY_RUN" = "1" ] && { printf '    [dry-run] download %s\n' "$1"; return 0; }
  curl "${CURL_OPTS[@]}" --max-time "${DL_TIMEOUT:-300}" -o "$2" "$1"
}

# gh_asset <owner/repo> <regex matching the asset name>  -> prints download URL
gh_asset() {
  curl "${CURL_OPTS[@]}" --max-time 45 \
       "https://api.github.com/repos/$1/releases/latest" \
    | jq -r --arg re "$2" '.assets[]? | select(.name|test($re)) | .browser_download_url' \
    | head -1
}

# ---------------------------------------------------------- machine detection
detect_shell_version() {
  # EGO wants "46" for GNOME >= 40, "3.38" for the 3.x series.
  local v major minor
  v=$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -1)
  [ -n "$v" ] || return 1
  major=${v%%.*}
  if [ "$major" -ge 40 ] 2>/dev/null; then
    printf '%s' "$major"
  else
    minor=$(printf '%s' "$v" | cut -d. -f2)
    printf '%s.%s' "$major" "${minor:-0}"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  printf 'x86_64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *)             printf 'unsupported' ;;
  esac
}

# ------------------------------------------------------- extension management
# ego_install <uuid> <shell_version>  -> installs, prints version, returns 0/1
ego_install() {
  local uuid="$1" sv="$2" json url tmp
  json=$(curl "${CURL_OPTS[@]}" --max-time 30 \
    "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${sv}" \
    2>/dev/null) || return 1
  [ -n "$json" ] || return 1
  url=$(printf '%s' "$json" | jq -r '.download_url // empty')
  [ -n "$url" ] || return 1
  if [ "$DRY_RUN" = "1" ]; then
    printf '    [dry-run] install extension %s\n' "$uuid"; return 0
  fi
  tmp=$(mktemp -d)
  if dl "https://extensions.gnome.org${url}" "$tmp/$uuid.zip" \
     && gnome-extensions install --force "$tmp/$uuid.zip" >/dev/null 2>&1; then
    rm -rf "$tmp"
    printf '%s' "$(printf '%s' "$json" | jq -r '.version')"
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

ext_dir()      { printf '%s/.local/share/gnome-shell/extensions/%s' "$HOME" "$1"; }
ext_installed() {
  [ -f "$(ext_dir "$1")/metadata.json" ] || [ -f "/usr/share/gnome-shell/extensions/$1/metadata.json" ]
}

# xset <uuid> <schema-id> <key> <value>
# Sets an extension setting via its bundled schema, so it works even before
# the shell has loaded the extension. Falls back to the global schema source
# (needed for distro-shipped extensions such as Ubuntu's dock).
xset() {
  local uuid="$1" schema="$2" key="$3" val="$4" sd
  sd="$(ext_dir "$uuid")/schemas"
  if [ "$DRY_RUN" = "1" ]; then
    printf '    [dry-run] %s %s = %s\n' "$schema" "$key" "$val"; return 0
  fi
  if [ -d "$sd" ] && gsettings --schemadir "$sd" set "$schema" "$key" "$val" 2>/dev/null; then
    return 0
  fi
  gsettings set "$schema" "$key" "$val" 2>/dev/null
}

# gset <schema> <key> <value>  — plain gsettings with reporting
gset() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '    [dry-run] %s %s = %s\n' "$1" "$2" "$3"; return 0
  fi
  gsettings set "$1" "$2" "$3" 2>/dev/null \
    || warn "could not set $1 $2 (schema missing on this machine?)"
}

# --------------------------------------------------------------------- backup
# Snapshot everything the installer is about to touch.
arc_backup() {
  local bk="$1"
  [ "$DRY_RUN" = "1" ] && { info "[dry-run] would back up to $bk"; return 0; }
  mkdir -p "$bk/dconf" "$bk/configs"

  local p name
  for p in /org/gnome/desktop/interface/ /org/gnome/desktop/background/ \
           /org/gnome/desktop/screensaver/ /org/gnome/desktop/wm/preferences/ \
           /org/gnome/desktop/wm/keybindings/ /org/gnome/shell/ /org/gnome/mutter/; do
    name=$(printf '%s' "$p" | tr '/' '_' | sed 's/^_//;s/_$//')
    dconf dump "$p" > "$bk/dconf/${name}.ini" 2>/dev/null || true
  done
  dconf dump / > "$bk/dconf/FULL-dconf-dump.ini" 2>/dev/null || true

  {
    echo "# Arc Reactor backup — $(date -Is)"
    echo "# host $(hostname)  $(gnome-shell --version 2>/dev/null)"
    echo "# $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
    local kv
    for kv in \
      "org.gnome.desktop.interface gtk-theme" \
      "org.gnome.desktop.interface icon-theme" \
      "org.gnome.desktop.interface cursor-theme" \
      "org.gnome.desktop.interface cursor-size" \
      "org.gnome.desktop.interface font-name" \
      "org.gnome.desktop.interface monospace-font-name" \
      "org.gnome.desktop.interface document-font-name" \
      "org.gnome.desktop.interface color-scheme" \
      "org.gnome.desktop.interface text-scaling-factor" \
      "org.gnome.desktop.background picture-uri" \
      "org.gnome.desktop.background picture-uri-dark" \
      "org.gnome.desktop.screensaver picture-uri" \
      "org.gnome.shell.extensions.user-theme name" \
      "org.gnome.shell enabled-extensions" \
      "org.gnome.shell disabled-extensions" \
      "org.gnome.shell favorite-apps" \
      "org.gnome.mutter dynamic-workspaces" \
      "org.gnome.desktop.wm.preferences num-workspaces" \
      "org.gnome.desktop.wm.preferences titlebar-font" \
      "org.gnome.desktop.wm.keybindings switch-input-source" \
      ; do
      printf '%s = %s\n' "$kv" "$(gsettings get $kv 2>/dev/null || echo '<unset>')"
    done
  } > "$bk/settings-snapshot.txt"

  local f
  for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc"; do
    [ -f "$f" ] && cp -a "$f" "$bk/configs/$(basename "$f")"
  done
  for d in gtk-3.0 gtk-4.0; do
    [ -d "$HOME/.config/$d" ] && cp -a "$HOME/.config/$d" "$bk/configs/$d"
  done
  local vs="$HOME/.config/Code/User/settings.json"
  [ -f "$vs" ] && cp -a "$vs" "$bk/configs/vscode-settings.json"
  return 0
}
