# Atuin install

Install and connect Atuin to your self-hosted sync server using a local `.env` file.

## Staged setup (sync stays disabled)

On a **fresh test host** run as your normal user, not with sudo:

```bash
git clone https://github.com/mackp1967/atuin-install.git
cd atuin-install
cp .env.example .env
chmod 600 .env
${EDITOR:-nano} .env
bash -n install-atuin.sh
bash install-atuin.sh
```

Set `ATUIN_SYNC_URL`, `ATUIN_USER`, `ATUIN_PASSWORD`, and `ATUIN_KEY` in the ignored `.env`. The installer first writes your supplied key to `~/.local/share/atuin/key` with no trailing newline, or refuses to proceed if an existing key differs. It explicitly sets `key_path` to that file, disables automatic sync, and installs Atuin. **The default does not log in, import history, or sync.**

Once the key file has been verified and you are ready to test authentication:

```bash
bash install-atuin.sh --login
atuin store verify
```

The `--login` stage checks the local record store before and after logging in. It still never imports history or syncs, and leaves `auto_sync = false`. If verification fails, stop; do not run `atuin store purge` or sync until you have reviewed a backup and the key mismatch. Confirm the correct key with an already-working host before enabling synchronization manually.

For a different environment file use `ATUIN_ENV_FILE=/path/to/.env`. The key directory follows `XDG_DATA_HOME` if set, so the default key file is **`~/.local/share/atuin/key`** (not `/.local/share/atuin/key`).

## Uninstall

```bash
bash uninstall-atuin.sh
# Also delete remaining local Atuin configuration and cache:
bash uninstall-atuin.sh --purge
```

Both commands remove `~/.atuin` and `~/.local/share/atuin` (including local history and key). The uninstall script sources `~/.bashrc` in its own process, but that cannot reload the shell that launched it. Remove or guard the Atuin initialization lines in `~/.bashrc`, then run `source ~/.bashrc` in your current shell or start a fresh shell. Uninstall does not delete your remote account or synchronized server data.

## Security

`.env` is ignored by Git. **Never commit it or your encryption key.** Copy the example to each computer via a secure channel or populate it from your password manager. The installer reads `.env` as trusted Bash input; only use a file you control. Atuin's `login -p ... -k ...` flags allow unattended setup but briefly expose secrets in process arguments. On shared machines with untrusted local users, consider interactive login instead. Once installed, store a backup of your encryption key in your password manager.
