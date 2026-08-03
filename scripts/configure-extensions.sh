#!/usr/bin/env bash
# ============================================================================
#  Arc Reactor — extension + dock configuration
#
#  Idempotent and standalone: safe to re-run at any time to re-apply every
#  setting. Uses `gsettings --schemadir` so it works even before GNOME has
#  loaded the extensions (i.e. before you log out and back in).
#
#  Extensions that are not installed are skipped rather than erroring, so this
#  works on machines where some extension has no build for the running GNOME.
#
#  Palette as GdkRGBA doubles:
#    red   #e62429 -> 0.902, 0.141, 0.161
#    gold  #f0a020 -> 0.941, 0.627, 0.125
#    cyan  #55d9f0 -> 0.333, 0.851, 0.941
#    base  #0d0b0b -> 0.051, 0.043, 0.043
# ============================================================================
set -uo pipefail

EXTD="$HOME/.local/share/gnome-shell/extensions"
SYSD="/usr/share/gnome-shell/extensions"
QUIET=${QUIET:-0}

_say()  { [ "$QUIET" = "1" ] || printf '    %-44s %s\n' "$1" "$2"; }
present() { [ -f "$EXTD/$1/metadata.json" ] || [ -f "$SYSD/$1/metadata.json" ]; }
skipmsg() { [ "$QUIET" = "1" ] || printf '  (not installed, skipped: %s)\n' "$1"; }

# s <uuid> <schema-id> <key> <value>
s() {
  local uuid="$1" schema="$2" key="$3" val="$4" sd="$EXTD/$1/schemas"
  present "$uuid" || return 0
  if [ -d "$sd" ] && gsettings --schemadir "$sd" set "$schema" "$key" "$val" 2>/dev/null; then
    _say "$key" "$val"; return 0
  fi
  if gsettings set "$schema" "$key" "$val" 2>/dev/null; then
    _say "$key" "$val"; return 0
  fi
  printf '    !! could not set %s %s\n' "$schema" "$key" >&2
}

# ---------------------------------------------------------------- Blur My Shell
U=blur-my-shell@aunetx
if present $U; then
  echo ">> Blur My Shell — glass everywhere"
  B=org.gnome.shell.extensions.blur-my-shell
  s $U $B sigma 30
  s $U $B brightness 0.6
  s $U $B color "(0.051, 0.043, 0.043, 0.25)"
  s $U $B noise-amount 0.05
  s $U $B color-and-noise true

  # Panel: static blur is far cheaper on an iGPU and looks identical here.
  s $U $B.panel blur true
  s $U $B.panel static-blur true
  s $U $B.panel customize true
  s $U $B.panel sigma 32
  s $U $B.panel brightness 0.55
  s $U $B.panel color "(0.051, 0.043, 0.043, 0.30)"
  s $U $B.panel override-background true
  s $U $B.panel unblur-in-overview true
  s $U $B.panel pipeline pipeline_default

  s $U $B.overview blur true
  s $U $B.overview customize true
  s $U $B.overview sigma 30
  s $U $B.overview brightness 0.55
  s $U $B.overview pipeline pipeline_default

  s $U $B.appfolder blur true
  s $U $B.appfolder customize true
  s $U $B.appfolder sigma 30
  s $U $B.appfolder brightness 0.60

  # Dock: a faint red tint in the glass ties it to the accent.
  s $U $B.dash-to-dock blur true
  s $U $B.dash-to-dock static-blur false
  s $U $B.dash-to-dock customize true
  s $U $B.dash-to-dock sigma 28
  s $U $B.dash-to-dock brightness 0.60
  s $U $B.dash-to-dock color "(0.180, 0.055, 0.060, 0.22)"
  s $U $B.dash-to-dock override-background true
  s $U $B.dash-to-dock corner-radius 22
  s $U $B.dash-to-dock unblur-in-overview false

  # This is what makes the terminal look like frosted glass.
  s $U $B.applications blur true
  s $U $B.applications enable-all false
  s $U $B.applications whitelist "['kitty']"
  s $U $B.applications customize true
  s $U $B.applications sigma 30
  s $U $B.applications brightness 0.60
  s $U $B.applications opacity 235
  s $U $B.applications dynamic-opacity false
  s $U $B.applications static-blur false
  s $U $B.applications corner-radius 14
  s $U $B.applications blur-on-overview true

  s $U $B.lockscreen blur true
  s $U $B.screenshot blur true
  s $U $B.coverflow-alt-tab blur true
  s $U $B.window-list blur false
else skipmsg $U; fi

# ------------------------------------------------ Rounded Window Corners Reborn
U=rounded-window-corners@fxgn
if present $U; then
  echo ">> Rounded Window Corners Reborn"
  R=org.gnome.shell.extensions.rounded-window-corners-reborn
  s $U $R border-width 1
  s $U $R tweak-kitty-terminal true
  s $U $R enable-preferences-entry true

  # a{sv} / a{si} cannot be expressed on the gsettings command line
  python3 - <<'PY' 2>/dev/null || echo "    !! could not set rounded-corner geometry" >&2
