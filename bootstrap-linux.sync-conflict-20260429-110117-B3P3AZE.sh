#!/bin/bash
# Bootstrap script for setting up Syncthing and dotfiles on Linux devices
# Author: Matthew Beatty
# Usage: bash bootstrap-linux.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        ID=$ID
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

# Install Syncthing based on distribution
install_syncthing() {
    print_status "Installing Syncthing for $OS..."
    
    case $ID in
        ubuntu|debian)
            # Add Syncthing repository
            sudo apt-get update
            sudo apt-get install -y curl apt-transport-https
            
            # Add Syncthing release key
            sudo mkdir -p /usr/share/keyrings
            curl -L https://syncthing.net/release-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
            
            # Add repository
            echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list
            
            # Install
            sudo apt-get update
            sudo apt-get install -y syncthing
            ;;
            
        fedora|rhel|centos)
            sudo dnf install -y syncthing
            ;;
            
        arch|manjaro)
            sudo pacman -S --noconfirm syncthing
            ;;
            
        opensuse*)
            sudo zypper install -y syncthing
            ;;
            
        *)
            print_warning "Unsupported distribution. Please install Syncthing manually."
            print_status "Visit: https://syncthing.net/downloads/"
            return 1
            ;;
    esac
    
    print_status "Syncthing installed successfully"
}

# Create Syncthing directories
setup_directories() {
    print_status "Creating Syncthing directory structure..."
    mkdir -p ~/Syncthing/dotfiles/{shell,git,ssh,vscode,config}
    print_status "Directory structure created"
}

# Create symlinks for dotfiles
create_symlinks() {
    print_status "Creating symlinks for dotfiles..."
    
    # Backup existing files if they exist and aren't already symlinks
    backup_dir=~/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)
    mkdir -p "$backup_dir"
    
    # Function to safely create symlink
    safe_symlink() {
        local source=$1
        local target=$2
        
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            print_warning "Backing up existing $target to $backup_dir"
            cp -a "$target" "$backup_dir/" 2>/dev/null || true
        fi
        
        # Remove existing file/symlink
        rm -f "$target"
        
        # Create new symlink
        ln -s "$source" "$target"
        print_status "Linked $target → $source"
    }
    
    # Shell configurations
    safe_symlink ~/Syncthing/dotfiles/shell/.zshrc ~/.zshrc
    safe_symlink ~/Syncthing/dotfiles/shell/.zprofile ~/.zprofile
    
    # If using bash instead of zsh
    if [ -f ~/Syncthing/dotfiles/shell/.bashrc ]; then
        safe_symlink ~/Syncthing/dotfiles/shell/.bashrc ~/.bashrc
    fi
    if [ -f ~/Syncthing/dotfiles/shell/.bash_profile ]; then
        safe_symlink ~/Syncthing/dotfiles/shell/.bash_profile ~/.bash_profile
    fi
    
    # Git configuration
    safe_symlink ~/Syncthing/dotfiles/git/.gitconfig ~/.gitconfig
    
    # SSH config (NOT keys!)
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    safe_symlink ~/Syncthing/dotfiles/ssh/config ~/.ssh/config
    chmod 600 ~/.ssh/config
    
    # VS Code settings (Linux path)
    if [ -d ~/.config/Code ]; then
        mkdir -p ~/.config/Code/User
        safe_symlink ~/Syncthing/dotfiles/vscode/settings.json ~/.config/Code/User/settings.json
        
        if [ -f ~/Syncthing/dotfiles/vscode/keybindings.json ]; then
            safe_symlink ~/Syncthing/dotfiles/vscode/keybindings.json ~/.config/Code/User/keybindings.json
        fi
    fi
    
    print_status "Symlinks created successfully"
}

# Setup Syncthing as a user service
setup_syncthing_service() {
    print_status "Setting up Syncthing as a user service..."
    
    # Enable and start Syncthing for current user
    systemctl --user enable syncthing.service
    systemctl --user start syncthing.service
    
    print_status "Syncthing service is running"
    print_status "Web UI will be available at: http://localhost:8384"
}

# Install additional tools mentioned in .zshrc
install_additional_tools() {
    print_status "Installing additional tools for enhanced shell experience..."
    
    case $ID in
        ubuntu|debian)
            # Core tools
            sudo apt-get install -y \
                git \
                curl \
                wget \
                htop \
                tmux \
                build-essential
            
            # Modern CLI replacements if available
            which eza &>/dev/null || {
                print_status "Installing eza (modern ls)..."
                sudo apt-get install -y gpg
                sudo mkdir -p /usr/share/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /usr/share/keyrings/eza-community.gpg
                echo "deb [signed-by=/usr/share/keyrings/eza-community.gpg] http://deb.eza.community stable main" | sudo tee /etc/apt/sources.list.d/eza-community.list
                sudo apt-get update
                sudo apt-get install -y eza
            }
            
            which bat &>/dev/null || sudo apt-get install -y bat
            which rg &>/dev/null || sudo apt-get install -y ripgrep
            which fd &>/dev/null || sudo apt-get install -y fd-find
            which fzf &>/dev/null || sudo apt-get install -y fzf
            which zoxide &>/dev/null || {
                print_status "Installing zoxide..."
                curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
            }
            ;;
            
        fedora|rhel|centos)
            sudo dnf install -y \
                git \
                curl \
                wget \
                htop \
                tmux \
                gcc \
                make
                
            # Modern tools
            which eza &>/dev/null || sudo dnf install -y eza
            which bat &>/dev/null || sudo dnf install -y bat
            which rg &>/dev/null || sudo dnf install -y ripgrep
            which fd &>/dev/null || sudo dnf install -y fd-find
            which fzf &>/dev/null || sudo dnf install -y fzf
            ;;
            
        arch|manjaro)
            sudo pacman -S --noconfirm \
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
    esac
    
    print_status "Additional tools installed"
}

# Main installation flow
main() {
    print_status "Starting Syncthing dotfiles bootstrap for Linux"
    echo ""
    
    # Detect distribution
    detect_distro
    print_status "Detected: $OS ($ID)"
    echo ""
    
    # Check if Syncthing is already installed
    if command -v syncthing &>/dev/null; then
        print_warning "Syncthing is already installed"
    else
        install_syncthing
    fi
    echo ""
    
    # Setup directories
    setup_directories
    echo ""
    
    # Note about syncing
    print_warning "IMPORTANT: Before creating symlinks, you need to:"
    print_warning "1. Start Syncthing and access the web UI at http://localhost:8384"
    print_warning "2. Add this device to your Syncthing network from your Mac"
    print_warning "3. Accept the 'dotfiles' folder share from your Mac"
    print_warning "4. Wait for initial sync to complete"
    echo ""
    
    read -p "Have you completed the Syncthing setup and initial sync? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create symlinks
        create_symlinks
        echo ""
        
        # Setup service
        setup_syncthing_service
        echo ""
        
        # Optional: Install additional tools
        read -p "Do you want to install additional CLI tools (eza, bat, ripgrep, etc.)? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_additional_tools
        fi
        
        print_status "Bootstrap complete!"
        print_status "Your dotfiles are now synced via Syncthing"
        print_status "Any changes will automatically sync across devices"
        echo ""
        print_warning "Remember to reload your shell configuration:"
        print_warning "  source ~/.zshrc  (for zsh)"
        print_warning "  source ~/.bashrc (for bash)"
    else
        print_warning "Please complete Syncthing setup first, then run this script again"
        print_warning "You can manually start Syncthing with: syncthing"
        exit 0
    fi
}

# Run main function
main "$@"