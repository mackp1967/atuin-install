#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ATUIN_ENV_FILE:-$SCRIPT_DIR/.env}"
CONFIG_DIR="${ATUIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/atuin}"
CONFIG_FILE="$CONFIG_DIR/config.toml"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
KEY_FILE="$DATA_DIR/key"
ATUIN="$HOME/.atuin/bin/atuin"

if [[ "${EUID}" -eq 0 ]]; then
    echo "Run as your normal user, not root or sudo." >&2
    exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing $ENV_FILE; copy .env.example to .env and fill in your credentials." >&2
    exit 1
fi

# .env is a trusted local Bash file, not downloaded from the server.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
for variable in ATUIN_SYNC_URL ATUIN_USER ATUIN_PASSWORD ATUIN_KEY; do
    if [[ -z "${!variable:-}" ]]; then
        echo "Set $variable in $ENV_FILE." >&2
        exit 1
    fi
done

if command -v atuin >/dev/null 2>&1; then
    ATUIN="$(command -v atuin)"
elif [[ ! -x "$ATUIN" ]]; then
    echo "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive
fi
if [[ ! -x "$ATUIN" ]]; then
    echo "Atuin executable not found." >&2
    exit 1
fi

mkdir -p "$CONFIG_DIR" "$DATA_DIR"
if [[ -f "$CONFIG_FILE" ]]; then
    cp -p "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi
config_tmp="$(mktemp "$CONFIG_DIR/.config.toml.XXXXXX")"
# Prepend sync_address so it stays top-level in TOML even if sections follow.
printf 'sync_address = "%s"\n' "$ATUIN_SYNC_URL" > "$config_tmp"
if [[ -f "$CONFIG_FILE" ]]; then
    sed '/^[[:space:]]*sync_address[[:space:]]*=/d' "$CONFIG_FILE" >> "$config_tmp"
fi
mv -f "$config_tmp" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

if [[ -f "$KEY_FILE" ]]; then
    cp -p "$KEY_FILE" "$KEY_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi
# Remove trailing CR/LF from the configured key, but do not alter its interior.
while [[ "$ATUIN_KEY" == *$'\r' || "$ATUIN_KEY" == *$'\n' ]]; do
    ATUIN_KEY="${ATUIN_KEY%?}"
done
if [[ -z "$ATUIN_KEY" ]]; then
    echo "ATUIN_KEY is empty after removing trailing CR/LF." >&2
    exit 1
fi
# The key file must not end in a newline or carriage return.
printf '%s' "$ATUIN_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

echo "Using sync server: $ATUIN_SYNC_URL"
echo "Username: $ATUIN_USER"
echo "Key file: $KEY_FILE"

# For unattended login, the password/key are briefly visible in process args.
"$ATUIN" login -u "$ATUIN_USER" -p "$ATUIN_PASSWORD" -k "$ATUIN_KEY"

if [[ -t 0 ]]; then
    read -r -p "Import existing shell history? [Y/n] " reply
    if [[ ! "$reply" =~ ^[Nn]$ ]]; then
        "$ATUIN" import auto
    fi
fi
"$ATUIN" sync
echo "Atuin setup complete. Restart your shell to load its integration."
