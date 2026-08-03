# Arc Reactor — palette reference

Use this when extending the theme to something not covered by the kit (a new
app, a Vim colourscheme, a Slack sidebar, a website).

## Core

| Token | Hex | RGB | GdkRGBA doubles |
|---|---|---|---|
| base | `#0d0b0b` | 13, 11, 11 | 0.051, 0.043, 0.043 |
| mantle | `#080707` | 8, 7, 7 | 0.031, 0.027, 0.027 |
| surface0 | `#171213` | 23, 18, 19 | 0.090, 0.071, 0.075 |
| surface1 | `#211a1b` | 33, 26, 27 | 0.129, 0.102, 0.106 |
| surface2 | `#2e2425` | 46, 36, 37 | 0.180, 0.141, 0.145 |
| overlay | `#3a2c2e` | 58, 44, 46 | 0.227, 0.173, 0.180 |
| text | `#ece6e4` | 236, 230, 228 | 0.925, 0.902, 0.894 |
| subtext | `#a89a98` | 168, 154, 152 | 0.659, 0.604, 0.596 |
| muted | `#6b5f5d` | 107, 95, 93 | 0.420, 0.373, 0.365 |

## Accents

| Token | Hex | RGB | Meaning |
|---|---|---|---|
| **red** (armour) | `#e62429` | 230, 36, 41 | primary — focus, active, running, alert |
| red bright | `#ff4d52` | 255, 77, 82 | hover / emphasis on red |
| red dim | `#8c1418` | 140, 20, 24 | gradient tail, graph low end |
| **gold** (armour) | `#f0a020` | 240, 160, 32 | secondary — labels, paths, warnings |
| gold bright | `#ffc35c` | 255, 195, 92 | hover / emphasis on gold |
| gold dim | `#8a5a10` | 138, 90, 16 | gradient tail |
| **cyan** (reactor) | `#55d9f0` | 85, 217, 240 | energised — cursor, selection, live state |
| cyan bright | `#86e8ff` | 134, 232, 255 | hover / emphasis on cyan |
| cyan dim | `#2a8fa8` | 42, 143, 168 | gradient tail |
| white-hot | `#eaf8ff` | 234, 248, 255 | reactor core only — use very sparingly |

## Terminal 16

The whole terminal stack resolves against these, so setting them once themes
fastfetch, bat, fzf, eza and anything else that uses named ANSI colours.

| # | Name | Normal | Bright |
|---|---|---|---|
| 0 / 8 | black | `#1f1a1a` | `#4b3f3f` |
| 1 / 9 | red | `#e62429` | `#ff4d52` |
| 2 / 10 | green | `#7bd88f` | `#9cf0ae` |
| 3 / 11 | yellow | `#f0a020` | `#ffc35c` |
| 4 / 12 | blue | `#55d9f0` | `#86e8ff` |
| 5 / 13 | magenta | `#d05a9e` | `#f07ac0` |
| 6 / 14 | cyan | `#4fc9d9` | `#7fe3f0` |
| 7 / 15 | white | `#d8d2d0` | `#f5efed` |

Note `blue` is mapped to reactor cyan and `yellow` to armour gold — that is what
makes generic tools come out on-palette without per-tool configuration.

## Usage rules

1. **Red is for state, not decoration.** Focus rings, active tabs, running
   indicators, the current item. If everything is red, nothing reads as active.
2. **Cyan means "live".** Cursors, selections, the focused window preview,
   energised transitions. Never use it for a static label.
3. **Gold is for identity and orientation** — paths, section headers, keys in a
   readout, the clock.
4. **White-hot is the reactor core only.** One or two pixels' worth per screen.
5. **Backgrounds step, they don't jump.** base → surface0 → surface1 for nesting
   depth; keep contrast between adjacent layers subtle.
6. **Gradients run cool → hot** (cyan → gold → red) to signal increasing load.
   That is why btop glows red under pressure.

## Fonts

| Use | Family | Notes |
|---|---|---|
| Terminal / code | JetBrainsMono Nerd Font | ligatures on; the Nerd patch supplies the icons |
| UI | Rajdhani SemiBold | condensed, techy; swap to Inter if too much |
| HUD accents | Orbitron | clock, banners, headings only — poor at small sizes for body text |
| Documents | Inter Variable | real family name is `Inter Variable`, with a space |

## Opacity conventions

| Surface | Alpha | Why |
|---|---|---|
| top panel | 0.42 | low enough for the blur behind it to read |
| dock | 0.20 (+ Blur My Shell) | the dock's own background stays near-clear; the blur layer paints it |
| menus / popovers | 0.90 | readable over any wallpaper |
| terminal | 0.50 | tune to taste in `kitty.conf` |
| red hairlines / rims | 0.26 – 0.42 | a highlight, not an outline |

## Hex-with-alpha for VS Code

VS Code takes 8-digit hex. Common suffixes used in this theme:

| Suffix | Alpha | Used for |
|---|---|---|
| `26` | 15 % | subtle highlight fill |
| `33` | 20 % | hover fill |
| `40` | 25 % | selection, borders |
| `3D` | 24 % | active list selection |
| `66` | 40 % | active indent guide |
| `80` | 50 % | focus outline |
| `99` | 60 % | focus border |
