# Task 4 Report: application, vendor, Docker, and Proxmox migration

## Scope

Updated only the Task 4 files listed in `task-4-brief.md`; `install.sh`, Cargo
files, Arch scripts, Makefile, CI, devcontainer files, and process
documentation were not changed.

## Red evidence

The required stale-reference scan was run before implementation and failed on
the legacy Flutter 2.8.1 install, NodeSource `setup_18.x`, npm 11.2.0, nvm
0.40.2, Android Studio 2024.3.1.13, and `python2-setuptools` references.

## Changes

- Flutter installers use FVM's `stable` channel only. Debian now uses the
  Android Studio Snap channel, and Alpine uses the maintained `gcompat`
  compatibility package rather than a pinned third-party glibc APK.
- nvm installers now use v0.40.6 and continue to install the current LTS;
  package-manager installers use current packages and `npm@latest`.
- Python installers no longer pin pyenv Python minors or install discontinued
  Rye. They install the platform package-manager Python and current `pipx`,
  Poetry, and uv tooling.
- Proton VPN uses `protonvpn-stable-release_1.0.8_all.deb`; its downloaded
  SHA-256 is checked before installation.
- ROCm uses AMD's documented 7.2.4 Ubuntu Noble bootstrap artifact
  `amdgpu-install_7.2.4.70204-1_all.deb` and Python 3 setuptools.
- Proxmox now selects the highest Ubuntu `.04` LTS template from `pveam` with
  version-aware sorting, uses NodeSource `setup_lts.x`, and installs
  `n8n@latest`.
- Docker uses the current official `latest` channels. The PyTorch image derives
  Torch's installed directory with Python and exposes it through `/opt/libtorch`.

## Current upstream guidance consulted

- AMD ROCm 7.2.4 quick-start documentation for the Ubuntu Noble package name
  and Python package requirements.
- Proton VPN's Debian/Ubuntu repository package; the 1.0.8 artifact was
  downloaded from Proton's repository and its SHA-256 resolved to
  `0b14e71586b22e498eb20926c48c7b434b751149b1f2af9902ef1cfe6b03e180`.
- nvm's current official GitHub release, v0.40.6.
- NodeSource distribution guidance for `setup_lts.x`, n8n's npm installation
  channel, and Docker Hub's current Ubuntu and ROCm image tags.

## Verification

- `bash -n` passed for every modified Bash script; `dash -n` passed for both
  modified Alpine POSIX shell scripts.
- A representative `pveam` list verified the selector returns the highest LTS
  template (`ubuntu-26.04-standard_26.04-1_amd64.tar.zst`).
- `docker compose -f .docker/rocm-compose.yaml config -q` passed.
- The required stale-reference scan and the scoped supplemental stale scan
  passed with process documentation excluded.
- `git diff --check` passed; `git diff -- install.sh` was empty.

## Scope concern

The optional broader scan still finds discontinued Rye and fixed pyenv Python
minors in `scripts/alpine/python.sh`. That file is not in Task 4's allowed file
list, so it was deliberately left unchanged.

PowerShell was unavailable locally, so a PowerShell parser check could not be
run. The task's required shell syntax checks completed successfully.

## Fix round

### Findings addressed

- `scripts/alpine/python.sh` is now in scope. It uses Alpine's current
  `python3`, `py3-pip`, and `pipx` packages, installs Poetry through pipx and
  uv through Astral's installer, and contains no pyenv Python minor pins or
  Rye bootstrap. The script remains POSIX-shell compatible.
- Proton VPN now creates its downloaded repository package with
  `mktemp --suffix=.deb`, so `apt` receives a recognized local Debian package
  path while retaining the existing 1.0.8 URL and SHA-256 verification.
- The Darwin installer no longer invokes pip against the Homebrew-managed
  Python interpreter; Homebrew, pipx, Poetry, and uv remain the supported
  tooling path.

### Fix-round verification

- `dash -n` passed for all modified Alpine POSIX shell scripts; `bash -n`
  passed for every modified Bash script, including Proton VPN and Darwin
  Python.
- Focused stale scans passed: no pyenv minor pins, pyenv bootstrap, Rye URL, or
  Homebrew-Python pip upgrade remains in the fixed scripts.
- A safe `mktemp -u --suffix=.deb` validation produced a `.deb`-suffixed path,
  matching the Proton VPN script's `mktemp --suffix=.deb` invocation.
- `git diff --check` passed and `install.sh` remains unchanged.
