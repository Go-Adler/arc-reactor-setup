#!/usr/bin/env bash
# ============================================================================
#  Arc Reactor — uninstaller
#
#      ./uninstall.sh            restore settings, keep installed files
#      ./uninstall.sh --purge    also delete themes, icons, fonts, extensions,
#                                kitty and the CLI tools
#
#  Log out and back in afterwards. The backup at ~/.arc-reactor/backup is
#  never deleted by either mode.
# ============================================================================
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$KIT/lib/common.sh" ] && . "$KIT/lib/common.sh" || {
  step(){ printf '\n▸ %s\n' "$*"; }; ok(){ printf '  ✓ %s\n' "$*"; }
  warn(){ printf '  ! %s\n' "$*"; }; info(){ printf '    %s\n' "$*"; }
  die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
}

AR="$HOME/.arc-reactor"
BK="$AR/backup"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1
case "${1:-}" in
  -h|--help) sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -d "$BK/dconf" ] || die "no backup found at $BK — nothing to restore from."

step "Restoring dconf trees"
restore_tree() {   # <dconf path> <ini filename>
  if [ -s "$BK/dconf/$2" ]; then
    dconf reset -f "$1" 2>/dev/null
    dconf load "$1" < "$BK/dconf/$2" && ok "$1"
  fi
}
restore_tree /org/gnome/desktop/interface/       org_gnome_desktop_interface.ini
restore_tree /org/gnome/desktop/background/      org_gnome_desktop_background.ini
restore_tree /org/gnome/desktop/screensaver/     org_gnome_desktop_screensaver.ini
restore_tree /org/gnome/desktop/wm/preferences/  org_gnome_desktop_wm_preferences.ini
restore_tree /org/gnome/desktop/wm/keybindings/  org_gnome_desktop_wm_keybindings.ini
restore_tree /org/gnome/mutter/                  org_gnome_mutter.ini
restore_tree /org/gnome/shell/                   org_gnome_shell.ini

step "Restoring config files"
for f in .bashrc .bash_profile .zshrc; do
  if [ -f "$BK/configs/$f" ]; then
    [ -f "$HOME/$f" ] && cp -a "$HOME/$f" "$HOME/$f.arc-reactor-old"
    cp -a "$BK/configs/$f" "$HOME/$f"
    ok "~/$f (previous kept as ~/$f.arc-reactor-old)"
  fi
done
# If there was no backup of .bashrc, at least strip our block.
if [ ! -f "$BK/configs/.bashrc" ] && grep -q '# >>> arc-reactor >>>' "$HOME/.bashrc" 2>/dev/null; then
  sed -i '/# >>> arc-reactor >>>/,/# <<< arc-reactor <<</d' "$HOME/.bashrc"
  ok "removed the arc-reactor block from ~/.bashrc"
fi
for d in gtk-3.0 gtk-4.0; do
  if [ -d "$BK/configs/$d" ]; then
    rm -rf "$HOME/.config/$d"; cp -a "$BK/configs/$d" "$HOME/.config/$d"
    ok "~/.config/$d"
  fi
done
if [ -f "$BK/configs/vscode-settings.json" ]; then
  cp -a "$BK/configs/vscode-settings.json" "$HOME/.config/Code/User/settings.json"
  ok "VS Code settings.json"
elif [ -f "$HOME/.config/Code/User/settings.json.pre-arc-reactor" ]; then
  mv -f "$HOME/.config/Code/User/settings.json.pre-arc-reactor" \
        "$HOME/.config/Code/User/settings.json"
  ok "VS Code settings.json (from .pre-arc-reactor)"
fi
for v in Cursor VSCodium "Code - OSS"; do
  p="$HOME/.config/$v/User/settings.json"
  [ -f "$p.pre-arc-reactor" ] && mv -f "$p.pre-arc-reactor" "$p" && ok "$v settings.json"
done

if [ "$PURGE" = "1" ]; then
  step "Purging installed assets"

  rm -rf "$HOME/.themes/ArcReactor" \
         "$HOME/.themes/Colloid-Red-Dark" \
         "$HOME/.themes/Colloid-Red-Dark-hdpi" \
         "$HOME/.themes/Colloid-Red-Dark-xhdpi"
  rm -rf "$HOME/.local/share/icons/Colloid-Red" \
         "$HOME/.local/share/icons/Colloid-Red-Dark" \
         "$HOME/.local/share/icons/Colloid-Red-Light"
  rm -rf "$HOME/.icons/Bibata-Modern-Amber"
  ok "themes, icons, cursor"

  if [ -f "$AR/installed-extensions.txt" ]; then
    while read -r uuid; do
      [ -n "$uuid" ] && rm -rf "$HOME/.local/share/gnome-shell/extensions/$uuid"
    done < "$AR/installed-extensions.txt"
    ok "extensions listed in installed-extensions.txt"
  else
    warn "no extension manifest — extensions left in place"
    info "remove by hand from ~/.local/share/gnome-shell/extensions/"
  fi
  rm -rf "$HOME/.config/burn-my-windows"

  rm -rf "$HOME/.config/kitty" "$HOME/.config/fastfetch" \
         "$HOME/.config/btop" "$HOME/.config/starship.toml" \
         "$HOME/.local/kitty.app"
  rm -f  "$HOME/.local/share/applications/kitty.desktop" \
         "$HOME/.local/share/applications/kitty-open.desktop"
  for b in kitty kitten starship fastfetch btop eza bat fzf zoxide; do
    rm -f "$HOME/.local/bin/$b"
  done
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  ok "terminal stack"

  rm -f "$HOME/.local/share/warp-terminal/themes/arc_reactor.yaml" \
        "$HOME/.warp/themes/arc_reactor.yaml"
  rm -rf "$HOME/.local/share/fonts/ArcReactor"
  fc-cache -f >/dev/null 2>&1
  ok "Warp theme, fonts"

  rm -f "$HOME/.local/share/backgrounds"/arc-reactor-*.png
  rm -rf "$AR/wallpapers" "$AR/src"
  ok "wallpapers, cloned theme sources"
fi

cat <<EOF

  Rollback complete. ${C_YEL:-}Log out and back in to finish.${C_OFF:-}
  Your backup is still intact at $BK

EOF
