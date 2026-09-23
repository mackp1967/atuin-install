# Atuin install

Install and connect a Linux shell to the existing self-hosted Atuin account.

- Sync server: `https://atuin.7lsi.com`
- Username: `mackp`
- Password and encryption key are entered interactively, **never stored in this repository**.

## Install on a new computer

Run as your normal Linux user (not with `sudo`):

```bash
git clone https://github.com/mackp1967/atuin-install.git
cd atuin-install
bash install-atuin.sh
```

The installer installs Atuin when needed, backs up an existing `config.toml`, configures the sync server, prompts for login credentials and the existing encryption key, optionally imports local shell history, and runs `atuin sync`.

To override the defaults:

```bash
ATUIN_SERVER="https://other.example.com" ATUIN_USER="otheruser" bash install-atuin.sh
```

Restart your shell after installing. Check sync with `atuin status` and `atuin sync`. On an already configured computer, `atuin key` displays the key you need for new installs; keep it in your password manager.

## Uninstall

Remove the installer-managed Atuin binary while keeping your local configuration and history:

```bash
bash uninstall-atuin.sh
```

To also delete **local** Atuin configuration, history, and cached data:

```bash
bash uninstall-atuin.sh --purge
```

Review `~/.bashrc` or `~/.zshrc` and remove any Atuin initialization lines, then restart the shell. The uninstall script does not remove shell initialization automatically, and it does not remove binaries installed separately via a package manager or delete your server-side account/history.

## Security

Do not commit your password, encryption key, or personal `config.toml`. The script uses the interactive Atuin login prompt rather than including secrets in command-line flags. Inspect downloaded installers before executing them in sensitive environments.
