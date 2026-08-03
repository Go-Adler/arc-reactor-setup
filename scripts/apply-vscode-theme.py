#!/usr/bin/env python3
"""
Merge the Arc Reactor palette into VS Code's settings.json.

This MERGES — it never overwrites your file. Your existing keys, your syntax
colour theme and your extension settings are all preserved; only the chrome,
the editor background and the integrated terminal are retargeted.

  ./apply-vscode-theme.py                    # VS Code
  ./apply-vscode-theme.py --variant cursor   # Cursor
  ./apply-vscode-theme.py --path /custom/settings.json
  ./apply-vscode-theme.py --revert           # restore the .pre-arc-reactor backup

A backup is written next to the file as settings.json.pre-arc-reactor the first
time this runs; it is never overwritten on subsequent runs.
"""
import argparse
import json
import os
import re
import shutil
import sys

BASE, MANTLE = "#0d0b0b", "#080707"
S0, S1, S2, OV = "#171213", "#211a1b", "#2e2425", "#3a2c2e"
TEXT, SUB = "#ece6e4", "#a89a98"
RED, REDB = "#e62429", "#ff4d52"
GOLD, CYAN = "#f0a020", "#55d9f0"
GREEN = "#7bd88f"

VARIANTS = {
    "code":   "~/.config/Code/User/settings.json",
    "cursor": "~/.config/Cursor/User/settings.json",
    "vscodium": "~/.config/VSCodium/User/settings.json",
    "code-oss": "~/.config/Code - OSS/User/settings.json",
}

COLORS = {
    # chrome
    "titleBar.activeBackground": MANTLE,
    "titleBar.activeForeground": TEXT,
    "titleBar.inactiveBackground": MANTLE,
    "titleBar.inactiveForeground": SUB,
    "titleBar.border": RED + "40",

    "activityBar.background": MANTLE,
    "activityBar.foreground": RED,
    "activityBar.inactiveForeground": SUB,
    "activityBar.activeBorder": RED,
    "activityBar.border": OV,
    "activityBarBadge.background": RED,
    "activityBarBadge.foreground": BASE,

    "sideBar.background": S0,
    "sideBar.foreground": TEXT,
    "sideBar.border": OV,
    "sideBarTitle.foreground": GOLD,
    "sideBarSectionHeader.background": S1,
    "sideBarSectionHeader.foreground": GOLD,

    "statusBar.background": MANTLE,
    "statusBar.foreground": SUB,
    "statusBar.border": RED + "40",
    "statusBar.noFolderBackground": MANTLE,
    "statusBar.debuggingBackground": RED,
    "statusBar.debuggingForeground": BASE,
    "statusBarItem.remoteBackground": RED,
    "statusBarItem.remoteForeground": BASE,
    "statusBarItem.hoverBackground": RED + "33",

    # editor
    "editor.background": BASE,
    "editor.foreground": TEXT,
    "editorGutter.background": BASE,
    "editorLineNumber.foreground": "#5a4a4a",
    "editorLineNumber.activeForeground": GOLD,
    "editor.lineHighlightBackground": "#ffffff08",
    "editor.selectionBackground": RED + "40",
    "editor.selectionHighlightBackground": RED + "26",
    "editor.wordHighlightBackground": CYAN + "26",
    "editor.findMatchBackground": GOLD + "59",
    "editor.findMatchHighlightBackground": GOLD + "33",
    "editorCursor.foreground": CYAN,
    "editorIndentGuide.background1": "#ffffff0f",
    "editorIndentGuide.activeBackground1": RED + "66",
    "editorBracketMatch.background": CYAN + "26",
    "editorBracketMatch.border": CYAN,
    "editorWhitespace.foreground": "#ffffff12",
    "editorRuler.foreground": OV,

    # tabs
    "editorGroupHeader.tabsBackground": MANTLE,
    "editorGroup.border": OV,
    "tab.activeBackground": BASE,
    "tab.activeForeground": TEXT,
    "tab.activeBorderTop": RED,
    "tab.inactiveBackground": MANTLE,
    "tab.inactiveForeground": SUB,
    "tab.border": OV,
    "tab.hoverBackground": S1,

    # panels
    "panel.background": BASE,
    "panel.border": RED + "40",
    "panelTitle.activeForeground": GOLD,
    "panelTitle.activeBorder": RED,
    "panelTitle.inactiveForeground": SUB,

    # widgets
    "focusBorder": RED + "99",
    "foreground": TEXT,
    "widget.shadow": "#00000080",
    "input.background": S1,
    "input.foreground": TEXT,
    "input.border": OV,
    "inputOption.activeBorder": RED,
    "dropdown.background": S1,
    "dropdown.border": OV,
    "button.background": RED,
    "button.foreground": BASE,
    "button.hoverBackground": REDB,
    "badge.background": RED,
    "badge.foreground": BASE,
    "progressBar.background": RED,

    "list.activeSelectionBackground": RED + "3D",
    "list.activeSelectionForeground": TEXT,
    "list.inactiveSelectionBackground": S2,
    "list.hoverBackground": S1,
    "list.highlightForeground": GOLD,
    "list.focusOutline": RED + "80",

    "scrollbarSlider.background": "#ffffff14",
    "scrollbarSlider.hoverBackground": RED + "40",
    "scrollbarSlider.activeBackground": RED + "66",
    "minimapSlider.background": "#ffffff10",

    "quickInput.background": S0,
    "quickInputTitle.background": S1,
    "menu.background": S0,
    "menu.foreground": TEXT,
    "menu.selectionBackground": RED + "40",
    "menu.border": OV,

    "notificationCenterHeader.background": S1,
    "notifications.background": S0,
    "notifications.border": RED + "40",

    "peekViewEditor.background": S0,
    "peekViewResult.background": MANTLE,
    "peekView.border": RED,

    # git
    "gitDecoration.modifiedResourceForeground": GOLD,
    "gitDecoration.untrackedResourceForeground": GREEN,
    "gitDecoration.deletedResourceForeground": REDB,
    "gitDecoration.conflictingResourceForeground": RED,
    "gitDecoration.ignoredResourceForeground": "#6b5f5d",

    # integrated terminal — the same 16 colours as kitty
    "terminal.background": BASE,
    "terminal.foreground": TEXT,
    "terminalCursor.foreground": CYAN,
    "terminal.selectionBackground": OV,
    "terminal.ansiBlack": "#1f1a1a",
    "terminal.ansiBrightBlack": "#4b3f3f",
    "terminal.ansiRed": RED,
    "terminal.ansiBrightRed": REDB,
    "terminal.ansiGreen": GREEN,
    "terminal.ansiBrightGreen": "#9cf0ae",
    "terminal.ansiYellow": GOLD,
    "terminal.ansiBrightYellow": "#ffc35c",
    "terminal.ansiBlue": CYAN,
    "terminal.ansiBrightBlue": "#86e8ff",
    "terminal.ansiMagenta": "#d05a9e",
    "terminal.ansiBrightMagenta": "#f07ac0",
    "terminal.ansiCyan": "#4fc9d9",
    "terminal.ansiBrightCyan": "#7fe3f0",
    "terminal.ansiWhite": "#d8d2d0",
    "terminal.ansiBrightWhite": "#f5efed",
}

