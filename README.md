# Arc Reactor

An Iron Man HUD desktop for GNOME. Charcoal base, armour red and gold, reactor
cyan as the "energised" accent — applied consistently across the shell, GTK,
the terminal, the prompt and the editor.

Everything installs **user-local**. No `sudo`, no system files touched.

---

## Quick start

```bash
git clone <this-repo> arc-reactor-setup     # or: tar -xzf arc-reactor-setup.tar.gz
cd arc-reactor-setup
./install.sh --dry-run                      # see exactly what it will do
./install.sh                                # do it
```

Then **log out and back in**, and run:

```bash
./verify.sh
```

To undo:

```bash
./uninstall.sh            # restore settings, keep installed files
./uninstall.sh --purge    # also remove themes, fonts, extensions, kitty, CLI tools
```

---

## ⚠ You must log out

GNOME cannot load newly installed extensions into a running session — on
Wayland there is no way to restart the shell at all. Everything else (theme,
icons, cursor, fonts, wallpaper, terminal) applies immediately.

Until you log out you will **not** see: window animations, rounded corners, the
HUD monitor readouts, Search Light, the 3D cube, or Coverflow Alt-Tab.

`verify.sh` reports these as `… pending` rather than failures before logout.

---

## Requirements

| | |
|---|---|
| **Desktop** | GNOME Shell **45–49** (tested on 46). The installer detects your version and fetches matching extension builds; anything without a build for your version is skipped with a warning and the rest still installs. Older GNOME will mostly work but several extensions dropped support below 45. |
| **Distro** | Any. Tested on Ubuntu 24.04. Ubuntu's built-in dock is used if present; elsewhere upstream Dash to Dock is installed. |
| **Session** | Wayland or X11. |
| **Arch** | x86_64 or aarch64. |
| **Commands** | `curl jq git python3 gsettings dconf fc-cache unzip tar sed` |
| **Optional** | `numpy` + `pillow` — lets the wallpaper render at *your* native resolution instead of using the bundled 1080p one. |

Install prerequisites:

```bash
# Debian / Ubuntu
sudo apt install curl jq git python3 python3-numpy python3-pil unzip tar \
                 libglib2.0-bin fontconfig gnome-shell-extension-prefs

# Fedora
sudo dnf install curl jq git python3 python3-numpy python3-pillow unzip tar \
                 glib2 fontconfig

# Arch
sudo pacman -S curl jq git python python-numpy python-pillow unzip tar \
               glib2 fontconfig
```

The installer refuses to start if a required command is missing, and tells you
which one.

---

## Palette

| Role | Hex | Used for |
|---|---|---|
| base | `#0d0b0b` | backgrounds (near-black, faintly warm) |
| mantle | `#080707` | panel / titlebar / status chrome |
| surface | `#171213` → `#3a2c2e` | cards, inputs, hovers |
| **armour red** | `#e62429` | primary accent — focus, active, indicators |
| **armour gold** | `#f0a020` | secondary — labels, paths, warnings |
| **reactor cyan** | `#55d9f0` | energised state — cursor, selection, live |
| text | `#ece6e4` / `#a89a98` | foreground / muted |

The terminal side is wired through the **named ANSI colours**
(`color1`=red, `color3`=gold, `color4`=cyan). That is deliberate: fastfetch,
bat, fzf and eza then inherit the palette automatically instead of carrying a
second hardcoded copy of it.

---

## What gets installed

### Look
- **GTK / libadwaita** — Colloid, red accent, `black rimless normal float`
  tweaks, plus gtk-4.0 so libadwaita apps (Nautilus, Settings) match.
- **GNOME Shell** — a custom `ArcReactor` theme: floating glass panel with a red
  hairline, Orbitron clock with a gold glow, red pill buttons, cyan focus rings,
  glass menus, red-edged notifications, HUD lock screen.
- **Icons** — Colloid red. **Cursor** — Bibata Modern Amber.
- **Fonts** — JetBrainsMono Nerd Font (terminal), Rajdhani (UI), Orbitron (HUD
  accents), Inter (documents).
- **Wallpaper** — generated, not downloaded, so it matches the palette exactly.

