# Atuin install

Install and connect Atuin to your self-hosted sync server using a local `.env` file.

## Set up

```bash
git clone https://github.com/mackp1967/atuin-install.git
cd atuin-install
cp .env.example .env
chmod 600 .env
${EDITOR:-nano} .env
bash install-atuin.sh
```

Set these variables in `.env`:

```dotenv
ATUIN_SYNC_URL='https://atuin.7lsi.com'
ATUIN_USER='mackp'
ATUIN_PASSWORD='your-existing-password'
ATUIN_KEY='your-existing-encryption-key'
```

The installer uses the values in `.env` to install Atuin if necessary, set `sync_address` in `~/.config/atuin/config.toml`, create `~/.local/share/atuin/key`, log in, optionally import existing shell history, and synchronize. The key and configuration files have mode `600`. Existing files are backed up before replacement. The installer strips trailing CR and LF characters from `ATUIN_KEY` and writes the key file with **no trailing newline**. The data directory follows `XDG_DATA_HOME` if set.

Run as your normal Linux user, **not with sudo**. Restart the shell after installation. For a different environment file, set `ATUIN_ENV_FILE=/path/to/.env`.

The key file path is **`~/.local/share/atuin/key`**, not `/.local/share/atuin/key`: the latter would be at the filesystem root.

## Uninstall

```bash
bash uninstall-atuin.sh
# Also delete remaining local Atuin configuration and cache:
bash uninstall-atuin.sh --purge
```

Both commands remove `~/.atuin` and `~/.local/share/atuin` (including local history and key). The uninstall script sources `~/.bashrc` in its own process, but that cannot reload the shell that launched it. Remove or guard the Atuin initialization lines in `~/.bashrc`, then run `source ~/.bashrc` in your current shell or start a fresh shell. Uninstall does not delete your remote account or synchronized server data.

## Security

`.env` is ignored by Git. **Never commit it or your encryption key.** Copy the example to each computer via a secure channel or populate it from your password manager. The installer reads `.env` as trusted Bash input; only use a file you control. Atuin's `login -p ... -k ...` flags allow unattended setup but briefly expose secrets in process arguments. On shared machines with untrusted local users, consider interactive login instead. Once installed, store a backup of your encryption key in your password manager.
