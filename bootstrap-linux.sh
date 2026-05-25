#!/bin/bash
# Bootstrap script for setting up Syncthing and dotfiles on Linux devices
# Author: Matthew Beatty
# Usage: bash bootstrap-linux.sh [--yes] [--skip-tools] [--skip-sync-check] [--dotfiles-dir PATH] [--sync-base PATH]

set -euo pipefail

HOMESYNC_DIR="${HOMESYNC_DIR:-$HOME/dev/homesync}"
SYNC_DOTFILES_DIR="${SYNC_DOTFILES_DIR:-$HOMESYNC_DIR/syncthing-dotfiles}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script/default paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"
if [ -d "$HOME/homesync" ]; then
    SYNC_BASE_DEFAULT="$HOME/homesync"
else
    SYNC_BASE_DEFAULT="$HOME/Syncthing"
fi
SYNC_BASE="${SYNC_BASE:-$SYNC_BASE_DEFAULT}"

# Flags
AUTO_YES=0
SKIP_TOOLS=0
SKIP_SYNC_CHECK=0

# Runtime globals
OS=""
DISTRO_ID=""
backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
backup_dir_created=0

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

usage() {
    cat <<EOF
Usage: bash bootstrap-linux.sh [OPTIONS]

Options:
  -y, --yes               Run non-interactively (assume yes for prompts)
      --skip-tools        Skip optional additional CLI tool installation
      --skip-sync-check   Skip required-file sync checks before creating symlinks
      --dotfiles-dir PATH Dotfiles source directory (default: script directory)
      --sync-base PATH    Syncthing root directory (default: \$HOME/homesync or \$HOME/Syncthing)
  -h, --help              Show this help

Environment variable overrides:
  DOTFILES_DIR, SYNC_BASE
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -y|--yes)
                AUTO_YES=1
                ;;
            --skip-tools)
                SKIP_TOOLS=1
                ;;
            --skip-sync-check)
                SKIP_SYNC_CHECK=1
                ;;
            --dotfiles-dir)
                DOTFILES_DIR="${2:-}"
                shift
                ;;
            --sync-base)
                SYNC_BASE="${2:-}"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local reply=""

    if [ "$AUTO_YES" -eq 1 ]; then
        return 0
    fi

    if [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n]: " reply
        [ -z "$reply" ] && reply="y"
    else
        read -r -p "$prompt [y/N]: " reply
        [ -z "$reply" ] && reply="n"
    fi

    [[ "$reply" =~ ^[Yy]$ ]]
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="${NAME:-Unknown Linux}"
        DISTRO_ID="${ID:-unknown}"
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

validate_paths() {
    if [ -z "$DOTFILES_DIR" ] || [ ! -d "$DOTFILES_DIR" ]; then
        print_error "DOTFILES_DIR does not exist: $DOTFILES_DIR"
        exit 1
    fi

    mkdir -p "$SYNC_BASE/dotfiles"
    mkdir -p "$SYNC_BASE/dotfiles"/{shell,git,ssh,vscode,config,tmux}
}

install_syncthing() {
    print_status "Installing Syncthing for $OS..."

    case "$DISTRO_ID" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y curl apt-transport-https gpg

            sudo mkdir -p /usr/share/keyrings
            curl -fsSL https://syncthing.net/release-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg

            echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list >/dev/null

            sudo apt-get update
            sudo apt-get install -y syncthing
            ;;

        fedora|rhel|centos)
            sudo dnf install -y syncthing
            ;;

        arch|manjaro|cachyos)
            sudo pacman -S --needed --noconfirm syncthing
            ;;

        opensuse*|sles)
            sudo zypper install -y syncthing
            ;;

        *)
            print_warning "Unsupported distribution for automatic install."
            print_status "Install Syncthing manually: https://syncthing.net/downloads/"
            return 1
            ;;
    esac

    print_status "Syncthing installed successfully"
}

is_same_link() {
    local source="$1"
    local target="$2"

    [ -L "$target" ] || return 1
    [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]
}

safe_symlink() {
    local source="$1"
    local target="$2"

    if [ ! -e "$source" ]; then
        print_warning "Source missing, skipping: $source"
        return 0
    fi

    if is_same_link "$source" "$target"; then
        print_status "Already linked: $target → $source"
        return 0
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$backup_dir_created" -eq 0 ]; then
            mkdir -p "$backup_dir"
            backup_dir_created=1
        fi

        local backup_target="$backup_dir/$(basename "$target")"
        if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
            backup_target="$backup_target.$(date +%H%M%S)"
        fi

        print_warning "Backing up existing $target to $backup_target"
        mv "$target" "$backup_target"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    print_status "Linked $target → $source"
}

check_required_dotfiles() {
    local missing=0
    local required_files=(
        "shell/.zshrc"
        "shell/.zprofile"
        "git/.gitconfig"
        "ssh/config"
    )

    for relpath in "${required_files[@]}"; do
        if [ ! -f "$DOTFILES_DIR/$relpath" ]; then
            print_warning "Missing expected file: $DOTFILES_DIR/$relpath"
            missing=1
        fi
    done

    return "$missing"
}

