#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ATUIN_ENV_FILE:-$SCRIPT_DIR/.env}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
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

# Only load a trusted local .env file; it is Bash code.
# shellcheck disable=SC1090
source "$ENV_FILE"
for variable in ATUIN_SYNC_URL ATUIN_USER ATUIN_PASSWORD ATUIN_KEY; do
    if [[ -z "${!variable:-}" ]]; then
        echo "Set $variable in $ENV_FILE before installing." >&2
        exit 1
    fi
done

# Remove only trailing CR/LF. Do not create any key or invoke Atuin with an empty key.
while [[ "$ATUIN_KEY" == *$'\r' || "$ATUIN_KEY" == *$'\n' ]]; do
    ATUIN_KEY="${ATUIN_KEY%?}"
done
if [[ -z "$ATUIN_KEY" || "$ATUIN_KEY" == *$'\r'* || "$ATUIN_KEY" == *$'\n'* ]]; then
    echo "ATUIN_KEY is missing or contains an embedded CR/LF; aborting." >&2
    exit 1
fi

# IMPORTANT: establish the supplied key *before* running the Atuin installer,
# login, history import, init or sync. Never generate or replace a different key.
mkdir -p "$DATA_DIR" "$CONFIG_DIR"
if [[ -e "$KEY_FILE" ]]; then
    if ! printf '%s' "$ATUIN_KEY" | cmp -s "$KEY_FILE" -; then
        echo "ERROR: Existing $KEY_FILE differs from ATUIN_KEY in .env." >&2
        echo "Preserving your current key and history; nothing was initialized." >&2
        exit 1
    fi
    echo "Existing key matches .env; retaining it."
else
    printf '%s' "$ATUIN_KEY" > "$KEY_FILE"
    echo "Created $KEY_FILE from .env (without CR/LF)."
fi
chmod 600 "$KEY_FILE"

# Confirm the actual key file is exactly the supplied key before any Atuin command.
if ! printf '%s' "$ATUIN_KEY" | cmp -s "$KEY_FILE" -; then
    echo "ERROR: Key file verification failed; aborting." >&2
    exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
    cp -p "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi
config_tmp="$(mktemp "$CONFIG_DIR/.config.toml.XXXXXX")"
printf 'sync_address = "%s"\n' "$ATUIN_SYNC_URL" > "$config_tmp"
if [[ -f "$CONFIG_FILE" ]]; then
    sed '/^[[:space:]]*sync_address[[:space:]]*=/d' "$CONFIG_FILE" >> "$config_tmp"
fi
mv -f "$config_tmp" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

# Installation can add shell integration; the key is already in place.
if command -v atuin >/dev/null 2>&1; then
    ATUIN="$(command -v atuin)"
elif [[ ! -x "$ATUIN" ]]; then
    echo "Installing Atuin with your supplied key already configured..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive
fi
if [[ ! -x "$ATUIN" ]]; then
    echo "Atuin executable not found." >&2
    exit 1
fi

echo "Using sync server: $ATUIN_SYNC_URL"
echo "Username: $ATUIN_USER"
echo "Key file verified: $KEY_FILE"

# Reusing a session avoids login/re-encryption of an existing local store.
SESSION_FILE="$DATA_DIR/session"
if [[ -s "$SESSION_FILE" ]]; then
    echo "Existing session found; preserving it and your key."
else
    echo "Logging in with only your .env encryption key."
    # Atuin login flags briefly expose credentials in the local process list.
    "$ATUIN" login -u "$ATUIN_USER" -p "$ATUIN_PASSWORD" -k "$ATUIN_KEY"
fi

# Refuse to import/sync if login unexpectedly changed the key.
if ! printf '%s' "$ATUIN_KEY" | cmp -s "$KEY_FILE" -; then
    echo "ERROR: Atuin changed the key file; refusing to import or sync." >&2
    exit 1
fi

if [[ -t 0 ]]; then
    read -r -p "Import existing shell history? [Y/n] " reply
    if [[ ! "$reply" =~ ^[Nn]$ ]]; then
        "$ATUIN" import auto
    fi
fi
"$ATUIN" sync
echo "Atuin setup complete. Restart your shell to load its integration."