EDITOR_SETTINGS = {
    "editor.fontFamily": "'JetBrainsMono Nerd Font', 'Droid Sans Mono', monospace",
    "editor.fontLigatures": True,
    "editor.fontSize": 13,
    "editor.lineHeight": 1.6,
    "editor.cursorBlinking": "phase",
    "editor.cursorSmoothCaretAnimation": "on",
    "editor.smoothScrolling": True,
    "editor.renderLineHighlight": "all",
    "editor.bracketPairColorization.enabled": True,
    "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font'",
    "terminal.integrated.fontSize": 12,
    "terminal.integrated.smoothScrolling": True,
    "workbench.list.smoothScrolling": True,
    "workbench.tree.indent": 14,
}


def strip_jsonc(text):
    """Remove // and /* */ comments and trailing commas, ignoring strings."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j == -1 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i)
            i = n if j == -1 else j + 2
        else:
            out.append(c)
            i += 1
    s = "".join(out)
    return re.sub(r",(\s*[}\]])", r"\1", s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=sorted(VARIANTS), default="code")
    ap.add_argument("--path", help="explicit path to settings.json")
    ap.add_argument("--revert", action="store_true",
                    help="restore the .pre-arc-reactor backup and exit")
    a = ap.parse_args()

    p = os.path.expanduser(a.path or VARIANTS[a.variant])
    bak = p + ".pre-arc-reactor"

    if a.revert:
        if not os.path.isfile(bak):
            sys.exit(f"no backup at {bak}")
        shutil.move(bak, p)
        print(f"reverted {p}")
        return

    if not os.path.isfile(p):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        cfg = {}
        print(f"note: {p} did not exist — creating it")
    else:
        raw = open(p, encoding="utf-8").read()
        try:
            cfg = json.loads(strip_jsonc(raw)) if raw.strip() else {}
        except json.JSONDecodeError as e:
            sys.exit(f"could not parse {p}: {e}\n"
                     "fix the JSON by hand, then re-run.")
        if not os.path.exists(bak):
            shutil.copy2(p, bak)
            print(f"backup -> {bak}")
        else:
            print(f"backup already exists, left alone -> {bak}")

    existing = cfg.get("workbench.colorCustomizations", {})
    if not isinstance(existing, dict):
        existing = {}
    existing.update(COLORS)
    cfg["workbench.colorCustomizations"] = existing
    cfg.update(EDITOR_SETTINGS)

    with open(p, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=4, ensure_ascii=False)
        f.write("\n")

    json.load(open(p, encoding="utf-8"))  # prove the result is valid JSON
    print(f"merged into {p}")
    print(f"  colour keys : {len(COLORS)}")
    print(f"  total keys  : {len(cfg)}")
    print(f"  syntax theme kept as: {cfg.get('workbench.colorTheme', '(default)')}")


if __name__ == "__main__":
    main()
