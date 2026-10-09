# Syncthing Dotfiles Repository

This repository stores shared dotfiles and bootstraps Linux devices using symlinks plus Syncthing-backed synchronization.

## What this repo manages

- Zsh config (`shell/.zshenv`, `shell/.zshrc`, `shell/.zprofile`)
- ZDOTDIR-scoped zsh env (`shell/zdotdir/.zshenv`)
- Git config (`git/.gitconfig`)
- SSH client config (`ssh/config`, never private keys)
- VS Code settings (`vscode/settings.json`)
- Tmux config (`tmux/.tmux.conf`, if present)

## Repository layout

```text
dotfiles/
├── bootstrap-linux.sh
├── shell/          # shell config, plus shell/zdotdir/.zshenv
├── git/
├── ssh/
├── vscode/
├── tmux/
└── config/
```

## Prerequisites

- Linux system with `bash`, `systemd --user`, and `sudo` access
- Syncthing account/device pairing ready (or allow script to install Syncthing)
- This repository cloned locally

## Bootstrap script overview

`bootstrap-linux.sh` can:

- install Syncthing (if missing),
- initialize sync directory structure,
- seed missing files into the sync dotfiles directory,
- create/update home-directory symlinks with safe backups,
- enable/start `syncthing.service` in user mode,
- optionally install common CLI tools.

## Recommended setup workflow

1. Clone repo:
   ```bash
   git clone https://github.com/mjbeatty89/syncthing-dotfiles.git ~/homesync/dotfiles
   cd ~/homesync/dotfiles
   ```
2. Run a dry-run first:
   ```bash
   ./bootstrap-linux.sh --dry-run --yes --skip-tools
   ```
3. Run production setup:
   ```bash
   ./bootstrap-linux.sh --yes
   ```
4. Reload shell:
   ```bash
   source ~/.zshrc
   ```

## Bootstrap command reference

```bash
./bootstrap-linux.sh [OPTIONS]
```

### Options

- `-y, --yes`: non-interactive mode (assume yes)
- `--dry-run`: print planned actions without making changes
- `--skip-tools`: skip optional CLI tool installation
- `--skip-sync-check`: skip required-file checks before symlinking
- `--dotfiles-dir PATH`: override source directory
- `--sync-base PATH`: override Syncthing base directory
- `-h, --help`: show help

### Environment overrides

- `DOTFILES_DIR`
- `SYNC_BASE`
- `SYNC_DOTFILES_DIR`

## Symlinks created by bootstrap

Primary expected links:

- `~/.zshenv` → `shell/.zshenv`
- `~/.config/zsh/.zshenv` → `shell/zdotdir/.zshenv`
- `~/.config/zsh/.zshrc` → `shell/.zshrc`
- `~/.config/zsh/.zprofile` → `shell/.zprofile`
- `~/.gitconfig` → `git/.gitconfig`
- `~/.ssh/config` → `ssh/config`
- `~/.config/Code/User/settings.json` → `vscode/settings.json`
- `~/.tmux.conf` → `tmux/.tmux.conf` (if file exists)

When existing targets are replaced, backups are saved under:
`~/.dotfiles-backup-YYYYMMDD-HHMMSS`

## ZDOTDIR-scoped zsh env

`shell/zdotdir/.zshenv` exists for a subtle reason worth stating explicitly.

zsh reads `$ZDOTDIR/.zshenv` **instead of** `~/.zshenv` whenever `ZDOTDIR` is already set in the environment. Some tools export `ZDOTDIR` before spawning a shell; the OpenCode CLI is one. Those shells are also non-interactive, so they never read `.zshrc`. Without a `$ZDOTDIR/.zshenv`, such a shell sees none of this repository's shell configuration at all.

Keep `shell/zdotdir/.zshenv` **self-contained**. It must never `source ~/.zshenv`, because `shell/.zshenv` ends with `source "$ZDOTDIR/.zshenv"` and the two would recurse.

### 1Password service account

That file loads a 1Password service-account token so the `op` CLI works headlessly, with no desktop-app session delegation and no 1Password Connect dependency:

```zsh
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -r "$HOME/.config/op/service-account-token" ]; then
    OP_SERVICE_ACCOUNT_TOKEN="$(command cat "$HOME/.config/op/service-account-token")"
    export OP_SERVICE_ACCOUNT_TOKEN
fi
```

Rules for this pattern:

- The token itself lives at `~/.config/op/service-account-token` with mode `0600`. It is never committed or synced by this repository; only the loader above is.
- The service account is scoped to the `1pserv` vault, so other vaults still require an interactive sign-in.
- To provision another device, place the same token at that path. Alternatively, the OpenCode config repository's `restore-secrets.sh` writes it from its SOPS bundle.

## Verification commands

```bash
# Verify shell script syntax
bash -n bootstrap-linux.sh

# Verify managed shell files
zsh -n shell/.zshenv
zsh -n shell/zdotdir/.zshenv
zsh -n shell/.zshrc
zsh -n shell/.zprofile

# Verify symlink targets
ls -l ~/.zshenv ~/.config/zsh/.zshenv ~/.config/zsh/.zshrc ~/.config/zsh/.zprofile ~/.gitconfig ~/.ssh/config

# Verify Syncthing user service
systemctl --user --no-pager status syncthing.service
```

## Development and linting

This repo includes Node-based lint/format tooling.

```bash
npm install
npm run lint
npm run format
```

## Security rules

Never commit or sync secrets such as:

- private SSH keys,
- API tokens,
- password files,
- private certificates.

Keep exclusions updated in:

- `.gitignore`
- `.stignore`

## Troubleshooting

- **Syncthing not active**:
  `systemctl --user enable --now syncthing.service`
- **Symlink points to wrong file**:
  rerun bootstrap with correct `--dotfiles-dir`.
- **Unexpected overwrite risk**:
  run `--dry-run` first and inspect planned backup/symlink actions.
- **Sync conflicts**:
  resolve in Syncthing UI (`http://localhost:8384`) and rerun bootstrap if needed.
