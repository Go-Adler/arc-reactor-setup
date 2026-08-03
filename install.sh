#!/usr/bin/env bash
# ============================================================================
#  Arc Reactor — installer
#
#  Reproduces the full Iron Man HUD desktop on a GNOME machine.
#  Everything is installed USER-LOCAL. No sudo, no system files touched.
#
#      ./install.sh                 full install
#      ./install.sh --dry-run       print what would happen, change nothing
#      ./install.sh --no-tools      skip kitty and the CLI tools
#      ./install.sh --no-extensions skip GNOME extensions
#      ./install.sh --no-vscode     skip VS Code theming
#      ./install.sh --help
#
#  A full backup is taken before anything changes. Undo with ./uninstall.sh
# ============================================================================
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$KIT/lib/common.sh"

AR="$HOME/.arc-reactor"
BK="$AR/backup"
MANIFEST="$AR/installed-extensions.txt"

DO_TOOLS=1 DO_EXT=1 DO_VSCODE=1 ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)       DRY_RUN=1 ;;
    --no-tools)      DO_TOOLS=0 ;;
    --no-extensions) DO_EXT=0 ;;
    --no-vscode)     DO_VSCODE=0 ;;
    -y|--yes)        ASSUME_YES=1 ;;
    -h|--help)       sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)               die "unknown option: $1 (try --help)" ;;
  esac
  shift
done
export DRY_RUN

# ============================================================================
step "Preflight"
# ============================================================================
[ "$(id -u)" != "0" ] || die "do not run this as root — it installs into \$HOME"

for c in curl jq git gsettings dconf fc-cache python3 unzip tar sed; do
  have "$c" || die "missing required command: $c
  Debian/Ubuntu:  sudo apt install curl jq git python3 unzip tar libglib2.0-bin fontconfig
  Fedora:         sudo dnf install curl jq git python3 unzip tar glib2 fontconfig"
done
ok "required commands present"

SHELL_VER=$(detect_shell_version) || die "GNOME Shell not found — this desktop targets GNOME."
ok "GNOME Shell $SHELL_VER"

ARCH=$(detect_arch)
[ "$ARCH" = "unsupported" ] && warn "unrecognised CPU ($(uname -m)) — CLI tool downloads may fail"
ok "architecture $ARCH"

SESSION="${XDG_SESSION_TYPE:-unknown}"
ok "session type $SESSION"
[ "$SESSION" = "wayland" ] && info "Wayland: newly installed extensions need a full logout to load."

if ! gnome-extensions list >/dev/null 2>&1; then
  warn "'gnome-extensions' unavailable — extension install will be skipped"
  DO_EXT=0
fi

python3 - <<'PY' 2>/dev/null && HAVE_PY_IMG=1 || HAVE_PY_IMG=0
import numpy, PIL
PY
if [ "$HAVE_PY_IMG" = "1" ]; then
  ok "numpy + pillow available — wallpaper will be generated at native resolution"
else
  warn "numpy/pillow missing — will use the bundled 1920x1080 wallpaper instead"
  info "for a native-resolution wallpaper: pip3 install --user numpy pillow"
fi

curl "${CURL_OPTS[@]}" --max-time 15 -o /dev/null https://extensions.gnome.org/ 2>/dev/null \
  && ok "network reachable" || die "cannot reach extensions.gnome.org — check connectivity/proxy"

if [ "$ASSUME_YES" != "1" ] && [ "$DRY_RUN" != "1" ]; then
  printf '\n%sThis will restyle your desktop and append a block to ~/.bashrc.%s\n' "$C_BLD" "$C_OFF"
  printf 'A full backup goes to %s first. Continue? [y/N] ' "$BK"
  read -r reply
  case "$reply" in [yY]*) ;; *) echo "aborted."; exit 0 ;; esac
fi

# ============================================================================
step "Backing up current configuration"
# ============================================================================
mkdir -p "$AR"
arc_backup "$BK"
ok "backup written to $BK"
info "undo everything later with: $KIT/uninstall.sh"

# ============================================================================
step "Fonts"
# ============================================================================
FD="$HOME/.local/share/fonts/ArcReactor"
run mkdir -p "$FD"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

