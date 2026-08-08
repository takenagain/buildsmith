# Latest Dependency and Arch Linux Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update every repository-managed dependency and version reference to current upstream releases/channels, add Arch Linux support with opt-in `yay`, and validate installation in local Docker containers.

**Architecture:** Keep the Rust runner responsible for OS-specific script selection and make shell installers responsible for package-manager-specific bootstrapping. Prefer vendor-supported moving channels for tools and official rolling/latest container tags; retain exact Cargo lockfile versions and vendor checksums where required. Add one disposable Docker validation harness that exercises the same `install.sh` path across supported Linux families.

**Tech Stack:** Rust 2021, Cargo/crates.io, Bash/POSIX shell, PowerShell, GNU Make, Docker, GitHub Actions, pacman/AUR, apt, apk, Homebrew, Snap, Flatpak, FVM.

## Global Constraints

- Remove the legacy Flutter pin everywhere; only install the current FVM `stable` channel.
- Use NodeSource `setup_current.x`, `nvm install node`, `nvm use node`, Windows' latest channel, `npm@latest`, and `n8n@latest`; no fixed Node.js pin remains.
- Use official current/latest OS and container channels; no superseded OS entries remain in test matrices.
- Use ROCm `7.2.4` documentation/package naming for the current repository release.
- Use current GitHub Action lines: checkout `@v6`, cache `@v5`, upload-artifact `@v7`, download-artifact `@v5`, and softprops/action-gh-release `@v3`.
- Arch package operations must use a full `pacman -Syu` transaction; never perform a partial `pacman -Sy` upgrade.
- `yay` is opt-in, must not run as root, and must be built with `makepkg` as a normal user.
- Preserve the pre-existing `install.sh` change that comments out `make install-deps`.
- Do not revert or overwrite unrelated user changes.

---

### Task 1: Refresh Rust crates and make Arch script collection testable

**Files:**
- Modify: `runner/Cargo.toml`
- Modify: `runner/Cargo.lock`
- Modify: `runner/src/scripts/collector.rs`
- Test: `runner/src/scripts/collector.rs` unit tests in the existing module

**Interfaces:**
- `resolve_os_script_directory(os_info::Type) -> anyhow::Result<String>` returns `"arch"` for `os_info::Type::Arch`.
- `collect_scripts` returns each Unix/common and OS-specific `.sh` path once.

- [ ] **Step 1: Write failing collector tests**

Add a `#[cfg(test)] mod tests` to `collector.rs` using `tempfile::tempdir()`:

```rust
#[test]
fn arch_uses_the_arch_script_directory() {
    assert_eq!(resolve_os_script_directory(OsType::Arch).unwrap(), "arch");
}

#[test]
fn arch_collection_does_not_duplicate_unix_scripts() {
    let root = tempfile::tempdir().unwrap();
    std::fs::create_dir_all(root.path().join("unix")).unwrap();
    std::fs::create_dir_all(root.path().join("arch")).unwrap();
    std::fs::write(root.path().join("unix/common.sh"), "#!/bin/sh\n").unwrap();
    std::fs::write(root.path().join("arch/arch.sh"), "#!/bin/sh\n").unwrap();

    let scripts = collect_scripts(Some(root.path()), OsType::Arch).unwrap();

    assert_eq!(scripts.len(), 2);
    assert_eq!(scripts.iter().filter(|path| path.ends_with("common.sh")).count(), 1);
}
```

- [ ] **Step 2: Run the focused tests and verify the expected failure**

Run: `cargo test --manifest-path runner/Cargo.toml collector::tests -- --nocapture`

Expected: the Arch mapping test fails because `Arch` currently resolves to the fallback `unix` directory and the collection test observes a duplicate Unix script.

- [ ] **Step 3: Update direct crate versions to the current crates.io results**

Set the direct dependencies to these current values observed during planning:

```toml
clap = { version = "4.6.6", features = ["derive"] }
dialoguer = "0.12.0"
walkdir = "2.5.0"
anyhow = "1.0.104"
os_info = "3.15.0"
uuid = { version = "1.24.0", features = ["v4"] }
log = "0.4.33"
env_logger = "0.11.11"
serde = { version = "1.0.229", features = ["derive"] }
serde_json = "1.0.151"
csv = "1.4.0"
include_dir = "0.7.4"
tempfile = "3.27.0"
```

Run: `cargo update --manifest-path runner/Cargo.toml`

- [ ] **Step 4: Implement the minimal collector migration**

Map `OsType::Arch` to `"arch"`. Ensure the fallback branch is only used for unsupported operating systems, so an Arch-specific directory is not collected twice. Keep existing sort order and Windows behavior unchanged.

- [ ] **Step 5: Run the focused tests and the Rust quality checks**

Run: `cargo test --manifest-path runner/Cargo.toml collector::tests -- --nocapture`