import gi, os
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib
sd = os.path.expanduser(
    "~/.local/share/gnome-shell/extensions/rounded-window-corners@fxgn/schemas")
src = Gio.SettingsSchemaSource.new_from_directory(
    sd, Gio.SettingsSchemaSource.get_default(), False)
sch = src.lookup("org.gnome.shell.extensions.rounded-window-corners-reborn", True)
st = Gio.Settings.new_full(sch, None, None)
def v(x): return GLib.Variant("v", x)
st.set_value("global-rounded-corner-settings", GLib.Variant("a{sv}", {
    "padding": v(GLib.Variant("a{sv}", {k: v(GLib.Variant("u", 1))
                                        for k in ("left", "right", "top", "bottom")})),
    "keepRoundedCorners": v(GLib.Variant("a{sv}", {
        "maximized":  v(GLib.Variant("b", False)),
        "fullscreen": v(GLib.Variant("b", False))})),
    "borderRadius": v(GLib.Variant("u", 14)),
    "smoothing":    v(GLib.Variant("d", 0.0)),
    "borderColor":  v(GLib.Variant("ad", [0.902, 0.141, 0.161, 0.40])),
    "enabled":      v(GLib.Variant("b", True)),
}))
st.set_value("focused-shadow", GLib.Variant("a{si}", {
    "horizontalOffset": 0, "verticalOffset": 5,
    "blurOffset": 34, "spreadRadius": 4, "opacity": 70}))
st.set_value("unfocused-shadow", GLib.Variant("a{si}", {
    "horizontalOffset": 0, "verticalOffset": 2,
    "blurOffset": 14, "spreadRadius": -1, "opacity": 60}))
Gio.Settings.sync()
print("    global-rounded-corner-settings               radius=14, red rim @0.40")
PY
else skipmsg $U; fi

# --------------------------------------------------------------- Astra Monitor
U=monitor@astraext.github.io
if present $U; then
  echo ">> Astra Monitor — HUD readouts"
  A=org.gnome.shell.extensions.astra-monitor
  s $U $A headers-font-family "Rajdhani"
  s $U $A headers-font-size 12
  s $U $A compact-mode false

  s $U $A processor-header-show true
  s $U $A processor-header-icon false
  s $U $A processor-header-graph true
  s $U $A processor-header-graph-color1 "#E62429"
  s $U $A processor-header-graph-color2 "#8C1418"
  s $U $A processor-header-graph-width 34
  s $U $A processor-header-percentage true
  s $U $A processor-header-bars false
  s $U $A processor-update 2.0

  s $U $A memory-header-show true
  s $U $A memory-header-icon false
  s $U $A memory-header-graph true
  s $U $A memory-header-graph-color1 "#F0A020"
  s $U $A memory-header-graph-color2 "#8A5A10"
  s $U $A memory-header-graph-width 34
  s $U $A memory-header-percentage true
  s $U $A memory-header-bars false
  s $U $A memory-update 3.0

  s $U $A network-header-show true
  s $U $A network-header-icon false
  s $U $A network-header-io true
  s $U $A network-header-graph false
  s $U $A network-header-io-bars-color1 "#55D9F0"
  s $U $A network-header-io-bars-color2 "#2A8FA8"
  s $U $A network-header-io-graph-color1 "#55D9F0"
  s $U $A network-header-io-graph-color2 "#2A8FA8"
  s $U $A network-update 2.0

  # off by default: storage is noise, and Astra's iGPU support is thin
  s $U $A storage-header-show false
  s $U $A gpu-header-show false
  s $U $A sensors-header-show false
else skipmsg $U; fi

# ---------------------------------------------------------------- Search Light
U=search-light@icedman.github.com
if present $U; then
  echo ">> Search Light — spotlight launcher"
  L=org.gnome.shell.extensions.search-light
  s $U $L shortcut-search "['<Super>space']"
  s $U $L background-color "(0.051, 0.043, 0.043, 0.88)"
  s $U $L border-color "(0.902, 0.141, 0.161, 0.85)"
  s $U $L border-thickness 2
  s $U $L border-radius 1.5
  s $U $L text-color "(0.925, 0.902, 0.894, 1.0)"
  s $U $L entry-text-color "(1.0, 1.0, 1.0, 1.0)"
  s $U $L blur-background true
  s $U $L blur-sigma 36
  s $U $L blur-brightness 0.6
  s $U $L show-panel-icon false
  s $U $L use-animations true
  s $U $L animation-speed 0.25
  s $U $L window-effect 1
  s $U $L window-effect-color "(0.902, 0.141, 0.161, 1.0)"
else skipmsg $U; fi

# ---------------------------------------------------------------- Desktop Cube
U=desktop-cube@schneegans.github.com
if present $U; then
  echo ">> Desktop Cube — 3D workspaces"
  C=org.gnome.shell.extensions.desktop-cube
  s $U $C last-first-gap false        # closed cube rather than a flat strip
  s $U $C workpace-separation 0
  s $U $C do-explode true
  s $U $C window-parallax 0.6
  s $U $C per-monitor-perspective true
  s $U $C enable-desktop-dragging true
  s $U $C enable-panel-dragging true
  s $U $C enable-overview-dragging true
  s $U $C enable-desktop-edge-switch true
  s $U $C enable-overview-edge-switch true
  s $U $C mouse-rotation-speed 2.0
