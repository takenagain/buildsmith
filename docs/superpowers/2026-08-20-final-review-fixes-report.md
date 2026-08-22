# Final-review fix report

Date: 2026-08-20

## Scope and root causes

The requested final-review findings were verified against the exact scripts and
runner code before changes. Current package data was checked against the
[Arch `pam-u2f` package](https://archlinux.org/packages/extra/x86_64/pam-u2f/),
the [Alpine `gnupg-scdaemon` package](https://pkgs.alpinelinux.org/package/v3.17/main/x86_64/gnupg-scdaemon),
and the [nvm v0.40.7 release](https://github.com/nvm-sh/nvm/releases/tag/v0.40.7).

The confirmed root causes were:

- Arch's script sent two nonexistent official-repository names to pacman:
  `libpam-u2f` and the AUR-only `yubikey-agent`.
- Alpine's YubiKey and OpenSSH scripts performed privileged package and system
  operations directly even though the Docker runner selects the non-root
  `buildsmith` user.
- Alpine's existing GnuPG package set did not install `scdaemon`.
- Exclusion matching inspected the full absolute script path, including parent
  directories outside the scripts root.
- The Docker matrix treated the final runner banner as sufficient evidence and
  did not reconcile the collected paths with per-script completion records.
- The three Cursor scripts called `curl` for API discovery before their
  downloader dependency check.
- Alpine and Debian still referenced nvm v0.40.6.
- The TMPDIR contract searched for a backslash that is not present in the shell
  expansion and therefore could not detect `${TMPDIR:-/tmp}`.

## RED/GREEN evidence

### TMPDIR contract

- RED: `bash scripts/test-yubikey-contracts.sh` exited 1 with
  `unexpected '${TMPDIR:-/tmp}' in .../scripts/debian/flatpak.sh` after the
  assertion was corrected.
- GREEN: the Flatpak download now uses a fixed `/tmp` mktemp template, and the
  same contract exited 0 with `YubiKey separation and run-all contracts passed.`

### Arch YubiKey packages and AUR agent

- Direct reproduction: an Arch base container exited 1 with
  `target not found: libpam-u2f` and `target not found: yubikey-agent`.
- RED: the focused contract exited 1 with
  `unexpected 'libpam-u2f' in .../scripts/arch/yubikey.sh`.
- GREEN: the contract passed; an Arch package-resolution probe successfully
  resolved `pam-u2f`, `ccid`, `gnupg`, `pcsclite`, `pinentry`, and
  `yubikey-manager`; and the script now invokes
  `yay -S --needed --noconfirm yubikey-agent`. Existing `%t` socket,
  `RuntimeDirectory`, and `systemctl --user` assertions remain green.

### Alpine YubiKey fallback

- Direct reproduction: running the original script as the Docker-selected
  non-root user exited 99 with `ERROR: Unable to open log: Permission denied`.
- Package probe: after installing the original package list, `gpg-agent`,
  `gpgconf`, `pcscd`, and `pinentry` existed, while `scdaemon=MISSING`.
- RED: the focused contract exited 1 with
  `missing 'sudo apk add --no-cache' in .../scripts/alpine/yubikey.sh`.
- GREEN: the contract passed, and a fresh Alpine non-root run installed
  `gnupg-scdaemon`, launched the agent, created
  `/home/buildsmith/.gnupg/S.gpg-agent.ssh`, and printed the configured socket.

### Alpine OpenSSH runner privilege boundary

- RED: the focused Alpine runner selected `buildsmith`, invoked the real Rust
  runner, and exited 1 after the script's direct `apk` call returned
  `ERROR: Unable to open log: Permission denied` (script exit 99).
- GREEN: `bash scripts/test-alpine-openssh-server-docker.sh` exited 0. It built
  and invoked the real Alpine runner as `buildsmith`, installed packages via
  sudo, generated host keys, updated sshd policy, persisted the iptables rule,
  started sshd, and printed `Alpine OpenSSH non-root runner validation passed.`

### Relative exclusion matching

- RED: the new Rust negative test exited 101 at
  `assertion failed: !path_matches_exclusion(&docker_parent, "docker")`.
- GREEN: both command tests passed: valid Docker/YubiKey relative paths still
  match case-insensitively, while `docker` and `yubikey` terms that occur only
  above the supplied scripts root do not match unrelated scripts.

### Per-script Docker completion reconciliation

- RED: `bash scripts/test-script-run-log-verifier.sh` exited 1 with
  `missing verifier: .../scripts/verify-script-run-log.sh`.
- GREEN: the fixture deliberately supplied the final runner banner while
  omitting `alpine/git.sh`; the verifier rejected it and named the missing
  path. With both non-excluded fixture paths logged, it printed
  `Verified successful completion for 2 non-excluded scripts.` Docker and
  YubiKey fixture paths were excluded, and `docker` in an absolute parent path
  did not exclude `git.sh`.

### Cursor downloader order

- RED: `bash scripts/test-installer-contracts.sh` exited 1 with
  `check_dependencies runs at line 97 after downloader use at line 71` for the
  Alpine Cursor script.
- GREEN: the focused order contract passed for Alpine, Debian, and Unix after
  each dependency check was moved ahead of API discovery and downloads.

### nvm release

- RED: the focused installer contract exited 1 with
  `nvm installer is not pinned to v0.40.7 in .../scripts/alpine/nodejs.sh`.
- GREEN: both Alpine and Debian now reference the official v0.40.7 installer,
  and the focused contract passed.

## Final verification

The following focused verification was run without the prohibited full
Ubuntu/Alpine/Arch platform lanes:

```text
bash scripts/test-installer-contracts.sh
bash scripts/test-script-run-log-verifier.sh
bash scripts/test-yubikey-contracts.sh
bash scripts/test-alpine-openssh-server-docker.sh
cargo test --manifest-path runner/Cargo.toml cli::commands::tests::
bash -n <all in-scope Bash scripts>
dash -n <all in-scope /bin/sh scripts>
git diff --check
cargo fmt --manifest-path runner/Cargo.toml -- --check
cargo test --manifest-path runner/Cargo.toml
cargo clippy --manifest-path runner/Cargo.toml -- -D warnings
```

Final results: focused shell contracts passed, the Alpine OpenSSH runner
regression passed, all 9 Rust tests passed, Bash/dash syntax checks passed,
`git diff --check` passed, rustfmt check passed, and Clippy passed with warnings
denied. The full platform lanes were intentionally left for the coordinator's
delegated validation.

## Files changed for these findings

- `docs/superpowers/2026-08-20-final-review-fixes-report.md`
- `runner/src/cli/commands.rs`
- `runner/src/main.rs`
- `scripts/alpine/cursor-ide.sh`
- `scripts/alpine/nodejs.sh`
- `scripts/alpine/openssh-server.sh`
- `scripts/alpine/yubikey.sh`
- `scripts/arch/yubikey.sh`
- `scripts/debian/cursor-ide.sh`
- `scripts/debian/flatpak.sh`
- `scripts/debian/nodejs.sh`
- `scripts/test-alpine-openssh-server-docker.sh`
- `scripts/test-installer-contracts.sh`
- `scripts/test-script-run-log-verifier.sh`
- `scripts/test-scripts-docker.sh`
- `scripts/test-yubikey-contracts.sh`
- `scripts/unix/cursor-ide.sh`
- `scripts/verify-script-run-log.sh`

Other dirty-worktree files were pre-existing and were not changed for these
findings.