if fc-list "JetBrainsMono Nerd Font" 2>/dev/null | grep -q . ; then
  ok "JetBrainsMono Nerd Font already present"
else
  if dl "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" "$TMP/jbm.zip"; then
    run unzip -oq "$TMP/jbm.zip" -d "$TMP/jbm"
    if [ "$DRY_RUN" != "1" ]; then
      find "$TMP/jbm" -type f \( -name 'JetBrainsMonoNerdFont-*.ttf' \
           -o -name 'JetBrainsMonoNerdFontMono-*.ttf' \) -exec cp {} "$FD/" \;
    fi
    ok "JetBrainsMono Nerd Font"
  else
    bad "JetBrainsMono Nerd Font download failed (terminal glyphs will show as boxes)"
  fi
fi

RAW="https://raw.githubusercontent.com/google/fonts/main/ofl"
getfont() { # url dest label
  if [ -f "$2" ]; then ok "$3 (cached)"; return; fi
  if dl "$1" "$2"; then ok "$3"; else bad "$3 failed"; fi
}
getfont "$RAW/orbitron/Orbitron%5Bwght%5D.ttf" "$FD/Orbitron-VF.ttf" "Orbitron"
for w in Light Regular Medium SemiBold Bold; do
  getfont "$RAW/rajdhani/Rajdhani-$w.ttf" "$FD/Rajdhani-$w.ttf" "Rajdhani $w"
done

if fc-list "Inter Variable" 2>/dev/null | grep -q .; then
  ok "Inter already present"
else
  IURL=$(gh_asset rsms/inter '^Inter-.*\.zip$')
  if [ -n "$IURL" ] && dl "$IURL" "$TMP/inter.zip"; then
    run unzip -oq "$TMP/inter.zip" -d "$TMP/inter"
    if [ "$DRY_RUN" != "1" ]; then
      find "$TMP/inter" -name 'InterVariable*.ttf' -exec cp {} "$FD/" \;
    fi
    ok "Inter"
  else
    warn "Inter download failed (only used as the document font)"
  fi
fi
run fc-cache -f "$FD"
[ "$DRY_RUN" = "1" ] || ok "font cache rebuilt ($(ls "$FD" 2>/dev/null | wc -l) files)"

# Give the wallpaper generator access to the HUD fonts even before fc-cache.
run mkdir -p "$KIT/assets/fonts"
[ "$DRY_RUN" = "1" ] || {
  cp -f "$FD/Orbitron-VF.ttf" "$KIT/assets/fonts/" 2>/dev/null
  cp -f "$FD/JetBrainsMonoNerdFont-Regular.ttf" "$KIT/assets/fonts/" 2>/dev/null
} || true

# ============================================================================
step "GTK theme (Colloid, red accent, black + rimless + float)"
# ============================================================================
SRC="$AR/src"; run mkdir -p "$SRC"
clone_or_pull() { # repo-name
  if [ -d "$SRC/$1/.git" ]; then
    (cd "$SRC/$1" && run git pull -q) && ok "$1 updated"
  else
    run git clone -q --depth 1 "https://github.com/vinceliuice/$1.git" "$SRC/$1" \
      && ok "$1 cloned"
  fi
}
clone_or_pull Colloid-gtk-theme
clone_or_pull Colloid-icon-theme

if [ "$DRY_RUN" != "1" ]; then
  ( cd "$SRC/Colloid-gtk-theme" \
    && bash install.sh -c dark -t red --tweaks black rimless normal float -l fixed >/dev/null 2>&1 ) \
    && ok "Colloid-Red-Dark installed to ~/.themes (incl. gtk-4.0/libadwaita)" \
    || bad "Colloid GTK install failed"
  ( cd "$SRC/Colloid-icon-theme" && bash install.sh -t red -b >/dev/null 2>&1 ) \
    && ok "Colloid-Red-Dark icons installed" \
    || bad "Colloid icon install failed"
else
  info "[dry-run] would run both Colloid install.sh scripts"
fi

