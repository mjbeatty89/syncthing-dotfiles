# ============================================================================
# ZSH Configuration - Multi-OS Support
# Matthew Beatty - mjbeatty89@gmail.com
# ============================================================================
# XDG base directory variables (XDG_CONFIG_HOME, XDG_DATA_HOME, etc.)
# are declared in .zshenv, which is sourced before this file.
# ============================================================================

# ============================================================================
# OS Detection
# ============================================================================
case "$(uname -s)" in
    Darwin*)
        export OS_TYPE="mac"
        ;;
    Linux*)
        export OS_TYPE="linux"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        export OS_TYPE="windows"
        ;;
    *)
        export OS_TYPE="unknown"
        ;;
esac

# ============================================================================
# PATH Configuration
# ============================================================================
# Use zsh's path array for reliable ordering and automatic deduplication
typeset -U path

path_prepend() { [[ -d "$1" ]] && path=("$1" $path); }
path_append() { [[ -d "$1" ]] && path+=("$1"); }

# User-local bins first
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.bun/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.antigravity/antigravity/bin"
path_prepend "$HOME/.atuin/bin"
path_prepend "/opt/homebrew/bin"
path_prepend "/opt/homebrew/sbin"

# Package-manager / tool bins
if [ "$OS_TYPE" = "mac" ]; then
    path_prepend "$HOME/Library/pnpm"
else
    path_prepend "$XDG_DATA_HOME/pnpm"
fi
path_append "$HOME/.docker/bin"
path_append "$HOME/.lmstudio/bin"
path_append "/Volumes/mm2ssd/mjb/.lmstudio/bin"
path_append "/Applications/Obsidian.app/Contents/MacOS"
path_append "$HOME/mlx-env/bin"  # MLX local AI

export PATH

# ============================================================================
# XDG-Aware Tool Configuration
# ============================================================================
# XDG vars are declared in .zshenv. Here we redirect individual tools
# so they stop scattering files across $HOME.

# Zsh history → XDG state (persistent runtime state, not config)
mkdir -p "$XDG_STATE_HOME/zsh"

# Less — move .lesshst out of home
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
mkdir -p "$XDG_STATE_HOME/less"

# SQLite — move .sqlite_history out of home
export SQLITE_HISTORY="$XDG_STATE_HOME/sqlite/history"
mkdir -p "$XDG_STATE_HOME/sqlite"

# npm — cache to XDG_CACHE, config to XDG_CONFIG
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
mkdir -p "$XDG_CACHE_HOME/npm" "$XDG_CONFIG_HOME/npm"

# wget — keep .wget-hsts out of home
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
mkdir -p "$XDG_CONFIG_HOME/wget"
[[ ! -f "$WGETRC" ]] && echo "hsts-file = $XDG_CACHE_HOME/wget-hsts" > "$WGETRC"

# Python — history and startup config
# PYTHON_HISTORY requires Python 3.13+; PYTHONSTARTUP works on all versions
export PYTHONDONTWRITEBYTECODE=1
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonstartup.py"
mkdir -p "$XDG_STATE_HOME/python" "$XDG_CONFIG_HOME/python"

# Ansible — your homelab playbooks will pick this up automatically
export ANSIBLE_HOME="$XDG_CONFIG_HOME/ansible"
export ANSIBLE_CONFIG="$XDG_CONFIG_HOME/ansible/ansible.cfg"
export ANSIBLE_GALAXY_CACHE_DIR="$XDG_CACHE_HOME/ansible/galaxy"

# Zoxide — jump database lives in XDG data
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"
mkdir -p "$_ZO_DATA_DIR"

# ============================================================================
# API Keys and Secrets
# ============================================================================
# 1Password Environments (Local .env)
# We avoid exporting secrets at login. Instead, 1Password Desktop mounts a local
# .env at $HOME/.env.ai. Use the 'withai' helper to run commands with those vars.

# Path to the 1Password Environments mounted .env file
export OP_ENV_AI="$HOME/.env.ai"

# Helper to scope variables from the mounted .env to a single command
if command -v dotenvx &> /dev/null; then
    alias withai='dotenvx run -f "$OP_ENV_AI" --'
else
    withai() {
        echo "Install dotenvx first: https://github.com/dotenvx/dotenvx#installation" >&2
        return 1
    }