### Motion
| Action | Effect |
|---|---|
| Open a window | **Energize B** — materialises in reactor cyan, 420 ms |
| Close a window | **Incinerate** — disintegrates from the pointer in gold-red, 800 ms |
| Minimise | Magic-lamp genie |
| Drag / resize | Wobbly windows |
| Switch workspace | 3D **cube** |
| `Alt`+`Tab` | **Coverflow** with a red highlight |
| `Super`+`Space` | **Search Light** — blurred, red-rimmed spotlight launcher |

### Terminal
kitty (frosted glass), **starship** prompt, **fastfetch** with a generated
arc-reactor logo, **btop** with a matching theme, plus `eza`, `bat`, `fzf`,
`zoxide`. All into `~/.local/bin` and `~/.local/kitty.app`.

### Editors
VS Code / Cursor / VSCodium get 121 `colorCustomizations` plus JetBrainsMono
with ligatures. **Your syntax theme is left alone** — only the chrome, editor
background and integrated terminal are retargeted. A Warp theme is written too.

---

## Manual steps the installer cannot do

1. **Warp theme** — Warp has no CLI for theme selection.
   *Settings → Appearance → Themes → Arc Reactor*
2. **Log out and back in** (see above).

---

## Behaviour changes worth knowing

The installer changes a few non-cosmetic things. Each is listed with its undo.

| Change | Why | Undo |
|---|---|---|
| Workspaces become **static, 4** | Desktop Cube needs a fixed face count to read as a cube | `gsettings set org.gnome.mutter dynamic-workspaces true` |
| `Super`+`Space` reassigned to Search Light | It defaults to input-source switching, which does nothing with a single layout. **Skipped automatically if you have 2+ input sources.** | `gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']"` |
| Login lands on the **desktop**, not the overview | Shows the wallpaper | Just Perfection → `startup-status 1` |
| UI font is **Rajdhani SemiBold 12** | Condensed and techy | `gsettings set org.gnome.desktop.interface font-name 'Inter Variable 11'` |
| kitty has **no titlebar** | Cleaner. Move with `Super`+drag | set `hide_window_decorations no` in `~/.config/kitty/kitty.conf` |
| `cat` aliased to `bat` | Nicer paging. Pipe-safe — bat passes through unstyled when stdout isn't a tty | delete the block in `~/.bashrc` |
| `window-list`, old `system-monitor`, `ding` disabled | They fight the floating dock / duplicate Astra Monitor / clutter the wallpaper | re-enable via Extensions app |

---

## Tuning

**Wallpaper** — regenerate at any size:

```bash
./scripts/make_wallpaper.py                      # auto-detects your display
./scripts/make_wallpaper.py -w 3440 -H 1440 --geo 0.42   # ultrawide
./scripts/make_wallpaper.py --geo 0.65           # bigger reactor
```

`--geo` is the reactor's size relative to screen height. On very wide displays
lower it, or the reactor dominates. Supersampling is chosen automatically from a
pixel budget so it won't exhaust RAM at 4K.

**fastfetch logo** — `./scripts/make_ascii_logo.py` (edit the band radii in
`pixel()` to restyle it).

**Every extension setting** — `./scripts/configure-extensions.sh`. Idempotent,
re-runnable, and the single source of truth for the extension config.

**VS Code** — `./scripts/apply-vscode-theme.py --variant cursor`, or
`--revert`.

---

## Performance

On an Intel iGPU at 1080p this is comfortable but not free. Panel blur uses
*static* blur (much cheaper, visually identical here) and window animations run
at 420 ms rather than the 1000 ms defaults.

If it feels sluggish, disable in this order — most expensive first:

```bash
gnome-extensions disable desktop-cube@schneegans.github.com
gnome-extensions disable compiz-windows-effect@hermes83.github.com
gnome-extensions disable CoverflowAltTab@palatis.blogspot.com
```

Then the glass terminal, which is the next biggest cost:

```bash
gsettings --schemadir ~/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas \
  set org.gnome.shell.extensions.blur-my-shell.applications blur false
```

---

## If the desktop won't load

Stacked compositor effects can, in rare cases, crash GNOME Shell at startup
against a particular Mesa version. On Wayland you cannot restart the shell, so
know the escape hatch **before** you log out:

1. At the login screen, click the **gear icon** and choose **"GNOME on Xorg"**
   (or "Ubuntu on Xorg"). Extensions still load, but `Alt`+`F2` → `r` restarts
   the shell.
2. If that also fails, `Ctrl`+`Alt`+`F3` gives you a TTY. `./uninstall.sh` works
   fine with no graphical session.
