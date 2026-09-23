#!/usr/bin/env bash
set -Eeuo pipefail

SERVER="${ATUIN_SERVER:-https://atuin.7lsi.com}"
USERNAME="${ATUIN_USER:-mackp}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
CONFIG_FILE="$CONFIG_DIR/config.toml"
ATUIN="$HOME/.atuin/bin/atuin"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run as your regular user, not root or sudo." >&2
  exit 1
fi

if command -v atuin >/dev/null 2>&1; then
  ATUIN="$(command -v atuin)"
elif [[ ! -x "$ATUIN" ]]; then
  echo "Installing Atuin..."
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive
fi

if [[ ! -x "$ATUIN" ]]; then
  echo "Atuin was not found after installation." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
if [[ -f "$CONFIG_FILE" ]]; then
  cp -p "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
  # Replace an existing top-level sync_address. For a customized TOML config,
  # check the resulting file before running this script again.
  sed -i '/^[[:space:]]*sync_address[[:space:]]*=/d' "$CONFIG_FILE"
fi
printf '\nsync_address = "%s"\n' "$SERVER" >> "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

echo "Server: $SERVER"
echo "Username: $USERNAME"
echo "Log in with your existing Atuin password and encryption key."
"$ATUIN" login -u "$USERNAME"

read -r -p "Import this computer's existing shell history? [Y/n] " reply
if [[ ! "$reply" =~ ^[Nn]$ ]]; then
  "$ATUIN" import auto
fi

"$ATUIN" sync
echo "Done. Restart your shell to activate Atuin."
