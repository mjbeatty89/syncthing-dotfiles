# Syncthing Dotfiles Configuration
## Author: Matthew Beatty

This directory contains synchronized dotfiles managed through Syncthing for consistent configuration across Mac and Linux devices.

## Directory Structure

```
~/Syncthing/dotfiles/
├── shell/          # Shell configurations (zsh/bash)
├── git/            # Git configuration
├── ssh/            # SSH config (no private keys!)
├── vscode/         # VS Code settings
├── config/         # Other app configs
└── bootstrap-linux.sh  # Setup script for new Linux devices
```

## Synced Files

- **Shell**: `.zshrc`, `.zprofile` 
- **Git**: `.gitconfig`
- **SSH**: `config` (client configuration only)
- **VS Code**: `settings.json`

## Setting Up a New Linux Device

1. **Install Syncthing** (if not already installed)
2. **Run the bootstrap script**:
   ```bash
   curl -O [syncthing-device-url]/bootstrap-linux.sh
   bash bootstrap-linux.sh
   ```
3. **Configure Syncthing**:
   - Access web UI at `http://localhost:8384`
   - Add device using ID from your Mac
   - Accept the 'dotfiles' folder share
   - Wait for initial sync

## Setting Up on Mac

Already configured! The symlinks are:
- `~/.zshrc` → `~/Syncthing/dotfiles/shell/.zshrc`
- `~/.zprofile` → `~/Syncthing/dotfiles/shell/.zprofile`
- `~/.gitconfig` → `~/Syncthing/dotfiles/git/.gitconfig`
- `~/Library/Application Support/Code/User/settings.json` → `~/Syncthing/dotfiles/vscode/settings.json`

## Security Notes

⚠️ **NEVER sync**:
- Private SSH keys (`id_rsa`, `id_ed25519`, etc.)
- GPG private keys
- API tokens or secrets
- Password files

These are excluded via `.stignore` file.

## Making Changes

Any changes to dotfiles will automatically sync across all connected devices. No manual commits needed!

## Useful Commands

```bash
# Check Syncthing status
syncthing --version

# View Syncthing web UI
open http://localhost:8384  # Mac
xdg-open http://localhost:8384  # Linux

# Reload shell configuration
source ~/.zshrc

# Check symlinks
ls -la ~/.zshrc ~/.gitconfig
```

## Troubleshooting

1. **Syncthing not running**: Start with `syncthing` or enable service
2. **Files not syncing**: Check web UI for sync conflicts
3. **Permission issues**: Ensure proper permissions on `.ssh/config` (600)
4. **Shell errors**: Check syntax with `zsh -n ~/.zshrc`

## Additional Files to Consider Syncing

You might want to add:
- `.tmux.conf` - Terminal multiplexer config
- `.config/htop/` - System monitor config  
- `.config/starship.toml` - Shell prompt theme
- `.aliases` - Custom command aliases
- `.functions` - Custom shell functions

Simply copy them to the appropriate folder in `~/Syncthing/dotfiles/` and create symlinks.