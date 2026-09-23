#!/usr/bin/env bash
set -Eeuo pipefail

PURGE=false
if [[ "${1:-}" == "--purge" ]]; then
  PURGE=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: ${0} [--purge]" >&2
  exit 2
fi

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run as your regular user, not root or sudo." >&2
  exit 1
fi

echo "Removing the Atuin installation from $HOME..."
rm -rf -- "$HOME/.atuin"

if "$PURGE"; then
  echo "Removing local Atuin configuration and history..."
  rm -rf -- "${XDG_CONFIG_HOME:-$HOME/.config}/atuin" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/atuin" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/atuin" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/atuin"
fi

echo "Review ~/.bashrc and/or ~/.zshrc and remove Atuin initialization lines."
echo "Restart the shell after removing them."
echo "Your self-hosted server account and synced history are not deleted."
