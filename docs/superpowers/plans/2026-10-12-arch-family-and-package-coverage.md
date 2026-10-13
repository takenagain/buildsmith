# Arch Family and Package Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route Arch-derived distributions to the Arch scripts, add Arch equivalents for the missing Linux actions, and refresh stale package and tool pins.

**Architecture:** The Rust runner and bootstrap shell paths will use `/etc/os-release` `ID` and exact `ID_LIKE` tokens to select Arch-family scripts. New Arch actions will use pacman or yay and follow the existing per-script conventions. Confirmed stale pins will be updated alongside their contracts and lock data.

**Tech Stack:** Rust, Bash, Make, pacman, yay, npm, Cargo, Podman.

**Spec:** `docs/superpowers/specs/2026-10-12-arch-family-and-package-coverage-design.md`

## Global Constraints

- Parse `ID_LIKE` as whitespace-separated exact tokens and route systems whose ID or ID_LIKE contains `arch` to the existing `scripts/arch` directory.
- Apply the same Arch-family check in the Rust runner, `install.sh`, and `make install-deps`.
- Add fixture coverage for CachyOS, EndeavourOS, Manjaro, Garuda, and Omarchy metadata, and verify that Fedora-family metadata does not select Arch scripts.
- Do not select pacman/yay scripts for Bazzite; it is a Fedora Atomic image.
- Add Arch actions for Docker Engine, Docker Desktop, Flatpak, GNOME extensions, Proton VPN, ROCm, Snap, and Bitwarden CLI.
- Refresh NVM `0.40.7` to `0.40.8`, Bitwarden CLI `2026.8.0` to `2026.9.1`, Node `22.23.2` to `24.21.0`, npm `10.9.8` to `11.19.0`, and AMDGPU installer `31.40.1` to `31.60`.
- Run all project tests, package checks, and install validations inside Podman; preserve base images and remove task-created containers, volumes, and build cache at the end.

## Review Focus

- Quoted or multi-token `ID_LIKE` values: exact `arch` token is recognized, substrings are not.
- Fedora-family and Bazzite metadata: no Arch scripts are selected.
- Systems without readable os-release metadata: existing `os_info` routing still works.
- Scripts run without a graphical session, systemd, or AMD GPU: contract tests mock service and device operations, and the integration suite excludes hardware/session-only actions.
- Snap script without `yay`: it reports the missing prerequisite clearly and exits without a partial install.

---

### Task 1: Detect Arch-family distributions

**Files:**
- Modify: `runner/src/scripts/collector.rs`
- Create: `scripts/lib/distro-detection.sh`
- Modify: `install.sh`
- Modify: `Makefile`
- Create: `scripts/test-distro-detection.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: existing `collect_scripts(Option<&Path>, OsType) -> Result<Vec<PathBuf>>` interface.
- Produces: private Rust helpers that recognize Arch metadata and the shell function `is_arch_family_os_release [path]` for Makefile detection.

- [x] **Step 1: Add failing Rust fixture tests** for CachyOS (`ID=cachyos`, `ID_LIKE=arch`), EndeavourOS (`ID=endeavouros`, `ID_LIKE=arch`), Manjaro (`ID=manjaro`, `ID_LIKE=arch`), Garuda (`ID=garuda`, `ID_LIKE=arch`), Omarchy (`ID=omarchy`, `ID_LIKE=arch`), Fedora/Bazzite (`ID=bazzite`, `ID_LIKE="fedora"`), substring non-match (`ID_LIKE=archlinux`), and Arch script collection from a CachyOS fixture.
- [x] **Step 2: Run the Rust tests in Podman** and confirm the Arch metadata and collection cases fail before implementation while existing Arch and Windows collection cases pass.
- [x] **Step 3: Implement metadata parsing in the Rust collector**; prefer an Arch-family match from readable os-release text, then retain the existing `OsType` mapping as fallback.
- [x] **Step 4: Add failing shell fixture tests** for the same derivative metadata and Fedora rejection, plus source checks for the installer and Makefile predicates.
- [x] **Step 5: Implement `is_arch_family_os_release [path]`** with exact-token `ID_LIKE` matching for Makefile detection; keep an equivalent self-contained predicate in `install.sh` because streamed bootstrap must detect package managers before its temporary checkout exists. Preserve `/etc/arch-release` fallback.
- [x] **Step 6: Update README platform coverage** to name Arch-derived distributions and clarify that Bazzite follows Fedora Atomic rather than pacman/yay.
- [x] **Step 7: Run Rust and shell detection suites in Podman**, then commit as `feat: detect Arch family distributions`.

### Task 2: Add missing Arch package actions

**Files:**
- Create: `scripts/arch/docker-engine.sh`
- Create: `scripts/arch/docker-desktop.sh`
- Create: `scripts/arch/flatpak.sh`
- Create: `scripts/arch/gnome-extensions.sh`
- Create: `scripts/arch/protonvpn.sh`
- Create: `scripts/arch/rocm.sh`
- Create: `scripts/arch/snap.sh`
- Create: `scripts/arch/bitwarden-cli.sh`
- Create: `scripts/test-arch-package-contracts.sh`
- Modify: `scripts/test-scripts-docker.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: Arch-family routing from Task 1 and current Debian scripts as behavior references.
- Produces: eight runnable actions in `scripts/arch`, using official Arch packages or the documented AUR helper path.