# ============================================================================
step "Cursor (Bibata Modern Amber)"
# ============================================================================
if [ -d "$HOME/.icons/Bibata-Modern-Amber/cursors" ]; then
  ok "Bibata-Modern-Amber already present"
else
  BURL=$(gh_asset ful1e5/Bibata_Cursor 'Bibata-Modern-Amber\.tar\.xz$')
  if [ -n "$BURL" ] && dl "$BURL" "$TMP/bibata.tar.xz"; then
    run mkdir -p "$HOME/.icons"
    run tar -xf "$TMP/bibata.tar.xz" -C "$HOME/.icons/"
    ok "Bibata-Modern-Amber"
  else
    bad "Bibata download failed — cursor will stay as-is"
  fi
fi

# ============================================================================
step "GNOME Shell theme (ArcReactor)"
# ============================================================================
# base.css is DERIVED from whichever Colloid version this machine just
# installed, then its accents are remapped onto the Arc Reactor palette.
# That is why it is not shipped in the kit.
ART="$HOME/.themes/ArcReactor"
COL="$HOME/.themes/Colloid-Red-Dark/gnome-shell"
if [ "$DRY_RUN" = "1" ]; then
  info "[dry-run] would build $ART from $COL + the shipped overlay"
elif [ -d "$COL" ]; then
  rm -rf "$ART"; mkdir -p "$ART/gnome-shell"
  cp -a "$COL/assets" "$ART/gnome-shell/assets" 2>/dev/null || true
  cp -a "$COL/pad-osd.css" "$ART/gnome-shell/" 2>/dev/null || true
  cp "$COL/gnome-shell.css" "$ART/gnome-shell/base.css"
  sed -i \
    -e 's/#F44336/#E62429/g; s/#f44336/#e62429/g' \
    -e 's/#FFD600/#F0A020/g; s/#ffd600/#f0a020/g' \
    -e 's/#5bd3f8/#55D9F0/g' \
    -e 's/#0F0F0F/#0D0B0B/g; s/#0f0f0f/#0d0b0b/g' \
    -e 's/#262626/#1F1A1A/g' \
    "$ART/gnome-shell/base.css"
  cp "$KIT/themes/ArcReactor/gnome-shell/gnome-shell.css" "$ART/gnome-shell/"
  cp "$KIT/themes/ArcReactor/index.theme" "$ART/"
  ok "ArcReactor shell theme built (accents remapped in base.css)"
else
  bad "Colloid shell theme not found — skipping ArcReactor overlay"
fi

# ============================================================================
step "Wallpaper"
# ============================================================================
WP="$AR/wallpapers"; BGDIR="$HOME/.local/share/backgrounds"
run mkdir -p "$WP" "$BGDIR"
WALL="" LOCK=""
if [ "$HAVE_PY_IMG" = "1" ] && [ "$DRY_RUN" != "1" ]; then
  if python3 "$KIT/scripts/make_wallpaper.py" --out "$WP" 2>&1 | sed 's/^/    /'; then
    WALL=$(ls -1t "$WP"/arc-reactor-[0-9]*x[0-9]*.png 2>/dev/null | grep -v lock | head -1)
    LOCK=$(ls -1t "$WP"/arc-reactor-lock-*.png 2>/dev/null | head -1)
    ok "wallpaper generated at native resolution"
  fi
fi
if [ -z "$WALL" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] would generate or copy the wallpaper"
  else
    cp -f "$KIT/assets/wallpapers/"*.png "$WP/" 2>/dev/null
    WALL="$WP/arc-reactor-1920x1080.png"
    LOCK="$WP/arc-reactor-lock-1920x1080.png"
    ok "using bundled 1920x1080 wallpaper"
  fi
