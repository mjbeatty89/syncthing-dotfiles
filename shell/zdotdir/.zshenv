#!/usr/bin/env zsh
#
# ZDOTDIR-scoped zsh environment.
#
# zsh reads $ZDOTDIR/.zshenv INSTEAD of ~/.zshenv whenever ZDOTDIR is already
# set in the environment. Tools such as the OpenCode CLI export ZDOTDIR before
# spawning a non-interactive shell, and non-interactive shells never read
# .zshrc — so this file is the only startup file those shells see.
#
# Keep it self-contained. Do NOT source ~/.zshenv from here: ~/.zshenv ends
# with `source "$ZDOTDIR/.zshenv"`, which would recurse indefinitely.
#
# Symlinked to ~/.config/zsh/.zshenv by bootstrap-linux.sh
# (see create_symlinks).

# 1Password service account — gives `op` headless reads in every shell with no
# desktop-app session delegation and no 1Password Connect dependency.
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -r "$HOME/.config/op/service-account-token" ]; then
    OP_SERVICE_ACCOUNT_TOKEN="$(command cat "$HOME/.config/op/service-account-token")"
    export OP_SERVICE_ACCOUNT_TOKEN
fi