- [x] **Step 1: Write failing package-contract tests** that assert each action installs its intended package and configures its required service/remote; assert Snap gives a clear error when `yay` is unavailable.
- [x] **Step 2: Run the contracts in Podman** and confirm they fail because the Arch actions do not yet exist.
- [x] **Step 3: Check package names and install routes in a disposable Arch Podman container** using pacman metadata; verify Docker Desktop's official Arch archive and Snap's AUR package route.
- [x] **Step 4: Add the eight Arch scripts**: Docker Engine (`docker`, `docker-compose`, service and user group), Docker Desktop (official Arch package via pacman), Flatpak plus Flathub, GNOME extension manager, Proton VPN (`proton-vpn-gtk-app`), ROCm (`rocm-hip-sdk` and render/video access), Snap (`snapd` via yay plus socket and `/snap` setup), and Bitwarden CLI (`bitwarden-cli`).
- [x] **Step 5: Exclude graphical, service-manager, and hardware-dependent actions from the generic script execution container** while retaining contract and package metadata coverage for each.
- [x] **Step 6: Run package contracts, shell syntax checks, and Arch package lookup in Podman**, then commit as `feat: add Arch Linux package actions`.

### Task 3: Refresh NVM and Bitwarden CLI pins

**Files:**
- Modify: `scripts/debian/nodejs.sh`
- Modify: `scripts/alpine/nodejs.sh`
- Modify: `scripts/alpine/bitwarden-cli/bw`
- Modify: `scripts/alpine/bitwarden-cli/package.json`
- Modify: `scripts/alpine/bitwarden-cli/package-lock.json`
- Modify: `scripts/test-installer-contracts.sh`

**Interfaces:**
- Consumes: existing Alpine integrity-locked CLI installation and Debian NVM installation contracts.
- Produces: NVM `0.40.8`; Bitwarden CLI `2026.9.1`; isolated Bitwarden runtime Node `24.21.0` and npm `11.19.0`.

- [x] **Step 1: Update the installer contract expectations first** for the new NVM, Bitwarden, Node, and npm versions; update expected archive URL and wrapper paths.
- [x] **Step 2: Run the contract tests in Podman** and confirm they fail against the stale installer pins.
- [x] **Step 3: Update installer constants, wrapper, package manifest, and test fixtures** to the audited versions.
- [x] **Step 4: Regenerate `package-lock.json` and the Bitwarden tarball SHA-512 inside an Alpine or Node Podman container** using the official npm archive; keep lock integrity metadata.
- [x] **Step 5: Run installer contract tests and an Alpine container installation validation in Podman**, then commit as `chore: refresh Node and Bitwarden versions`.

### Task 4: Refresh ROCm and audit remaining explicit versions

**Files:**
- Modify: `scripts/debian/rocm.sh`
- Modify: `scripts/test-debian-rocm-contract.sh`
- Modify: `runner/Cargo.lock` only if compatible dependencies have newer published versions.
- Modify: other version-bearing files only if the Podman audit confirms their current pins are stale.

**Interfaces:**
- Consumes: current distro-specific installers and their package/version contracts.
- Produces: AMDGPU installer `31.60` and an evidence-backed audit for Android SDK, Proton VPN release package, CI distro tags, and Rust dependency lock versions.

- [x] **Step 1: Update the ROCm contract first** to require AMDGPU installer `31.60` and the matching package filename.
- [x] **Step 2: Run the ROCm contract in Podman** and confirm it fails against `31.40.1`.
- [x] **Step 3: Update the Debian ROCm installer** to `31.60` and `amdgpu-install_31.60.316000-1_all.deb`.
- [x] **Step 4: Audit Android SDK package availability, Proton VPN release metadata, and Cargo compatible updates inside Podman**; change only values proven stale, and record unchanged current pins in the progress ledger.
- [x] **Step 5: Run the ROCm contract and the repository's Rust dependency checks inside Podman**, then commit as `chore: update AMDGPU installer and package locks`.

### Task 5: Verify repository-wide coverage and finish

**Files:**
- Modify: `.github/workflows/test-install.yml` only if current CI distro coverage needs an explicit Arch-family metadata fixture.
- Review: all `scripts/**`, version contracts, README, and this specification.

**Interfaces:**
- Consumes: all implementations and contracts from Tasks 1–4.
- Produces: final passing Podman verification, a clean commit on `main`, and a recorded coverage/version audit.

- [ ] **Step 1: Review every Linux script and explicit version reference** against the spec, including common Unix actions, and list any intentionally distro-specific action in the audit.
- [ ] **Step 2: Run the complete Rust and shell contract suites in Podman**, plus the Arch package and Linux script validation suites that are safe for disposable containers.
- [ ] **Step 3: Run `git diff --check`, review the complete diff, and make any required fixes test-first.**
- [ ] **Step 4: Commit any final grouped documentation/CI updates**, verify the branch is clean, and remove task-created Podman containers, volumes, and build cache while preserving base images.