fi
[ "$DRY_RUN" = "1" ] || cp -f "$WP"/*.png "$BGDIR/" 2>/dev/null || true

# ============================================================================
step "GNOME extensions"
# ============================================================================
CORE_EXT=(
  burn-my-windows@schneegans.github.com
  rounded-window-corners@fxgn
  monitor@astraext.github.io
  search-light@icedman.github.com
  desktop-cube@schneegans.github.com
  CoverflowAltTab@palatis.blogspot.com
  compiz-windows-effect@hermes83.github.com
  compiz-alike-magic-lamp-effect@hermes83.github.com
  just-perfection-desktop@just-perfection
  blur-my-shell@aunetx
  user-theme@gnome-shell-extensions.gcampax.github.com
)
# Ubuntu ships its own dash-to-dock fork; elsewhere we need the upstream one.
if ext_installed ubuntu-dock@ubuntu.com; then
  DOCK_UUID=ubuntu-dock@ubuntu.com
  ok "using Ubuntu's built-in dock"
else
  DOCK_UUID=dash-to-dock@micxgx.gmail.com
  info "no Ubuntu dock — will install upstream Dash to Dock"
  CORE_EXT+=("$DOCK_UUID")
fi

if [ "$DO_EXT" = "1" ]; then
  [ "$DRY_RUN" = "1" ] || : > "$MANIFEST"
  for u in "${CORE_EXT[@]}"; do
    if ext_installed "$u"; then ok "${u%%@*} (already installed)"; continue; fi
    if v=$(ego_install "$u" "$SHELL_VER"); then
      ok "${u%%@*} v${v:-?}"
      [ "$DRY_RUN" = "1" ] || echo "$u" >> "$MANIFEST"
    else
      bad "${u%%@*} — no build for GNOME $SHELL_VER, skipping"
    fi
  done
  # Optional: installed but left disabled (conflicts with our panel CSS).
  if ! ext_installed openbar@neuromorph; then
    if v=$(ego_install openbar@neuromorph "$SHELL_VER"); then
      ok "openbar v${v:-?} (installed, left DISABLED — see README)"
      [ "$DRY_RUN" = "1" ] || echo "openbar@neuromorph" >> "$MANIFEST"
    fi
  fi
else
  warn "skipped (--no-extensions)"
fi

# ---- build the enabled list from what is ACTUALLY installed ----------------
if [ "$DO_EXT" = "1" ] && [ "$DRY_RUN" != "1" ]; then
  ENABLE=()
  for u in "${CORE_EXT[@]}"; do ext_installed "$u" && ENABLE+=("$u"); done
  # keep these if the machine happens to have them
  for u in tiling-assistant@ubuntu.com \
           auto-move-windows@gnome-shell-extensions.gcampax.github.com \
           clipboard-history@alexsaveau.dev \
           notification-banner-reloaded@marcinjakubowski.github.com; do
    ext_installed "$u" && ENABLE+=("$u")
  done
  LIST="[$(printf "'%s', " "${ENABLE[@]}" | sed 's/, $//')]"
  gset org.gnome.shell enabled-extensions "$LIST"
  ok "enabled ${#ENABLE[@]} extensions"

  DISABLE=()
  for u in window-list@gnome-shell-extensions.gcampax.github.com \
           system-monitor@gnome-shell-extensions.gcampax.github.com \
           openbar@neuromorph ding@rastersoft.com; do
    ext_installed "$u" && DISABLE+=("$u")
  done
  if [ ${#DISABLE[@]} -gt 0 ]; then
    gset org.gnome.shell disabled-extensions \
      "[$(printf "'%s', " "${DISABLE[@]}" | sed 's/, $//')]"
    ok "disabled ${#DISABLE[@]} conflicting extensions"
  fi
fi

# ============================================================================
step "Applying the look"
# ============================================================================
gset org.gnome.desktop.interface gtk-theme     'Colloid-Red-Dark'
gset org.gnome.desktop.interface icon-theme    'Colloid-Red-Dark'
gset org.gnome.desktop.interface cursor-theme  'Bibata-Modern-Amber'
gset org.gnome.desktop.interface cursor-size   '24'
gset org.gnome.desktop.interface color-scheme  'prefer-dark'
gset org.gnome.desktop.interface font-name           'Rajdhani SemiBold 12'
gset org.gnome.desktop.interface document-font-name  'Inter Variable 11'
gset org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
gset org.gnome.desktop.interface font-antialiasing   'rgba'
gset org.gnome.desktop.interface font-hinting        'slight'
gset org.gnome.desktop.wm.preferences titlebar-font  'Rajdhani Bold 12'
gset org.gnome.shell.extensions.user-theme name      'ArcReactor'
ok "theme, icons, cursor and fonts applied"

if [ -n "$WALL" ] && [ "$DRY_RUN" != "1" ]; then
  W="file://$BGDIR/$(basename "$WALL")"
  L="file://$BGDIR/$(basename "${LOCK:-$WALL}")"
  gset org.gnome.desktop.background picture-uri      "$W"
  gset org.gnome.desktop.background picture-uri-dark "$W"
  gset org.gnome.desktop.background picture-options  'zoom'
  gset org.gnome.desktop.background primary-color    '#0d0b0b'
  gset org.gnome.desktop.screensaver picture-uri     "$L"
  gset org.gnome.desktop.screensaver picture-options 'zoom'
  ok "wallpaper set ($(basename "$WALL"))"
fi

# Desktop Cube needs a fixed number of faces to read as a cube.
gset org.gnome.mutter dynamic-workspaces 'false'
gset org.gnome.desktop.wm.preferences num-workspaces '4'
ok "static workspaces (4) for the cube"

# Free Super+Space for Search Light, but only if it is genuinely unused.
if [ "$DRY_RUN" != "1" ]; then
  NSRC=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null \
         | grep -o '(' | wc -l)
  if [ "${NSRC:-0}" -le 1 ]; then
    gset org.gnome.desktop.wm.keybindings switch-input-source '[]'
    gset org.gnome.desktop.wm.keybindings switch-input-source-backward '[]'
    ok "Super+Space freed for Search Light (only one input source)"
  else
    warn "you have $NSRC input sources — leaving Super+Space bound to input switching"
    info "Search Light will have no shortcut; set one in its preferences."
  fi
fi

# ============================================================================
step "Extension settings"
# ============================================================================
if [ "$DO_EXT" != "1" ]; then
  warn "skipped (--no-extensions)"
elif [ "$DRY_RUN" = "1" ]; then
  # configure-extensions.sh writes gsettings directly and has no dry-run mode
  # of its own, so it must not be invoked here.
  info "[dry-run] would run scripts/configure-extensions.sh (dock UUID: $DOCK_UUID)"
  info "[dry-run] would install Burn My Windows profiles"
else
  ARC_DOCK_UUID="$DOCK_UUID" bash "$KIT/scripts/configure-extensions.sh" 2>&1 \
    | sed 's/^/    /' | tail -4
  ok "extension settings applied (see scripts/configure-extensions.sh)"
  mkdir -p "$HOME/.config/burn-my-windows/profiles"
  cp -f "$KIT/config/burn-my-windows/profiles/"*.conf \
        "$HOME/.config/burn-my-windows/profiles/"
  ok "Burn My Windows profiles (energize open / incinerate close)"
fi

# ============================================================================
step "Terminal stack"
# ============================================================================
if [ "$DO_TOOLS" = "1" ]; then
  BIN="$HOME/.local/bin"; run mkdir -p "$BIN"

  if [ -x "$HOME/.local/kitty.app/bin/kitty" ]; then
    ok "kitty already installed"
  elif [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] would install kitty into ~/.local/kitty.app"
  else
    if curl "${CURL_OPTS[@]}" --max-time 420 https://sw.kovidgoyal.net/kitty/installer.sh \
       | sh /dev/stdin launch=n >/dev/null 2>&1; then
      ok "kitty installed"
    else
      bad "kitty install failed"
    fi
  fi
  if [ -x "$HOME/.local/kitty.app/bin/kitty" ] && [ "$DRY_RUN" != "1" ]; then
    ln -sf "$HOME/.local/kitty.app/bin/kitty"  "$BIN/kitty"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$BIN/kitten"
    mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor"
    for f in kitty.desktop kitty-open.desktop; do
      s="$HOME/.local/kitty.app/share/applications/$f"
      [ -f "$s" ] || continue
      cp "$s" "$HOME/.local/share/applications/"
      sed -i "s|^Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|;
              s|^Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|;
              s|^TryExec=kitty|TryExec=$HOME/.local/kitty.app/bin/kitty|" \
             "$HOME/.local/share/applications/$f"
    done
    cp -rn "$HOME/.local/kitty.app/share/icons/hicolor/." \
           "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    ok "kitty desktop entry + icon"
  fi

  # starship
  if have starship; then ok "starship already installed"
  elif [ "$DRY_RUN" = "1" ]; then info "[dry-run] would install starship"
  else
    curl "${CURL_OPTS[@]}" --max-time 240 https://starship.rs/install.sh \
      | sh -s -- --yes --bin-dir "$BIN" >/dev/null 2>&1 \
      && ok "starship" || bad "starship install failed"
  fi

  # Static release binaries. Asset names differ per arch.
  if [ "$ARCH" = "x86_64" ]; then
    A_FF='linux-amd64\.tar\.gz$';        A_BTOP='btop-x86_64-unknown-linux-musl\.tar\.gz$'
    A_EZA='x86_64-unknown-linux-gnu\.tar\.gz$'; A_BAT='x86_64-unknown-linux-gnu\.tar\.gz$'
    A_FZF='linux_amd64\.tar\.gz$';       A_ZOX='x86_64-unknown-linux-musl\.tar\.gz$'
  else
    A_FF='linux-aarch64\.tar\.gz$';      A_BTOP='btop-aarch64-unknown-linux-musl\.tar\.gz$'
    A_EZA='aarch64-unknown-linux-gnu\.tar\.gz$'; A_BAT='aarch64-unknown-linux-gnu\.tar\.gz$'
    A_FZF='linux_arm64\.tar\.gz$';       A_ZOX='aarch64-unknown-linux-musl\.tar\.gz$'
  fi

  get_bin() { # repo  asset-regex  binary-name
    if have "$3"; then ok "$3 already installed"; return; fi
    if [ "$DRY_RUN" = "1" ]; then info "[dry-run] would install $3"; return; fi
    local u d; u=$(gh_asset "$1" "$2")
    [ -n "$u" ] || { bad "$3: no matching release asset for $ARCH"; return; }
    d=$(mktemp -d)
    if dl "$u" "$d/a.tar.gz" && tar -xzf "$d/a.tar.gz" -C "$d" 2>/dev/null; then
      local f; f=$(find "$d" -type f -name "$3" -perm -u+x | head -1)
      if [ -n "$f" ]; then cp "$f" "$BIN/$3"; ok "$3"; else bad "$3: binary not in archive"; fi
    else
      bad "$3: download/extract failed"
    fi
    rm -rf "$d"
  }
  get_bin fastfetch-cli/fastfetch  "$A_FF"   fastfetch
  get_bin aristocratos/btop        "$A_BTOP" btop
  get_bin eza-community/eza        "$A_EZA"  eza
  get_bin sharkdp/bat              "$A_BAT"  bat
  get_bin junegunn/fzf             "$A_FZF"  fzf
  get_bin ajeetdsouza/zoxide       "$A_ZOX"  zoxide
else
  warn "skipped (--no-tools)"
fi

# ============================================================================
step "Config files"
# ============================================================================
copy_cfg() { # src dst-dir
  if [ "$DRY_RUN" = "1" ]; then info "[dry-run] $1 -> $2"; return; fi
  mkdir -p "$2"; cp -f "$1" "$2/" && ok "$(basename "$1") -> ${2/#$HOME/~}"
}
copy_cfg "$KIT/config/kitty/kitty.conf"              "$HOME/.config/kitty"
copy_cfg "$KIT/config/starship.toml"                 "$HOME/.config"
copy_cfg "$KIT/config/fastfetch/config.jsonc"        "$HOME/.config/fastfetch"
copy_cfg "$KIT/config/btop/btop.conf"                "$HOME/.config/btop"
copy_cfg "$KIT/config/btop/themes/arc-reactor.theme" "$HOME/.config/btop/themes"
copy_cfg "$KIT/config/warp/arc_reactor.yaml"         "$HOME/.local/share/warp-terminal/themes"
copy_cfg "$KIT/config/warp/arc_reactor.yaml"         "$HOME/.warp/themes"

# fastfetch logo: regenerate if possible, else use the bundled copy
if [ "$DRY_RUN" != "1" ]; then
  if python3 "$KIT/scripts/make_ascii_logo.py" >/dev/null 2>&1; then
    ok "arc-reactor ASCII logo generated"
  else
    mkdir -p "$HOME/.config/fastfetch"
    cp -f "$KIT/assets/arc-reactor.txt" "$HOME/.config/fastfetch/"
    ok "arc-reactor ASCII logo (bundled copy)"
  fi
fi

# ---- shell integration -----------------------------------------------------
if [ "$DRY_RUN" != "1" ]; then
  if grep -q '# >>> arc-reactor >>>' "$HOME/.bashrc" 2>/dev/null; then
    sed -i '/# >>> arc-reactor >>>/,/# <<< arc-reactor <<</d' "$HOME/.bashrc"
    info "replaced existing arc-reactor block"
  fi
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
       info 'added ~/.local/bin to PATH' ;;
  esac
  cat "$KIT/config/bashrc-block.sh" >> "$HOME/.bashrc"
  bash -n "$HOME/.bashrc" && ok "shell integration appended to ~/.bashrc" \
    || bad "~/.bashrc has a syntax error — check the appended block"
fi

# ---- dock ------------------------------------------------------------------
if [ "$DRY_RUN" != "1" ] && gsettings list-schemas 2>/dev/null | grep -q dash-to-dock; then
  ok "dock configured by scripts/configure-extensions.sh"
fi

# ---- pin kitty to the dock -------------------------------------------------
if [ "$DO_TOOLS" = "1" ] && [ "$DRY_RUN" != "1" ] && have kitty; then
  python3 - <<'PY' 2>/dev/null && ok "kitty pinned to the dock" || true
import subprocess, ast
g = subprocess.check_output(["gsettings","get","org.gnome.shell","favorite-apps"], text=True).strip()
apps = ast.literal_eval(g)
if "kitty.desktop" not in apps:
    apps.insert(min(2, len(apps)), "kitty.desktop")
    subprocess.run(["gsettings","set","org.gnome.shell","favorite-apps",
                    "[" + ", ".join(f"'{a}'" for a in apps) + "]"], check=True)
PY
fi

# ============================================================================
step "VS Code"
# ============================================================================
if [ "$DO_VSCODE" = "1" ]; then
  DID=0
  for variant in code cursor vscodium code-oss; do
    case $variant in
      code)     p="$HOME/.config/Code/User/settings.json" ;;
      cursor)   p="$HOME/.config/Cursor/User/settings.json" ;;
      vscodium) p="$HOME/.config/VSCodium/User/settings.json" ;;
      code-oss) p="$HOME/.config/Code - OSS/User/settings.json" ;;
    esac
    [ -f "$p" ] || continue
    if [ "$DRY_RUN" = "1" ]; then info "[dry-run] would theme $variant"; DID=1; continue; fi
    python3 "$KIT/scripts/apply-vscode-theme.py" --variant "$variant" 2>&1 \
      | sed 's/^/    /' && DID=1
  done
  [ "$DID" = "1" ] || warn "no VS Code / Cursor / VSCodium settings found — skipped"
else
  warn "skipped (--no-vscode)"
fi

# ============================================================================
step "Done"
# ============================================================================
cp -f "$KIT/uninstall.sh" "$AR/uninstall.sh" 2>/dev/null || true
cat <<EOF

  ${C_BLD}Arc Reactor installed.${C_OFF}

  ${C_YEL}LOG OUT AND BACK IN NOW.${C_OFF}
  GNOME cannot load new extensions into a running session (especially on
  Wayland). Until you do, you will not see window animations, rounded
  corners, the HUD readouts, Search Light, the cube or Coverflow.

  After logging back in:
      $KIT/verify.sh

  Manual step that has no CLI:
      Warp -> Settings -> Appearance -> Themes -> Arc Reactor

  Undo everything:
      $KIT/uninstall.sh            # settings only
      $KIT/uninstall.sh --purge    # also remove installed files

  Backup of your previous setup: $BK
  Full documentation:            $KIT/README.md

EOF
