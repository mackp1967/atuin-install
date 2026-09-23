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

echo "Removing the Atuin installation and local data from $HOME..."
rm -rf -- "$HOME/.atuin" "${XDG_DATA_HOME:-$HOME/.local/share}/atuin"

if "$PURGE"; then
  echo "Removing remaining local Atuin configuration and cache..."
  rm -rf -- "${XDG_CONFIG_HOME:-$HOME/.config}/atuin" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/atuin" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/atuin"
fi

echo "Review ~/.bashrc and remove or guard any Atuin initialization lines."
if [[ -f "$HOME/.bashrc" ]]; then
  echo "Sourcing ~/.bashrc in the uninstall script..."
  # Sourcing here affects this script only, not the shell that launched it.
  set +u
  # shellcheck disable=SC1091
  source "$HOME/.bashrc" || echo "Warning: ~/.bashrc returned an error; check Atuin initialization lines." >&2
  set -u
fi
echo "To reload your current shell, run: source ~/.bashrc"
echo "Your self-hosted server account and synced history are not deleted."