create_symlinks() {
    print_status "Creating symlinks from dotfiles source: $DOTFILES_DIR"

    mkdir -p "$HOME/.config/zsh"

    # Minimal .zshenv in HOME to point to XDG config
    safe_symlink "$DOTFILES_DIR/shell/.zshenv" "$HOME/.zshenv"

    # Actual zsh configurations in XDG location
    safe_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.config/zsh/.zshrc"
    safe_symlink "$DOTFILES_DIR/shell/.zprofile" "$HOME/.config/zsh/.zprofile"

    [ -f "$DOTFILES_DIR/shell/.bashrc" ] && safe_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
    [ -f "$DOTFILES_DIR/shell/.bash_profile" ] && safe_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
    [ -f "$DOTFILES_DIR/tmux/.tmux.conf" ] && safe_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

    safe_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    safe_symlink "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
    [ -L "$HOME/.ssh/config" ] || [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config"

    local vscode_targets=(
        "$HOME/.config/Code/User"
        "$HOME/.config/Code - OSS/User"
        "$HOME/.vscode-oss/User"
    )
    local vscode_linked=0
    for target_dir in "${vscode_targets[@]}"; do
        if [ -d "$target_dir" ] || [ -d "$(dirname "$target_dir")" ]; then
            mkdir -p "$target_dir"
            [ -f "$DOTFILES_DIR/vscode/settings.json" ] && safe_symlink "$DOTFILES_DIR/vscode/settings.json" "$target_dir/settings.json"
            [ -f "$DOTFILES_DIR/vscode/keybindings.json" ] && safe_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$target_dir/keybindings.json"
            vscode_linked=1
        fi
    done
    [ "$vscode_linked" -eq 0 ] && print_warning "No VS Code user settings directory found; skipping VS Code symlinks."

    if [ "$backup_dir_created" -eq 1 ]; then
        print_status "Backups saved in: $backup_dir"
    fi
    print_status "Symlinks processed"
}

setup_syncthing_service() {
    print_status "Setting up Syncthing user service..."

    if ! command -v systemctl >/dev/null 2>&1; then
        print_warning "systemctl not available; skipping service setup."
        return 0
    fi

    systemctl --user enable --now syncthing.service
    print_status "Syncthing user service is enabled and running"
    print_status "Web UI: http://localhost:8384"
}

install_additional_tools() {
    print_status "Installing additional CLI tools..."

    case "$DISTRO_ID" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y git curl wget htop tmux build-essential

            command -v eza >/dev/null 2>&1 || {
                print_status "Installing eza..."
                sudo apt-get install -y gpg
                sudo mkdir -p /usr/share/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /usr/share/keyrings/eza-community.gpg
                echo "deb [signed-by=/usr/share/keyrings/eza-community.gpg] http://deb.eza.community stable main" | sudo tee /etc/apt/sources.list.d/eza-community.list >/dev/null
                sudo apt-get update
                sudo apt-get install -y eza
            }
            command -v bat >/dev/null 2>&1 || sudo apt-get install -y bat
            command -v rg >/dev/null 2>&1 || sudo apt-get install -y ripgrep
            command -v fd >/dev/null 2>&1 || sudo apt-get install -y fd-find
            command -v fzf >/dev/null 2>&1 || sudo apt-get install -y fzf
            command -v zoxide >/dev/null 2>&1 || {
                print_status "Installing zoxide..."
                curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
            }
            ;;

        fedora|rhel|centos)
            sudo dnf install -y git curl wget htop tmux gcc make
            command -v eza >/dev/null 2>&1 || sudo dnf install -y eza
            command -v bat >/dev/null 2>&1 || sudo dnf install -y bat
            command -v rg >/dev/null 2>&1 || sudo dnf install -y ripgrep
            command -v fd >/dev/null 2>&1 || sudo dnf install -y fd-find
            command -v fzf >/dev/null 2>&1 || sudo dnf install -y fzf
            command -v zoxide >/dev/null 2>&1 || sudo dnf install -y zoxide
            ;;

        arch|manjaro|cachyos)
            sudo pacman -S --needed --noconfirm \
                git \
                curl \
                wget \
                htop \
                tmux \
                base-devel \
                eza \
                bat \
                ripgrep \
                fd \
                fzf \
                zoxide
            ;;

        *)
            print_warning "Skipping additional tools: unsupported distro ID '$DISTRO_ID'"
            ;;
    esac

    print_status "Additional tools step complete"
}

main() {
    parse_args "$@"

    print_status "Starting Syncthing dotfiles bootstrap for Linux"
    detect_distro
    validate_paths

    print_status "Detected: $OS ($DISTRO_ID)"
    print_status "Dotfiles source: $DOTFILES_DIR"
    print_status "Sync base: $SYNC_BASE"
    echo ""

    if command -v syncthing >/dev/null 2>&1; then
        print_status "Syncthing already installed"
    else
        install_syncthing
    fi
    echo ""

    if [ "$SKIP_SYNC_CHECK" -eq 0 ]; then
        print_warning "Before symlinking, ensure this device has finished initial Syncthing folder sync."
        if ! check_required_dotfiles; then
            if ! prompt_yes_no "Required files are missing. Continue anyway?"; then
                print_warning "Exiting. Re-run after sync completes."
                exit 0
            fi
        fi
    fi

    if prompt_yes_no "Create/update dotfile symlinks now?" "y"; then
        create_symlinks
    else
        print_warning "Skipped symlink creation by request."
    fi
    echo ""

    setup_syncthing_service
    echo ""

    if [ "$SKIP_TOOLS" -eq 1 ]; then
        print_status "Skipping optional tool installation (--skip-tools)."
    else
        if prompt_yes_no "Install additional CLI tools (eza, bat, ripgrep, etc.)?"; then
            install_additional_tools
        fi
    fi
    echo ""

    print_status "Bootstrap complete"
    print_status "Reload shell config if needed: source ~/.zshrc (or open a new terminal)"
}

main "$@"