else skipmsg $U; fi

# ------------------------------------------------------------ Coverflow Alt-Tab
U=CoverflowAltTab@palatis.blogspot.com
if present $U; then
  echo ">> Coverflow Alt-Tab"
  F=org.gnome.shell.extensions.coverflowalttab
  s $U $F switcher-style "Coverflow"
  s $U $F animation-time 0.25
  s $U $F dim-factor 0.6
  s $U $F desaturate-factor 0.15
  s $U $F blur-radius 12
  s $U $F hide-panel false
  s $U $F use-tint true
  s $U $F tint-blend 0.15
  s $U $F tint-use-theme-color false
  s $U $F tint-color "(0.902, 0.141, 0.161)"
  s $U $F highlight-use-theme-color false
  s $U $F highlight-color "(0.902, 0.141, 0.161)"
  s $U $F switcher-background-color "(0.051, 0.043, 0.043)"
  s $U $F bind-to-switch-applications true
  s $U $F bind-to-switch-windows true
  s $U $F highlight-mouse-over true
else skipmsg $U; fi

# ------------------------------------------------------- Compiz Windows Effect
U=compiz-windows-effect@hermes83.github.com
if present $U; then
  echo ">> Compiz Windows Effect — wobbly windows"
  W=org.gnome.shell.extensions.com.github.hermes83.compiz-windows-effect
  s $U $W friction 4.0
  s $U $W spring-k 5.0
  s $U $W mass 55.0
  s $U $W speedup-factor-divider 14.0
  s $U $W x-tiles 6.0
  s $U $W y-tiles 6.0
  s $U $W maximize-effect true
  s $U $W resize-effect true
else skipmsg $U; fi

# ------------------------------------------------------------- Just Perfection
U=just-perfection-desktop@just-perfection
if present $U; then
  echo ">> Just Perfection — shell tuning"
  J=org.gnome.shell.extensions.just-perfection
  s $U $J startup-status 0   # land on the desktop, not the overview
  s $U $J panel-size 34      # matches #panel height in the ArcReactor stylesheet
  s $U $J ripple-box false   # no hot-corner ripple
  s $U $J window-preview-caption true
  s $U $J workspace-switcher-should-show true
else skipmsg $U; fi

# ========================================================================= dock
# Ubuntu ships a dash-to-dock fork (ubuntu-dock) whose schema is installed
# system-wide; upstream Dash to Dock lives under ~/.local. Both expose the same
# schema id, so try the caller's UUID first and fall back to plain gsettings.
DOCK_UUID="${ARC_DOCK_UUID:-}"
if [ -z "$DOCK_UUID" ]; then
  if present ubuntu-dock@ubuntu.com; then DOCK_UUID=ubuntu-dock@ubuntu.com
  else DOCK_UUID=dash-to-dock@micxgx.gmail.com; fi
fi

if gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.shell.extensions.dash-to-dock' \
   || present "$DOCK_UUID"; then
  echo ">> Dock — floating glass, bottom centre"
  D=org.gnome.shell.extensions.dash-to-dock
  d() { s "$DOCK_UUID" $D "$1" "$2"; }

  # shape
  d dock-position "'BOTTOM'"
  d extend-height false
  d always-center-icons true
  d dash-max-icon-size 42
  d icon-size-fixed false
  d custom-theme-shrink true
  d force-straight-corner false

  # intellihide: visible on the desktop, out of the way when working
  d dock-fixed false
  d autohide true
  d intellihide true
  d intellihide-mode "'ALL_WINDOWS'"
  d autohide-in-fullscreen true
  d require-pressure-to-show true
  d pressure-threshold 100.0
  d show-delay 0.12
  d hide-delay 0.20
  d animation-time 0.20

  # keep the dock's own background nearly clear; Blur My Shell paints the glass
  d apply-custom-theme false
  d transparency-mode "'FIXED'"
  d background-opacity 0.20
  d custom-background-color false
  d customize-alphas false
  d apply-glossy-effect false
  d unity-backlit-items false

  # running indicators in armour red
  d running-indicator-style "'DOTS'"
  d running-indicator-dominant-color false
  d custom-theme-customize-running-dots true
  d custom-theme-running-dots-color "'#E62429'"
  d custom-theme-running-dots-border-color "'#F0A020'"
  d custom-theme-running-dots-border-width 0

  # contents
  d show-trash false
  d show-mounts false
  d show-show-apps-button true
  d show-apps-at-top false
  d animate-show-apps true
  d show-windows-preview true
  d hide-tooltip false
  d click-action "'minimize-or-previews'"
  d scroll-action "'cycle-windows'"
  d disable-overview-on-startup true
else
  skipmsg "$DOCK_UUID (no dash-to-dock schema found)"
fi

echo
echo ">> done"