3. Nuclear option, no scripts needed:
   ```bash
   dconf write /org/gnome/shell/enabled-extensions "[]"
   dconf write /org/gnome/shell/extensions/user-theme/name "''"
   ```

---

## Troubleshooting

**Terminal shows boxes instead of icons** — the Nerd Font didn't install. Check
`fc-list "JetBrainsMono Nerd Font"`, then re-run `./install.sh`.

**An extension says "no build for GNOME N"** — upstream hasn't released for your
version. The installer skips it and continues; the rest still works.

**Panel looks unstyled** — the User Themes extension has to be active for a
custom shell theme. Confirm with
`gnome-extensions info user-theme@gnome-shell-extensions.gcampax.github.com`.

**Wallpaper is 1080p on a 4K screen** — `numpy`/`pillow` were missing at install
time. Install them and run `./scripts/make_wallpaper.py`.

**Colours look wrong in the terminal** — something is overriding the ANSI
palette. Check for a competing theme in `~/.config/kitty/`.

**Blur isn't visible behind kitty** — Blur My Shell matches on WM_CLASS. Confirm
with `xprop WM_CLASS` (X11) and that `kitty` is in the whitelist:
`gsettings --schemadir ~/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas get org.gnome.shell.extensions.blur-my-shell.applications whitelist`

---

## Deliberate omissions

- **Open Bar** is installed but left **disabled**. It injects its own panel
  stylesheet that overrides the hand-written `#panel` rules in the ArcReactor
  theme. Enable it only if you'd rather tune the bar through its GUI.
- **No dock icon magnification.** dash-to-dock has no macOS-style hover
  magnification. Nothing in this stack provides it.
- **GDM login screen and Plymouth boot splash are untouched** — both need root
  and system file edits, which this kit avoids by design.

---

## Layout

```
arc-reactor-setup/
├── README.md                     this file
├── PALETTE.md                    colour reference for extending the theme
├── install.sh                    installer (--dry-run / --no-tools / --no-extensions / --no-vscode)
├── uninstall.sh                  rollback (--purge)
├── verify.sh                     post-install checks
├── lib/common.sh                 shared helpers
├── config/
│   ├── kitty/kitty.conf
│   ├── starship.toml
│   ├── fastfetch/config.jsonc
│   ├── btop/{btop.conf,themes/arc-reactor.theme}
│   ├── burn-my-windows/profiles/ open + close animation profiles
│   ├── warp/arc_reactor.yaml
│   └── bashrc-block.sh           appended to ~/.bashrc between markers
├── themes/ArcReactor/            shell theme OVERLAY (see note below)
├── scripts/
│   ├── make_wallpaper.py         resolution-independent wallpaper generator
│   ├── make_ascii_logo.py        fastfetch logo generator
│   ├── configure-extensions.sh   every extension + dock setting
│   ├── apply-vscode-theme.py     merges into settings.json, never overwrites
│   └── extensions.txt            UUID manifest with descriptions
└── assets/
    ├── wallpapers/               pre-rendered 1080p fallback
    └── arc-reactor.txt           pre-rendered ASCII logo fallback
```

**Note on the shell theme.** `themes/ArcReactor/` contains only the *overlay*
stylesheet. Its `base.css` is generated at install time from whichever Colloid
version your machine downloads, with Colloid's accents rewritten to the Arc
Reactor palette. Shipping a frozen `base.css` would silently drift from the
Colloid release actually installed, so it is built rather than bundled.

---

## Two implementation traps

Worth knowing if you edit these files:

1. **GNOME Shell's St CSS is not real CSS.** No `var()`, no `calc()`, no
   `letter-spacing`, no `linear-gradient()` in `background`. Worse, a
   `font-family` list of **three or more** families is rejected outright and the
   whole rule is silently dropped. Every `font-family` in
   `themes/ArcReactor/gnome-shell/gnome-shell.css` is therefore a single family.
2. **kitty rejects malformed hex.** `#08_0707` fails to parse and aborts the
   whole config. Validate changes with:
   ```bash
   kitty +runpy 'from kitty.config import load_config; load_config("'$HOME'/.config/kitty/kitty.conf")'
   ```

Also: starship here is intentionally **not** powerline. With background-filled
segments, any module that renders empty (no git repo, no node project) leaves a
colour discontinuity in the separator chain. Each segment carries its own
leading `╶` divider instead, so the line is always correct.
