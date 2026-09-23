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

LOGIN=false
case "${1:-}" in
    "") ;;
    --login) LOGIN=true ;;
    -h|--help)
        echo "Usage: ${0} [--login]"
        echo "Default: provision and verify your .env key; install Atuin; keep sync disabled."
        echo "--login: also authenticate, then verify key and local record store. Never sync or import."
        exit 0
        ;;
    *)
        echo "Usage: ${0} [--login]" >&2
        exit 2
        ;;
esac

if [[ "${EUID}" -eq 0 ]]; then
    echo "Run as your normal user, not root or sudo." >&2
    exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing $ENV_FILE; copy .env.example to .env and fill it in." >&2
    exit 1
fi

# Source only a trusted, locally controlled .env file.
# shellcheck disable=SC1090
source "$ENV_FILE"
for variable in ATUIN_SYNC_URL ATUIN_USER ATUIN_PASSWORD ATUIN_KEY; do
    if [[ -z "${!variable:-}" ]]; then
        echo "Set $variable in $ENV_FILE before installing." >&2
        exit 1
    fi
done

# Normalize trailing Windows CR/LF, not the body of the key.
while [[ "$ATUIN_KEY" == *$'\r' || "$ATUIN_KEY" == *$'\n' ]]; do
    ATUIN_KEY="${ATUIN_KEY%?}"
done
if [[ -z "$ATUIN_KEY" || "$ATUIN_KEY" == *$'\r'* || "$ATUIN_KEY" == *$'\n'* ]]; then
    echo "Invalid ATUIN_KEY: empty or contains CR/LF." >&2
    exit 1
fi

verify_key() {
    if ! printf '%s' "$ATUIN_KEY" | cmp -s "$KEY_FILE" -; then
        echo "ERROR: $KEY_FILE does not match ATUIN_KEY in .env." >&2
        echo "No import or sync was attempted. Preserve your current files for recovery." >&2
        exit 1
    fi
}

# First: put the supplied key in place before even running the Atuin installer.
mkdir -p "$DATA_DIR" "$CONFIG_DIR"
if [[ -e "$KEY_FILE" ]]; then
    verify_key
    echo "Existing key matches .env; leaving it untouched."
else
    printf '%s' "$ATUIN_KEY" > "$KEY_FILE"
    echo "Created key from .env, without a newline."
fi
chmod 600 "$KEY_FILE"
verify_key

# Explicit key_path keeps Atuin pointed at the exact file we verified.
# auto_sync=false protects the server while diagnosing the second key ID.
if [[ -f "$CONFIG_FILE" ]]; then
    cp -p "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi
config_tmp="$(mktemp "$CONFIG_DIR/.config.toml.XXXXXX")"
printf 'sync_address = "%s"\n' "$ATUIN_SYNC_URL" > "$config_tmp"
printf 'key_path = "%s"\n' "$KEY_FILE" >> "$config_tmp"
printf 'auto_sync = false\n' >> "$config_tmp"
if [[ -f "$CONFIG_FILE" ]]; then
    sed -E '/^[[:space:]]*(sync_address|key_path|auto_sync)[[:space:]]*=/d' "$CONFIG_FILE" >> "$config_tmp"
fi
mv -f "$config_tmp" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

if command -v atuin >/dev/null 2>&1; then
    ATUIN="$(command -v atuin)"
elif [[ ! -x "$ATUIN" ]]; then
    echo "Installing Atuin after provisioning your key..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive
fi
if [[ ! -x "$ATUIN" ]]; then
    echo "Atuin executable not found." >&2
    exit 1
fi
verify_key

echo "Atuin installed. Supplied key verified. Automatic sync is disabled."
if ! "$LOGIN"; then
    echo "No login, history import, or sync was performed."
    echo "Next, run in your current terminal: source ~/.bashrc"
    echo "When ready, run: bash ${0} --login"
    exit 0
fi

# Check existing records before login: do not write additional records if they
# are already encrypted under a different key.
if ! "$ATUIN" store verify; then
    echo "Local record store failed verification. Login and sync are blocked." >&2
    exit 1
fi

SESSION_FILE="$DATA_DIR/session"
if [[ -s "$SESSION_FILE" ]]; then
    echo "Existing session found; not logging in again."
else
    echo "Logging in with the .env key. Sync remains disabled."
    # CLI flags may briefly expose secrets to privileged local processes.
    "$ATUIN" login -u "$ATUIN_USER" -p "$ATUIN_PASSWORD" -k "$ATUIN_KEY"
fi
verify_key
if ! "$ATUIN" store verify; then
    echo "Store failed verification after login. No import or sync attempted." >&2
    exit 1
fi
echo "Login and local verification complete; auto_sync remains false."
echo "No history was imported or synchronized. Review before enabling sync."