Expected: PASS with both collector tests.

Run: `cargo fmt --manifest-path runner/Cargo.toml -- --check` and `cargo clippy --manifest-path runner/Cargo.toml -- -D warnings`.

Expected: both commands exit 0.

- [ ] **Step 6: Commit the Rust dependency and collector migration**

```bash
git add runner/Cargo.toml runner/Cargo.lock runner/src/scripts/collector.rs
git commit -m "build: refresh Rust dependencies and support Arch scripts"
```

### Task 2: Make installer bootstrapping portable and add Arch base support

**Files:**
- Modify: `install.sh`
- Modify: `Makefile`
- Create: `scripts/arch/pacman.sh`
- Create: `scripts/unix/rust.sh`
- Test: `bash -n install.sh scripts/arch/pacman.sh scripts/unix/rust.sh`

**Interfaces:**
- `install.sh` recognizes `arch` and runs a full pacman bootstrap without requiring `sudo` when already root.
- `Makefile install-deps` dispatches Arch to `scripts/arch/pacman.sh`.
- `Makefile install-rust` uses the valid shared Unix Rust installer rather than missing distro files.

- [ ] **Step 1: Add shell regression checks before implementation**

Run this side-effect-free red preflight assertion against the current source:

```bash
! rg -q 'arch' install.sh
```

Expected: PASS as a red assertion because the current installer has no Arch
branch. This check is intentionally not kept as a repository test; the later
Docker harness provides the durable integration coverage.

- [ ] **Step 2: Add shared privileged-command and Rust environment handling**

Implement a helper in `install.sh` that executes commands directly as root and through `sudo` otherwise. Detect Arch using `/etc/arch-release` or `ID=arch` from `/etc/os-release`. Export `CARGO_HOME`-aware paths:

```bash
CARGO_BIN_DIR="${CARGO_HOME:-$HOME/.cargo}/bin"
export PATH="$CARGO_BIN_DIR:$PATH"
```

Source `${CARGO_HOME:-$HOME/.cargo}/env` after rustup when present. Preserve the existing commented `#make install-deps` line exactly.

- [ ] **Step 3: Add the Arch pacman bootstrap**

Create `scripts/arch/pacman.sh` with strict mode and:

```bash
pacman -Syu --needed --noconfirm base-devel ca-certificates curl git
```

Use the shared root/sudo behavior where the script is invoked outside the root Docker test.

- [ ] **Step 4: Add the shared Unix Rust installer and repair Make targets**

Create `scripts/unix/rust.sh` that installs/updates the stable rustup toolchain and exports the current Cargo bin path for its process. Change `Makefile` so Linux and macOS `install-rust` call that valid script, and so Arch `install-deps` calls `scripts/arch/pacman.sh`. Do not reference nonexistent `scripts/*/rust.sh` files.

- [ ] **Step 5: Run syntax and Makefile checks**

Run: `bash -n install.sh scripts/arch/pacman.sh scripts/unix/rust.sh`

Expected: exit 0.

Run: `make -n install-deps` and `make -n install-rust`.

Expected: commands reference valid files and include the Arch branch.

- [ ] **Step 6: Commit the installer bootstrap changes**

```bash
git add install.sh Makefile scripts/arch/pacman.sh scripts/unix/rust.sh
git commit -m "feat: add portable Arch bootstrap support"
```

### Task 3: Add Arch application scripts and opt-in yay support

**Files:**
- Create: `scripts/arch/yay.sh`
- Create: `scripts/arch/nodejs.sh`
- Create: `scripts/arch/python.sh`
- Create: `scripts/arch/neovim.sh`
- Create: `scripts/arch/podman.sh`
- Create: `scripts/arch/git.sh`
- Create: `scripts/arch/openssh-server.sh`
- Create: `scripts/arch/flutter.sh`
- Test: `bash -n scripts/arch/*.sh`

**Interfaces:**
- Every Arch script uses pacman package names valid for Arch’s current repositories.
- `scripts/arch/yay.sh` exits with a clear error when run as root and installs `yay` only when explicitly selected.
- Node.js installs the current Arch `nodejs`/`npm` packages and updates npm to `latest`.
- Flutter installs the current repository Flutter/Dart packages and uses only FVM `stable`.

- [ ] **Step 1: Write failing static contract checks**

Run a temporary shell assertion before creating the files:

```bash
test -f scripts/arch/pacman.sh
test -f scripts/arch/yay.sh
```

Expected: the `yay.sh` assertion fails because the file does not exist yet.

- [ ] **Step 2: Implement pacman-based application scripts**

Use strict mode, full `pacman -Syu --needed` transactions, and current package names. Keep application-specific configuration aligned with the existing Debian/Alpine/Darwin scripts while removing stale fixed versions. Flutter must call `fvm install stable` and `fvm global stable`; it must not mention the legacy Flutter pin.

