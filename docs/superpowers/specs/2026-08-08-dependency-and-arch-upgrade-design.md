# Latest Dependency and Arch Linux Upgrade Design

## Goal

Bring every maintained dependency, application, operating-system reference,
container image, workflow action, and installer version in the repository to
the current upstream release or official latest channel. Add first-class Arch
Linux support, including an explicitly opt-in `yay` path, and validate the
installer in disposable Docker containers.

## Approach

Use current-at-install-time upstream channels wherever the vendor provides a
supported moving channel: Rust stable, Flutter stable, current Node.js, npm latest,
n8n latest, package-manager packages, official `latest`/rolling container tags,
and the current GitHub Actions major lines. Keep exact values only where Cargo
requires a lockfile or a vendor documents a versioned bootstrap artifact and
checksum. This prevents the scripts from becoming stale immediately after a
point release while retaining integrity checks for externally downloaded
bootstrap packages.

The Rust application will move its direct crates to the latest crates.io
versions, refresh `Cargo.lock`, and receive targeted migrations for any API
breaks. The installer will share safe command helpers across operating
systems, use full-system upgrades for rolling distributions, and preserve the
existing user change that disables `make install-deps` inside `install.sh`.

## Components and Changes

### Rust runner and dependencies

- Update all direct dependencies in `runner/Cargo.toml` to the latest crates.io
  releases and regenerate `runner/Cargo.lock`.
- Keep the application package version unchanged unless a source-compatible
  migration requires a release bump; dependency upgrades are the requested
  scope, not a product release.
- Map `os_info::Type::Arch` to the `arch` script directory.
- Avoid collecting fallback directories twice when an OS-specific directory is
  present.
- Add tests for OS-to-script-directory mapping and script collection
  de-duplication if the existing module boundaries permit unit tests.

### Installer and Make targets

- Detect Arch Linux explicitly in `install.sh` and the Rust collector.
- Make `install.sh` able to bootstrap `make` and Rust on Arch with `pacman`.
- Make the Makefile dispatch dependency and Rust installation to Arch scripts.
- Ensure Rust’s cargo bin directory is available to commands launched by the
  installer itself and by CI verification, including when `CARGO_HOME` is
  customized.
- Remove references to missing platform-specific Rust scripts or replace them
  with a single valid implementation.
- Retain the current `install.sh` line that comments out `make install-deps`.

### Arch Linux support

- Add `scripts/arch/pacman.sh` using a full `pacman -Syu` transaction and the
  current base development, networking, certificate, and source-control
  packages required by the repository.
- Add `scripts/arch/yay.sh` as an explicit opt-in path. It must refuse to run
  as root, build the AUR package as a normal user, and avoid partial upgrades.
- Add Arch variants for the repository’s relevant application scripts rather
  than invoking Debian/Alpine package names on Arch: Node.js, Python, Neovim,
  Podman, Git/OpenSSH, and Flutter where the existing script has an Arch
  equivalent.
- Keep AUR installation separate from base dependency installation because
  `yay` is community-maintained and not required for the runner.

### Current applications, platforms, and images

- Remove the legacy Flutter pin from every script and documentation; install
  only the current stable channel through FVM.
- Replace fixed Node.js and npm patch pins with the current Node.js channel,
  using `setup_current.x`, `nvm install node`, `nvm use node`, Windows' latest
  channel, and `npm@latest`; install n8n with `n8n@latest`.
- Replace stale Ubuntu, Debian, Alpine, and ROCm references with their current
  official channels/releases. Select the newest available Ubuntu LTS template
  dynamically for Proxmox rather than hard-coding an old template name.
- Replace the hard-coded Android Studio archive with the vendor-supported latest
  package channel.
- Update fixed nvm, ProtonVPN, glibc, ROCm, and other vendor bootstrap values to
  the latest documented values and checksums, or use an official latest URL when
  the vendor supports one.