fi

# Convenience aliases for common tools using the mounted env
alias ai-openai='withai openai'
alias ai-gh='withai gh'
alias ai-bash='withai bash'
alias ai-curl='withai curl'

# ============================================================================
# History Configuration
# ============================================================================
HISTFILE="$XDG_STATE_HOME/zsh/history"   # XDG state (dir created above)
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY          # Write timestamp to history file
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first
setopt HIST_IGNORE_DUPS          # Don't record duplicates
setopt HIST_IGNORE_SPACE         # Don't record entries starting with space
setopt HIST_VERIFY               # Don't execute immediately upon history expansion
setopt SHARE_HISTORY             # Share history between all sessions

# ============================================================================
# Directory Navigation
# ============================================================================
setopt AUTO_CD                   # cd by typing directory name if it's not a command
setopt AUTO_PUSHD                # Make cd push old directory onto directory stack
setopt PUSHD_IGNORE_DUPS         # Don't push multiple copies of same directory
setopt PUSHD_SILENT              # Don't print directory stack after pushd/popd

# ============================================================================
# Completion System
# ============================================================================
# Docker and other tools add their completions to fpath — do this BEFORE compinit
fpath=($HOME/.docker/completions $fpath)

autoload -Uz compinit

# Store the completion dump in XDG cache (versioned so stale dumps auto-refresh)
mkdir -p "$XDG_CACHE_HOME/zsh"
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Enable menu selection
zstyle ':completion:*' menu select

# Better completion for kill command
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

# Complete . and .. directories
zstyle ':completion:*' special-dirs true

# Group results by category
zstyle ':completion:*' group-name ''

# Enable approximate matches for completion
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# ============================================================================
# ZSH Autocomplete (oh-my-zsh)
# ============================================================================
# oh-my-zsh is installed at $HOME/.oh-my-zsh by its installer.
# To move it to XDG ($XDG_DATA_HOME/oh-my-zsh), reinstall with:
#   ZSH="$XDG_DATA_HOME/oh-my-zsh" sh -c "$(curl -fsSL https://install.ohmyz.sh)"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=()

source $ZSH/oh-my-zsh.sh

