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

# Log out before deleting the binary or local account data.
if command -v atuin >/dev/null 2>&1; then
  ATUIN_BIN="$(command -v atuin)"
elif [[ -x "$HOME/.atuin/bin/atuin" ]]; then
  ATUIN_BIN="$HOME/.atuin/bin/atuin"
else
  ATUIN_BIN=""
fi

if [[ -n "$ATUIN_BIN" ]]; then
  echo "Logging out of Atuin..."
  if ! "$ATUIN_BIN" logout; then
    echo "Warning: Atuin logout failed (or was already logged out); continuing local removal." >&2
  fi
else
  echo "Atuin executable not found; skipping logout."
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
