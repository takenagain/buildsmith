# YubiKey Agent Separation and Linux Script Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate YubiKey provisioning, use systemd user-agent integration on Debian/Arch, and execute all non-Docker/non-YubiKey Linux scripts in clean Docker containers.

**Architecture:** Add one YubiKey script per supported OS, keep Git and SSH-server responsibilities separate, add a Rust `run-all` command with explicit path exclusions, and make the Docker harness run it as a non-root sudo-capable user.

**Tech Stack:** Rust 2021, clap, Bash/POSIX shell, PowerShell, systemd user units, gpg-agent, Docker, apt/apk/pacman.

## Global Constraints

- Debian and Arch use `yubikey-agent` through `systemctl --user` and `%t/yubikey-agent/yubikey-agent.sock`.
- Alpine uses its existing `gpg-agent` SSH-support fallback.
- Only paths containing `docker` or `yubikey` may be excluded from Docker script execution.
- The repository remains mounted read-only in Docker; build state is disposable.
- Existing user changes, including the commented `#make install-deps`, remain untouched.

---

### Task 1: Add failing contracts for YubiKey separation and runner execution

**Files:**
- Create: `scripts/test-yubikey-contracts.sh`
- Modify: `runner/src/cli/commands.rs`
- Modify: `runner/src/cli/mod.rs`
- Modify: `runner/src/scripts/collector.rs`

- [ ] **Step 1: Write contract assertions first**

Assert that Debian and Arch have `yubikey.sh`, Git scripts contain no
YubiKey-agent setup, Debian/Arch service text is user-scoped, Alpine has its
fallback, and the runner source exposes `run-all` plus exclusion handling.

- [ ] **Step 2: Run the contracts and verify the expected failure**

Run: `bash scripts/test-yubikey-contracts.sh`

Expected: FAIL because the new files and `run-all` command do not yet exist.

- [ ] **Step 3: Add focused Rust tests for relative-path exclusion matching**

Test that `docker-engine.sh` and `yubikey.sh` match exclusions while
`python.sh` does not.

### Task 2: Split YubiKey setup from platform scripts

**Files:**
- Create: `scripts/debian/yubikey.sh`
- Create: `scripts/arch/yubikey.sh`
- Create: `scripts/alpine/yubikey.sh`
- Create: `scripts/darwin/yubikey.sh`
- Create: `scripts/windows/yubikey.ps1`
- Modify: `scripts/debian/git.sh`
- Modify: `scripts/arch/git.sh`
- Modify: `scripts/alpine/git.sh`
- Modify: `scripts/darwin/git.sh`
- Modify: `scripts/windows/git.ps1`

- [ ] **Step 1: Implement Debian/Arch user-agent setup**

Install packages, write `~/.config/systemd/user/yubikey-agent.service` with
`RuntimeDirectory=yubikey-agent`, `ExecStart=<absolute>/yubikey-agent -l
%t/yubikey-agent/yubikey-agent.sock`, enable it with `systemctl --user`,
enable `pcscd.socket`, persist `SSH_AUTH_SOCK`, and import graphical session
variables into the user manager.

- [ ] **Step 2: Implement Alpine fallback and desktop platform splits**

Move Alpine's `gpg-agent` setup to `yubikey.sh`; move macOS LaunchAgent and
Windows YubiKey provisioning to their new files.

- [ ] **Step 3: Remove YubiKey ownership from Git scripts**

Leave Git/OpenSSH installation and Git signing configuration in `git.sh`,
without YubiKey package installation, agent startup, or hardware key restore.

- [ ] **Step 4: Run shell syntax and contract tests**

Run: `bash scripts/test-yubikey-contracts.sh` and syntax checks for every
modified `.sh` file. Expected: PASS.

### Task 3: Add non-interactive run-all execution

**Files:**
- Modify: `runner/src/cli/mod.rs`
- Modify: `runner/src/cli/commands.rs`
- Modify: `runner/src/main.rs`
- Modify: `runner/src/scripts/collector.rs`

- [ ] **Step 1: Implement `run-all --exclude <path>`**

Add a clap subcommand that selects all collected scripts except paths whose
normalized relative path contains one of the requested exclusion terms.
Reuse the existing temporary-directory execution and fail on the first
non-zero script.

- [ ] **Step 2: Run Rust tests, fmt, and Clippy**

Run `cargo test --manifest-path runner/Cargo.toml`, `cargo fmt --manifest-path
runner/Cargo.toml -- --check`, and `cargo clippy --manifest-path
runner/Cargo.toml -- -D warnings`.

### Task 4: Make non-excluded scripts container-runnable

**Files:**
- Modify: `scripts/test-install-docker.sh`
- Create: `scripts/test-scripts-docker.sh`
- Modify: `scripts/alpine/apk.sh`
- Modify: `scripts/alpine/neovim.sh`
- Modify: `scripts/alpine/openssh-server.sh`
- Modify: `scripts/arch/openssh-server.sh`
- Modify: `scripts/debian/openssh-server.sh`
- Modify: the listed Linux scripts, limited to headless, idempotency,
  noninteractive, or current-package fixes required to execute them.

- [ ] **Step 1: Add the Docker script runner**

Run Ubuntu, Alpine, and Arch latest/base containers, install only container
bootstrap prerequisites, create a non-root sudo user, build the runner, and
invoke `run-all --exclude docker --exclude yubikey` with `CI=1`,
`SSH_PUBLIC_KEY`, and `SSH_PORT`.

- [ ] **Step 2: Run each matrix and capture the first real failures**

Run: `bash scripts/test-scripts-docker.sh`

Expected initially: failures identify scripts requiring portability fixes;
the harness must not convert failures into skips.

- [ ] **Step 3: Fix failures minimally and rerun the affected lane**

Replace malformed commands, obsolete package names, interactive-only prompts,
and unconditional service-manager assumptions with documented, idempotent
behavior while preserving normal host behavior.

- [ ] **Step 4: Keep Docker setup excluded and verify all other scripts ran**

The harness must print the collected and excluded paths and assert that every
non-excluded path completed.

### Task 5: Final verification and documentation

**Files:**
- Modify: `README.md`
- Modify: `Makefile`
- Modify: `docs/superpowers/specs/2026-08-12-yubikey-and-docker-script-validation-design.md`

- [ ] **Step 1: Document separate YubiKey setup and host systemd commands**

Document Debian/Arch `systemctl --user` behavior, Alpine fallback, and the
Docker command plus its exact exclusions.

- [ ] **Step 2: Run the complete verification suite**

Run Rust tests/fmt/Clippy, shell syntax, contract tests, and the full Docker
matrix. Run PowerShell parsing if `pwsh` is available.

- [ ] **Step 3: Review diff and working tree**

Run `git diff --check`, inspect all changed files, and confirm no unrelated
changes or user edits were reverted.
