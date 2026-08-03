# >>> arc-reactor >>>
# Arc Reactor shell integration. Delete this whole block to revert,
# or run ~/.arc-reactor/restore.sh which restores the original .bashrc.

# --- prompt ------------------------------------------------------------------
command -v starship >/dev/null && eval "$(starship init bash)"

# --- smarter cd --------------------------------------------------------------
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"

# --- fuzzy finder, themed to the Arc Reactor palette -------------------------
if command -v fzf >/dev/null; then
  eval "$(fzf --bash)" 2>/dev/null
  export FZF_DEFAULT_OPTS="--height 45% --layout=reverse --border=rounded \
--color=bg+:#241d1d,spinner:#55d9f0,hl:#e62429,fg:#d8d2d0 \
--color=header:#e62429,info:#f0a020,pointer:#55d9f0,marker:#7bd88f \
--color=fg+:#ece6e4,prompt:#e62429,hl+:#ff4d52,border:#3a2c2e"
fi

# --- ls / cat replacements ---------------------------------------------------
if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l  --icons --group-directories-first --git --time-style=long-iso'
  alias la='eza -la --icons --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons'
fi
if command -v bat >/dev/null; then
  # bat passes through unstyled when stdout is not a tty, so this is pipe-safe
  alias cat='bat --paging=never'
  export BAT_THEME="base16"          # uses the terminal's 16 ANSI colours
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
alias reactor='fastfetch'

# --- system readout on a new kitty window ------------------------------------
if [[ $- == *i* ]] && [[ "${TERM:-}" == xterm-kitty ]] && command -v fastfetch >/dev/null; then
  fastfetch
fi
# <<< arc-reactor <<<