# Load zsh-autocomplete from OS-specific location
if [ "$OS_TYPE" = "mac" ] && [ -f "/opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]; then
    source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
elif [ "$OS_TYPE" = "linux" ]; then
    # Try common Linux locations
    if [ -f "/usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]; then
        source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
    elif [ -f "$XDG_DATA_HOME/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]; then
        source "$XDG_DATA_HOME/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
    elif [ -f "$HOME/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]; then
        source $HOME/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh
    fi
fi

# Configure zsh-autocomplete
zstyle ':autocomplete:*' min-input 2
zstyle ':autocomplete:*' min-delay 0.05  # seconds (float)

# ============================================================================
# Colors
# ============================================================================
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
# Enable colored output for grep (without deprecated GREP_OPTIONS)
if ! command -v rg &> /dev/null; then
    alias grep='grep --color=auto'
fi
export GREP_COLOR='1;32'

# ============================================================================
# Modern CLI Tool Replacements
# ============================================================================

# eza (modern replacement for ls with colors and icons)
if command -v eza &> /dev/null; then
    alias ls='eza --color=always --group-directories-first --icons'
    alias ll='eza -la --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias lt='eza -aT --color=always --group-directories-first --icons'
    alias l.='eza -a | grep "^\."'
fi

# bat (modern replacement for cat with syntax highlighting)
if command -v bat &> /dev/null; then
    alias cat='bat --style=auto'
    alias bathelp='bat --help'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ripgrep (modern replacement for grep)
if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# fd (modern replacement for find)
if command -v fd &> /dev/null; then
    alias find='fd'
fi

# ============================================================================
# FZF - Fuzzy Finder
# ============================================================================
if command -v fzf &> /dev/null; then
    # Set up fzf key bindings and fuzzy completion
    source <(fzf --zsh)

    # Use fd for fzf if available
    if command -v fd &> /dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi

    # Color scheme for fzf
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --inline-info \
        --color=fg:#d0d0d0,bg:#121212,hl:#5f87af \
        --color=fg+:#ffffff,bg+:#262626,hl+:#5fd7ff \
        --color=info:#afaf87,prompt:#d7005f,pointer:#af5fff \
        --color=marker:#87ff00,spinner:#af5fff,header:#87afaf"
fi

# ============================================================================
# Zoxide - Smarter cd
# ============================================================================
# _ZO_DATA_DIR is set above in the XDG section.
# '--cmd cd' replaces the built-in cd with zoxide's smarter version.
# You still get 'z' and 'zi' as shorthand aliases.
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# ============================================================================
# TheFuck - Correct Previous Command
# ============================================================================
if command -v thefuck &> /dev/null; then
    eval "$(thefuck --alias)"
    eval "$(thefuck --alias fk)"  # Shorter alias
fi

# ============================================================================
# Git Configuration
# ============================================================================

# Git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate --all'

# ============================================================================
# Development Aliases
# ============================================================================

# Python
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# Make
alias m='make'

# VSCode (OS-specific)
if [ "$OS_TYPE" = "mac" ]; then
    alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'
elif [ "$OS_TYPE" = "linux" ]; then
    # Linux — usually already in PATH
    command -v code &>/dev/null || alias code='code'
fi

# Quick directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ============================================================================
# Networking & System
# ============================================================================

# Network
alias myip='curl ifconfig.me'

# Local IP (OS-specific)
if [ "$OS_TYPE" = "mac" ]; then
    alias localip='ipconfig getifaddr en0'
elif [ "$OS_TYPE" = "linux" ]; then
    alias localip="hostname -I | awk '{print \$1}'"
fi

alias ports='lsof -i -P | grep LISTEN'

# SSH Shortcuts
alias ssh-config='${EDITOR:-nano} ~/.ssh/config'
if [ -x "$HOME/.ssh/check-hosts.sh" ]; then
    alias ssh-check="$HOME/.ssh/check-hosts.sh"
elif [ -x "$HOME/dev/homesync/ssh-config/check-hosts.sh" ]; then
    alias ssh-check="$HOME/dev/homesync/ssh-config/check-hosts.sh"
fi

if [ -d "$HOME/dev/homesync/ssh-config/.git" ]; then
    alias ssh-backup="cd $HOME/dev/homesync/ssh-config && git --no-pager status && git --no-pager log --oneline -5"
else
    alias ssh-backup='cd ~/.ssh && git --no-pager status && git --no-pager log --oneline -5'
fi

if [ -x "$HOME/.ssh/bootstrap-rpi.sh" ]; then
    alias rpi-bootstrap="$HOME/.ssh/bootstrap-rpi.sh"
elif [ -x "$HOME/dev/homesync/ssh-config/bootstrap-rpi.sh" ]; then
    alias rpi-bootstrap="$HOME/dev/homesync/ssh-config/bootstrap-rpi.sh"
fi

# Quick SSH to em0lab hosts
alias sha='ssh ha'
alias sfr='ssh frigate'
alias swin='ssh winserv'
alias sub='ssh ubuntu'

# System monitoring (OS-specific)
if [ "$OS_TYPE" = "mac" ]; then
    alias cpu='top -o cpu'
    alias mem='top -o mem'
elif [ "$OS_TYPE" = "linux" ]; then
    alias cpu='top -o %CPU'
    alias mem='top -o %MEM'
fi

# ============================================================================
# Package Manager Aliases
# ============================================================================

if [ "$OS_TYPE" = "mac" ]; then
    # Homebrew
    alias brewup='brew update && brew upgrade && brew cleanup'
    alias brewclean='brew cleanup && brew autoremove'
elif [ "$OS_TYPE" = "linux" ]; then
    # APT (Debian/Ubuntu)
    if command -v apt &>/dev/null; then
        alias aptup='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
        alias aptclean='sudo apt autoremove -y && sudo apt autoclean'
    fi
    # DNF (Fedora/RHEL)
    if command -v dnf &>/dev/null; then
        alias dnfup='sudo dnf update -y && sudo dnf autoremove -y'
    fi
    # Pacman (Arch / CachyOS)
    if command -v pacman &>/dev/null; then
        alias pacup='sudo pacman -Syu'
        alias pacclean='sudo pacman -Sc'
    fi
fi

# ============================================================================
# QMK Keyboard Development
# ============================================================================
# qmk stores its firmware clone in XDG data
export QMK_HOME="$XDG_DATA_HOME/qmk_firmware"

# ============================================================================
# Package Managers (pnpm, bun)
# ============================================================================

# pnpm — macOS uses ~/Library per Apple convention; Linux uses XDG data
if [ "$OS_TYPE" = "mac" ]; then
    export PNPM_HOME="$HOME/Library/pnpm"
else
    export PNPM_HOME="$XDG_DATA_HOME/pnpm"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ============================================================================
# Custom Functions
# ============================================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$@" && cd "$_"
}

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"    ;;
            *.tar.gz)    tar xzf "$1"    ;;
            *.bz2)       bunzip2 "$1"    ;;
            *.rar)       unrar e "$1"    ;;
            *.gz)        gunzip "$1"     ;;
            *.tar)       tar xf "$1"     ;;
            *.tbz2)      tar xjf "$1"    ;;
            *.tgz)       tar xzf "$1"    ;;
            *.zip)       unzip "$1"      ;;
            *.Z)         uncompress "$1" ;;
            *.7z)        7z x "$1"       ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick find (note: 'fd' alias above overrides the fd() function — rename to fdir)
