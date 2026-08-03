#!/usr/bin/env bash
# ============================================================================
#  Arc Reactor — verification
#  Run after installing, and again after logging out and back in (extension
#  state is only meaningful once GNOME has actually loaded them).
# ============================================================================
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$KIT/lib/common.sh" ] && . "$KIT/lib/common.sh" || {
  C_GRN=; C_RED=; C_YEL=; C_BLD=; C_OFF=; C_CYN=
  step(){ printf '\n▸ %s\n' "$*"; }
}

PASS=0 FAIL=0 PENDING=0
p(){ printf '  %s✓%s %s\n' "$C_GRN" "$C_OFF" "$1"; PASS=$((PASS+1)); }
f(){ printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$1"; FAIL=$((FAIL+1)); }
w(){ printf '  %s…%s %s\n' "$C_YEL" "$C_OFF" "$1"; PENDING=$((PENDING+1)); }
c(){ if eval "$2" >/dev/null 2>&1; then p "$1"; else f "$1"; fi; }
# eqs <label> <schema> <key> <expected>  — reads the setting itself, which
# avoids the nested-quoting trap of passing a command substitution as an arg.
eqs(){
  local got
  got=$(gsettings get "$2" "$3" 2>/dev/null | tr -d "'")
  if [ "$got" = "$4" ]; then p "$1 = $got"
  else f "$1 = ${got:-<unset>} (expected $4)"; fi
}

printf '%s══ Arc Reactor verification ══%s\n' "$C_BLD$C_CYN" "$C_OFF"

step "Fonts"
for fam in "JetBrainsMono Nerd Font" "Rajdhani" "Orbitron" "Inter Variable"; do
  c "$fam" "fc-list '$fam' | grep -q ."
done

step "Themes and assets"
c "GTK theme Colloid-Red-Dark"   "[ -d ~/.themes/Colloid-Red-Dark ]"
c "Shell theme ArcReactor"       "[ -f ~/.themes/ArcReactor/gnome-shell/gnome-shell.css ]"
c "  └ base.css generated"       "[ -s ~/.themes/ArcReactor/gnome-shell/base.css ]"
c "  └ accents remapped to red"  "grep -qi '#E62429' ~/.themes/ArcReactor/gnome-shell/base.css"
c "gtk-4.0 (libadwaita) themed"  "[ -f ~/.config/gtk-4.0/gtk.css ]"
c "Icons Colloid-Red-Dark"       "[ -d ~/.local/share/icons/Colloid-Red-Dark ]"
c "Cursor Bibata-Modern-Amber"   "[ -d ~/.icons/Bibata-Modern-Amber/cursors ]"
c "Wallpaper present"            "ls ~/.local/share/backgrounds/arc-reactor-*.png"

step "Applied settings"
eqs "gtk-theme"    org.gnome.desktop.interface gtk-theme     Colloid-Red-Dark
eqs "icon-theme"   org.gnome.desktop.interface icon-theme    Colloid-Red-Dark
eqs "cursor-theme" org.gnome.desktop.interface cursor-theme  Bibata-Modern-Amber
eqs "shell theme"  org.gnome.shell.extensions.user-theme name ArcReactor
case "$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null)" in
  *arc-reactor*) p "wallpaper points at an arc-reactor image" ;;
  *)             f "wallpaper is not an arc-reactor image" ;;
esac

step "Extensions (state is only meaningful AFTER a logout)"
LOADED=0
for u in blur-my-shell@aunetx \
         burn-my-windows@schneegans.github.com \
         rounded-window-corners@fxgn \
         monitor@astraext.github.io \
         search-light@icedman.github.com \
         desktop-cube@schneegans.github.com \
         CoverflowAltTab@palatis.blogspot.com \
         compiz-windows-effect@hermes83.github.com \
         just-perfection-desktop@just-perfection; do
  if [ ! -f "$HOME/.local/share/gnome-shell/extensions/$u/metadata.json" ] \
     && [ ! -f "/usr/share/gnome-shell/extensions/$u/metadata.json" ]; then
    f "${u%%@*} — NOT INSTALLED"; continue
  fi
  st=$(gnome-extensions info "$u" 2>/dev/null | awk -F': ' '/State/{print $2}')
  case "$st" in
    ACTIVE)  p "${u%%@*} — ACTIVE"; LOADED=1 ;;
    ERROR|OUT_OF_DATE) f "${u%%@*} — $st" ;;
    # Installed but not yet picked up by the running shell. Expected until you
    # log out, so it is pending rather than a failure.
    *)       w "${u%%@*} — installed, awaiting logout (${st:-not loaded})" ;;
  esac
done

step "Burn My Windows profiles"
c "open profile (energize-b)"  "grep -qs 'energize-b-enable-effect=true' ~/.config/burn-my-windows/profiles/*.conf"
c "close profile (incinerate)" "grep -qs 'incinerate-enable-effect=true' ~/.config/burn-my-windows/profiles/*.conf"

step "Terminal stack"
for t in kitty starship fastfetch btop eza bat fzf zoxide; do
  c "$t on PATH" "command -v $t"
done
c "kitty.conf"                "[ -f ~/.config/kitty/kitty.conf ]"
if command -v kitty >/dev/null 2>&1; then
  c "kitty.conf parses"       "kitty +runpy 'from kitty.config import load_config; load_config(\"$HOME/.config/kitty/kitty.conf\")'"
fi
c "starship.toml"             "[ -f ~/.config/starship.toml ]"
c "fastfetch config"          "[ -f ~/.config/fastfetch/config.jsonc ]"
c "fastfetch logo"            "[ -s ~/.config/fastfetch/arc-reactor.txt ]"
c "btop theme"                "[ -f ~/.config/btop/themes/arc-reactor.theme ]"
c "shell integration block"   "grep -q '>>> arc-reactor >>>' ~/.bashrc"

step "Editors"
if [ -f "$HOME/.config/Code/User/settings.json" ]; then
  c "VS Code Arc Reactor colours" \
    "python3 -c \"import json;d=json.load(open('$HOME/.config/Code/User/settings.json'));assert d['workbench.colorCustomizations']['activityBar.foreground'].lower()=='#e62429'\""
fi
c "Warp theme file" "[ -f ~/.local/share/warp-terminal/themes/arc_reactor.yaml ]"

step "Rollback safety"
c "backup dconf dump" "[ -s ~/.arc-reactor/backup/dconf/FULL-dconf-dump.ini ]"
c "settings snapshot" "[ -s ~/.arc-reactor/backup/settings-snapshot.txt ]"
c "uninstall.sh"      "[ -x $KIT/uninstall.sh ]"

printf '\n%s══ %d passed, %d failed, %d pending ══%s\n' \
  "$C_BLD" "$PASS" "$FAIL" "$PENDING" "$C_OFF"
if [ "$PENDING" -gt 0 ]; then
  printf '%s%d extension(s) installed but not yet loaded — LOG OUT AND BACK IN,%s\n' \
    "$C_YEL" "$PENDING" "$C_OFF"
  printf '%sthen run this script again. That is expected, not a problem.%s\n' \
    "$C_YEL" "$C_OFF"
fi
[ "$FAIL" -eq 0 ]