- Install AMD ROCm 7.14.0 through the current `amdgpu-install` 31.40.1 package
  (`amdgpu-install_31.40.1.314001-1_all.deb`). Select AMD's Ubuntu repository
  path from `/etc/os-release`, allow only `resolute`, `noble`, or `jammy`, and
  fail before downloading on any other distribution or codename. Install the
  documented ROCm-only use case with automatic GFX selection and no DKMS.
- Update GitHub Actions to the current documented action lines: checkout 7,
  cache 6, upload-artifact 7, download-artifact 8, and softprops release 3.
- Remove obsolete CI matrix entries for old Ubuntu, Debian, Alpine, and macOS
  releases; use current runner/container channels and add Arch coverage. Linux
  container jobs use the same clean base images and minimal prerequisites as
  `scripts/test-install-docker.sh`, including `archlinux:base` rather than a
  base image with a preinstalled build toolchain.

### Local Docker validation

- Add a repository-local Docker validation command or harness that exercises
  the installer in disposable Ubuntu, Debian, Alpine, and Arch containers.
- Use official rolling/latest images, install only the minimal prerequisites
  needed to run `install.sh`, set isolated Cargo/Rustup/target directories, and
  assert that the release runner is produced.
- Run the Arch validation locally after implementation. Treat unavailable Docker
  or an upstream image/package outage as an explicit verification limitation,
  not as a passing result.

## Error Handling and Safety

- All shell scripts modified for this work retain strict error handling.
- Arch package operations always perform a full upgrade transaction; no
  `pacman -Sy` partial-upgrade sequence is allowed.
- `yay` is never built as root and is never installed implicitly.
- Downloaded vendor bootstrap files retain checksum verification when the
  vendor publishes a checksum.
- The ROCm installer creates its downloaded package under a temporary
  directory, removes that directory on every exit path, and rejects missing or
  unsupported `/etc/os-release` data instead of guessing a repository.
- Docker tests mount the repository read-only where possible and keep build
  state in disposable container paths.
- Existing user changes are preserved and unrelated files are not reverted.

## Verification

The implementation is complete only after all of the following have been run
freshly on the resulting tree:

1. `cargo test --manifest-path runner/Cargo.toml`.
2. `cargo fmt --manifest-path runner/Cargo.toml -- --check`.
3. `cargo clippy --manifest-path runner/Cargo.toml -- -D warnings`.
4. Shell syntax checks for every modified shell script and PowerShell parser
   checks where available.
5. A repository-wide scan showing no stale version pins or legacy Flutter
   references remain in maintained files.
6. Local Docker installer validation, including the Arch image and runner
   artifact assertion.

For the bounded GitHub Actions and ROCm follow-up, run `bash -n` on the ROCm
script, static assertions for every requested action major and ROCm installer
contract, and `git diff --check`. A GPU execution test is intentionally out of
scope because the installer can be validated statically without changing host
GPU drivers or requiring GPU hardware.

## Current upstream references consulted

- Rust stable channel: https://rust-lang.github.io/rustup/basics.html
- Flutter stable channel: https://docs.flutter.dev/install
- Node.js current release policy: https://nodejs.org/en/about/previous-releases
- ROCm 7.14.0 installation: https://rocm.docs.amd.com/en/docs-7.14.0/install/rocm.html
- AMDGPU installer 31.40.1 package index:
  https://repo.radeon.com/amdgpu-install/31.40.1/ubuntu/
- Proton VPN Debian/Ubuntu installation: https://protonvpn.com/support/cli-debian-ubuntu
- GitHub Actions checkout/cache/artifact/release documentation:
  https://github.com/actions/checkout,
  https://github.com/actions/cache,
  https://github.com/actions/upload-artifact,
  https://docs.github.com/en/actions/tutorials/store-and-share-data,
  https://github.com/softprops/action-gh-release
- Arch package maintenance and AUR build guidance:
  https://man.archlinux.org/man/pacman.8.en,
  https://wiki.archlinux.org/title/System_maintenance,
  https://github.com/Jguer/yay#installation
