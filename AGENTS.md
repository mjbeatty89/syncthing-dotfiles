#brew install --cask bluebubbles AGENTSs.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Architecture and Structure

This repository manages dotfiles synchronized via Syncthing across macOS and Linux devices.

- **Root Directory**: Contains the bootstrap script and config directories.
- **`shell/`**: Contains shell configuration files (`.zshrc`, `.zprofile`).
- **`git/`**: Contains Git configuration (`.gitconfig`).
- **`ssh/`**: Contains SSH client configuration (`config`). **Note**: Private keys are strictly excluded via `.stignore` and `.gitignore`.
- **`vscode/`**: Contains VS Code settings (`settings.json`).
- **`bootstrap-linux.sh`**: The automated setup script for new Linux environments. It installs dependencies (Syncthing, tools) and creates symlinks.

## Development Tasks

### Validating Shell Configuration
Before committing changes to shell scripts, verify syntax:
```bash
zsh -n shell/.zshrc
zsh -n shell/.zprofile
bash -n bootstrap-linux.sh
```

### Setting up a New Linux Device
To verify the bootstrap process (dry run or actual):
```bash
# Check script executable
test -x bootstrap-linux.sh

# Run bootstrap script (interactive)
./bootstrap-linux.sh
```

### Adding New Dotfiles
1. Place the configuration file in the appropriate subdirectory (e.g., `config/app/`).
2. Update `bootstrap-linux.sh` to include the symlink creation logic in the `create_symlinks` function.
3. If the file contains secrets, ensure it is added to `.stignore` and `.gitignore`.

### Syncthing Exclusion
The `.stignore` file controls which files Syncthing does *not* synchronize. Always check this file when adding new types of configuration to ensure secrets or large binaries are not synced.