- [ ] **Step 3: Implement the non-root yay path**

Require a non-root caller, install `base-devel` and `git` through a full pacman transaction, clone `https://aur.archlinux.org/yay.git` into a temporary directory, and run `makepkg -si --noconfirm --needed` as the caller. Honor `INSTALL_YAY=1` from an explicitly opted-in base-installer invocation or direct `scripts/arch/yay.sh` invocation; do not call it from the default base installation. There is no dedicated Make target for `yay`.

- [ ] **Step 4: Run static checks and stale-reference assertions**

Run: `bash -n scripts/arch/*.sh`

Expected: exit 0.

Run a moving-channel audit over `scripts/arch` for legacy Flutter pins, stale Node/npm selectors, and fixed application versions.

Expected: exit 0 with no legacy matches.

- [ ] **Step 5: Commit Arch application support**

```bash
git add scripts/arch
git commit -m "feat: add Arch application and yay installers"
```

### Task 4: Migrate stale application, vendor, Docker, and Proxmox versions

**Files:**
- Modify: `scripts/alpine/flutter.sh`
- Modify: `scripts/alpine/nodejs.sh`
- Modify: `scripts/darwin/flutter.sh`
- Modify: `scripts/darwin/nodejs.sh`
- Modify: `scripts/darwin/python.sh`
- Modify: `scripts/debian/flutter.sh`
- Modify: `scripts/debian/nodejs.sh`
- Modify: `scripts/debian/python.sh`
- Modify: `scripts/debian/protonvpn.sh`
- Modify: `scripts/debian/rocm.sh`
- Modify: `scripts/windows/flutter.ps1`
- Modify: `scripts/windows/nodejs.ps1`
- Modify: `scripts/windows/python.ps1`
- Modify: `proxmox/n8n-lxc-setup.sh`
- Modify: `proxmox/README.md`
- Modify: `.docker/Dockerfile`
- Modify: `.docker/pytorch-rocm.dockerfile`
- Modify: `.docker/rocm-compose.yaml`
- Test: shell syntax checks for all modified shell files

**Interfaces:**
- All maintained installers resolve current versions through official channels or current documented bootstrap values.
- Proxmox selects the newest Ubuntu LTS template returned by `pveam` and installs Node.js through `setup_current.x`, then `n8n@latest`.
- ROCm uses the documented 7.2.4 Ubuntu Noble bootstrap artifact and Python 3 package names.
- Docker images use official latest/current tags and dynamically discover the PyTorch libtorch path instead of embedding an old Python minor path.

- [ ] **Step 1: Write stale-reference scans and run them red**

Run a generic moving-channel audit over maintained files for legacy Flutter pins,
superseded OS entries, and stale fixed vendor/application versions.

Expected: FAIL because the existing repository still contains stale fixed versions.

- [ ] **Step 2: Migrate Flutter, Node.js, Python, and package-manager scripts**

Remove legacy Flutter installs; use current stable FVM only. Use current nvm release bootstrap, `nvm install node`, `nvm use node`, `npm install -g npm@latest`, and dynamic current Python selection/package-manager installs. Preserve platform-specific package-manager semantics.

- [ ] **Step 3: Migrate vendor installers and checksums**

Update ProtonVPN to the current documented `protonvpn-stable-release_1.0.8_all.deb` and checksum. Update ROCm to the 7.2.4 Noble installer and `python3-setuptools`. Replace obsolete Alpine glibc pinning with the current Alpine compatibility package or current vendor-supported path. Remove fixed Android Studio archive extraction in favor of the latest supported package channel.

- [ ] **Step 4: Migrate Proxmox and Docker definitions**

Select the highest Ubuntu LTS template from `pveam available` using version-aware sorting, update NodeSource to `setup_current.x`, install `n8n@latest`, and update documentation to describe the dynamic LTS selection. Use current official Docker tags, `rocm-terminal:latest`, and a stable `/opt/libtorch` symlink populated by inspecting the installed Torch package.

- [ ] **Step 5: Re-run syntax and stale scans**

Run shell syntax checks for every modified `.sh`, `bash -n` on Bash scripts, and `rg` scans for all legacy values in the red test.

Expected: syntax checks exit 0 and the stale scan exits 0.

- [ ] **Step 6: Commit the application/vendor migration**

```bash
git add scripts proxmox .docker
git commit -m "build: update application and vendor installers"
```

