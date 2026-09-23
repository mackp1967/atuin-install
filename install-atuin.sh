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

# Normalize only trailing CR/LF from the .env value.
while [[ "$ATUIN_KEY" == *$'\r' || "$ATUIN_KEY" == *$'\n' ]]; do
    ATUIN_KEY="${ATUIN_KEY%?}"
done
if [[ -z "$ATUIN_KEY" ]]; then
    echo "ATUIN_KEY is empty after removing trailing CR/LF." >&2
    exit 1
fi

# Never replace an existing key: it may be needed to decrypt the local store.
# Compare without printing the key or passing it as a process argument.
if [[ -e "$KEY_FILE" ]]; then
    if ! printf '%s' "$ATUIN_KEY" | cmp -s "$KEY_FILE" -; then
        echo "ERROR: .env ATUIN_KEY differs from the existing $KEY_FILE." >&2
        echo "Leaving the key, local history, and login untouched. Check your .env." >&2
        exit 1
    fi
    echo "Existing key matches .env; preserving it."
fi

mkdir -p "$CONFIG_DIR" "$DATA_DIR"
if [[ -f "$CONFIG_FILE" ]]; then
    cp -p "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi
config_tmp="$(mktemp "$CONFIG_DIR/.config.toml.XXXXXX")"
# Prepend sync_address so it remains top-level in TOML.
printf 'sync_address = "%s"\n' "$ATUIN_SYNC_URL" > "$config_tmp"
if [[ -f "$CONFIG_FILE" ]]; then
    sed '/^[[:space:]]*sync_address[[:space:]]*=/d' "$CONFIG_FILE" >> "$config_tmp"
fi
mv -f "$config_tmp" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

if [[ ! -e "$KEY_FILE" ]]; then
    # No newline: Atuin key files must contain only the key.
    printf '%s' "$ATUIN_KEY" > "$KEY_FILE"
fi
chmod 600 "$KEY_FILE"

echo "Using sync server: $ATUIN_SYNC_URL"
echo "Username: $ATUIN_USER"
echo "Key file: $KEY_FILE"

# Re-running login with -k can trigger re-encryption of an existing store.
# Keep the existing authenticated session when one is present.
SESSION_FILE="$DATA_DIR/session"
if [[ -s "$SESSION_FILE" ]]; then
    echo "Existing Atuin session found; skipping login to preserve local encryption."
else
    echo "No session found; logging in with the existing encryption key."
    # Credentials may briefly appear in process arguments.
    "$ATUIN" login -u "$ATUIN_USER" -p "$ATUIN_PASSWORD" -k "$ATUIN_KEY"
fi
if [[ -t 0 ]]; then
    read -r -p "Import existing shell history? [Y/n] " reply
    if [[ ! "$reply" =~ ^[Nn]$ ]]; then
        "$ATUIN" import auto
    fi
fi
"$ATUIN" sync
echo "Atuin setup complete. Restart your shell to load its integration."