ff() { find . -type f -name "*$1*"; }
fdir() { find . -type d -name "*$1*"; }

# Git commit with message
gcm() {
    git commit -m "$*"
}

# Create and checkout new git branch
gcb() {
    git checkout -b "$*"
}

# Search through command history
h() {
    history | grep "$@"
}

# ============================================================================
# Starship Prompt
# ============================================================================
# Starship reads $XDG_CONFIG_HOME/starship.toml automatically — no extra var needed.
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# ============================================================================
# Machine-Specific Configuration
# ============================================================================
# Load machine-specific config if it exists.
# Looks in the dotfiles repo first, then falls back to a local-only path.
CURRENT_HOST=$(hostname -s)
MACHINE_CONFIG="$HOME/dotfiles/zsh/machines/${CURRENT_HOST}.zsh"
if [ -f "$MACHINE_CONFIG" ]; then
    source "$MACHINE_CONFIG"
fi

# ============================================================================
# 1Password CLI Plugin (Mac)
# ============================================================================
if [ "$OS_TYPE" = "mac" ] && [ -f "$XDG_CONFIG_HOME/op/plugins.sh" ]; then
    source "$XDG_CONFIG_HOME/op/plugins.sh"
fi

# ============================================================================
# Other Tool Integrations
# ============================================================================

# broot — file navigator
[ -f "$XDG_CONFIG_HOME/broot/launcher/bash/br" ] && source "$XDG_CONFIG_HOME/broot/launcher/bash/br"

# langflow / uv
[ -f "$HOME/.langflow/uv/env" ] && . "$HOME/.langflow/uv/env"

# ============================================================================
# Dotfiles Auto-Update Function
# ============================================================================
dotfiles-update() {
    echo "📦 Updating dotfiles..."
    cd "$HOME/dotfiles" || return 1
    git add -A
    git commit -m "Update dotfiles from $(hostname -s) - $(date '+%Y-%m-%d %H:%M:%S')"
    git push
    echo "✅ Dotfiles updated and pushed to GitHub!"
    cd - > /dev/null
}

# ============================================================================
# Shell Plugins (autosuggestions, syntax highlighting)
# ============================================================================
# Load after everything else so highlighting covers all aliases
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ============================================================================
# Welcome Message
# ============================================================================
if command -v fastfetch &> /dev/null; then
    fastfetch
elif command -v neofetch &> /dev/null; then
    neofetch
fi

if [ "$OS_TYPE" = "mac" ]; then
    echo "🍎 macOS ($(hostname -s)) - Zsh ready."
elif [ "$OS_TYPE" = "linux" ]; then
    echo "🐧 Linux ($(hostname -s)) - Zsh ready."
else
    echo "💻 $(hostname -s) - Zsh ready."
fi

# claude-mem alias (1Password / bun script)
alias claude-mem='/Volumes/mm2ssd/mjb/.bun/bin/bun "/Volumes/mm2ssd/mjb/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Volumes/mm2ssd/mjb/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# opencode
export PATH=/Volumes/mm2ssd/mjb/.opencode/bin:$PATH

[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