### Task 5: Update CI, devcontainer, and repository documentation

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/test-install.yml`
- Modify: `.devcontainer/devcontainer.json`
- Modify: `.devcontainer/rust-compose.yml`
- Modify: `README.md`
- Modify: `proxmox/README.md`

**Interfaces:**
- Workflows use current action lines and current runner/container channels.
- Install CI verifies Rust from the configured Cargo home after invoking `install.sh`.
- CI includes Arch container coverage without legacy distro entries.
- Documentation advertises Arch, opt-in `yay`, stable Flutter, current Node/n8n, and Docker validation commands.

- [ ] **Step 1: Add failing workflow/documentation assertions**

Run a generic moving-channel audit over `.github`, `.devcontainer`, `README.md`,
and `proxmox` for legacy action lines, superseded OS entries, and stale fixed
application versions.

Expected: FAIL before the migration.

- [ ] **Step 2: Update workflow action lines and matrix entries**

Use checkout 6, cache 5, upload-artifact 7, download-artifact 5, and release 3. Replace old fixed runner/container entries with latest channels and add an Arch container that prepares `pacman` before running the installer. Update post-install Rust checks to use `${CARGO_HOME:-$HOME/.cargo}/bin`.

- [ ] **Step 3: Update docs and devcontainer configuration**

Document current-at-install behavior, Arch support, `INSTALL_YAY=1`, and the local Docker validation command. Keep the devcontainer on current Rust and current extension identifiers, removing stale version commentary.

- [ ] **Step 4: Run assertions and YAML/JSON validation**

Run the stale assertion above, a YAML parser if installed, and `python -m json.tool .devcontainer/devcontainer.json`.

Expected: stale assertion exits 0 and JSON validation exits 0.

- [ ] **Step 5: Commit CI and documentation changes**

```bash
git add .github .devcontainer README.md proxmox/README.md
git commit -m "ci: test current Linux channels including Arch"
```

### Task 6: Add and run local Docker installer validation

**Files:**
- Create: `scripts/test-install-docker.sh`
- Modify: `Makefile`
- Test: `scripts/test-install-docker.sh`

**Interfaces:**
- `make test-install-docker` runs disposable latest Ubuntu, Debian, Alpine, and Arch containers.
- Each container uses isolated `CARGO_HOME`, `RUSTUP_HOME`, and `CARGO_TARGET_DIR` values and asserts `runner` is executable.
- Arch uses `archlinux:base-devel`, initializes pacman keys if needed, and performs a full upgrade before prerequisites.

- [ ] **Step 1: Write the failing harness contract**

Create the script skeleton with a `run_container` function and a final artifact assertion, then run `bash scripts/test-install-docker.sh`.

Expected: FAIL clearly because the container matrix commands are not implemented.

- [ ] **Step 2: Implement the four-container matrix**

Use official latest images and per-image prerequisite commands. Mount the repository read-only at `/workspace`, set `CI=1`, set isolated temporary Rust/Cargo paths, invoke `bash ./install.sh`, and assert `/tmp/target/release/runner` is executable. Do not invoke `yay` in the root container test.

- [ ] **Step 3: Add the Make target and local usage documentation**

Add `test-install-docker` to `.PHONY` and make it call `bash $(CURDIR)/scripts/test-install-docker.sh`.

- [ ] **Step 4: Run the harness locally**

Run: `make test-install-docker`

Expected: all four containers exit 0 and each reports a built release runner. If Docker is unavailable, record the exact daemon error and continue with all non-Docker verification; do not call the task complete.

- [ ] **Step 5: Commit the Docker validation harness**

```bash
git add scripts/test-install-docker.sh Makefile
git commit -m "test: validate installer in current Linux containers"
```

### Task 7: Full verification and final audit

**Files:**
- Modify: only files required by verification findings.

- [ ] **Step 1: Run the complete Rust verification**

Run: `cargo test --manifest-path runner/Cargo.toml`

Run: `cargo fmt --manifest-path runner/Cargo.toml -- --check`

Run: `cargo clippy --manifest-path runner/Cargo.toml -- -D warnings`

Expected: all commands exit 0.

- [ ] **Step 2: Run shell and configuration verification**

Run `bash -n` for every modified shell script, PowerShell parser checks where `pwsh` is installed, JSON validation for `.devcontainer/devcontainer.json`, and YAML parsing for workflows when a parser is available.

- [ ] **Step 3: Run the repository-wide latest/stale audit**

Search maintained files for all removed legacy pins and selectors, including Flutter, Node.js, npm, nvm, Ubuntu, Debian, Alpine, ROCm terminal, Android Studio, ProtonVPN, and older ROCm values. Review every remaining version-like match manually and classify it as a current value, a protocol/schema version, or unrelated metadata.

- [ ] **Step 4: Inspect the final diff and preserve user changes**

Run: `git diff --check`, `git status --short`, and `git diff -- install.sh`.

Expected: no whitespace errors, the pre-existing `install.sh` change remains, and all intended files are accounted for.

- [ ] **Step 5: Commit only verification fixes and record evidence**

If verification requires fixes, add focused commits with tests. Otherwise, record the exact command outputs in the final handoff and do not create an empty commit.
