# Host Resource Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent Buildsmith validation from exhausting host memory and tearing down GNOME RDP sessions.

**Architecture:** Apply a reusable resource argument array to every substantive Docker validation entry point, then add narrowly scoped host controls for GNOME OOM priority and ZFS ARC. Remove the unused xrdp implementation after confirming that GNOME Remote Desktop is the listener that must remain.

**Tech Stack:** Bash, Docker Engine, systemd/systemd-oomd, ZFS on Linux, APT, GNOME Remote Desktop

**Spec:** `docs/superpowers/specs/2026-08-22-host-resource-isolation-design.md`

## Global Constraints

- Preserve the dirty Buildsmith checkout and do not alter unrelated user changes.
- Do not commit or restart the GNOME session.
- Retain the stopped validation container and its logs.
- Default Docker memory to 12 GiB, total RAM plus swap to 16 GiB, PIDs to 2,048, OOM score adjustment to 500, and build jobs to four.
- Persist ZFS ARC at exactly 8,589,934,592 bytes.
- Purge only `xrdp`, `xorgxrdp`, `pipewire-module-xrdp`, and `libpipewire-0.3-modules-xrdp`.

---

### Task 1: Stop the active validation safely

**Files:** None

**Interfaces:**
- Consumes: Docker container `naughty_torvalds` identified during diagnosis.
- Produces: A retained, exited container whose logs remain inspectable.

- [x] **Step 1: Verify container identity and workspace mount**

  Run `docker inspect naughty_torvalds` and confirm the image is
  `ubuntu:latest` and `/workspace` is mounted from the Buildsmith checkout.

- [x] **Step 2: Stop without removing it**

  Run `docker stop --timeout 20 naughty_torvalds`.

- [x] **Step 3: Verify retained state**

  Confirm Docker reports `status=exited`, and do not run `docker rm`.

### Task 2: Add a tested Docker resource guard

**Files:**
- Create: `scripts/test-docker-validation-resources.sh`
- Create: `scripts/lib/docker-validation-resources.sh`
- Modify: `scripts/test-install-docker.sh`
- Modify: `scripts/test-scripts-docker.sh`
- Modify: `scripts/test-debian-flutter-android-sdk-docker.sh`
- Modify: `scripts/test-arch-nodejs-docker.sh`
- Modify: `scripts/test-arch-python-docker.sh`
- Modify: `scripts/test-create-appimage-desktop-user-ownership.sh`
- Modify: `scripts/test-alpine-openssh-server-docker.sh`
- Modify: `scripts/test-ubuntu-openssh-server-fallback-docker.sh`

**Interfaces:**
- Consumes: Optional `BUILDSMITH_DOCKER_MEMORY_LIMIT`,
  `BUILDSMITH_DOCKER_MEMORY_SWAP_LIMIT`, `BUILDSMITH_DOCKER_PIDS_LIMIT`,
  `BUILDSMITH_DOCKER_OOM_SCORE_ADJ`, and `BUILDSMITH_BUILD_JOBS` variables.
- Produces: Bash array `buildsmith_docker_resource_args` for insertion into
  `docker run` argument lists.

- [x] **Step 1: Write the failing static contract test**

  Assert the helper's default and overridden array values, and assert that all
  eight Docker validation scripts source and expand the helper.

- [x] **Step 2: Verify the contract fails for the missing helper**

  Run `bash scripts/test-docker-validation-resources.sh`; expect a non-zero
  result naming `scripts/lib/docker-validation-resources.sh`.

- [x] **Step 3: Implement the shared Bash array**

  Create the helper with Docker arguments `--memory 12g`, `--memory-swap 16g`,
  `--pids-limit 2048`, `--oom-score-adj 500`, and build-job environment values
  for Make, Cargo, CMake, and `MAX_JOBS`, each derived from the documented
  override variables.

- [x] **Step 4: Adopt the helper in every substantive validation container**

  Source it after `repository_root` is assigned and expand
  `"${buildsmith_docker_resource_args[@]}"` before each validation image. Do
  not modify the tiny AppArmor namespace create/remove helper containers.

- [x] **Step 5: Verify the implementation**

  Run the contract test and `bash -n` on the helper, contract, and eight entry
  points; expect all commands to exit zero.

### Task 3: Protect GNOME and cap ZFS ARC

**Files:**
- Create: `/etc/systemd/system/user@1000.service.d/50-desktop-oom-protection.conf`
- Create: `/home/frannas/.config/systemd/user/org.gnome.Shell@wayland.service.d/50-oom-protection.conf`
- Create: `/home/frannas/.config/systemd/user/gnome-session-manager@ubuntu.service.d/50-oom-protection.conf`
- Create: `/home/frannas/.config/systemd/user/gnome-remote-desktop-handover.service.d/50-oom-protection.conf`
- Create: `/home/frannas/.config/systemd/user/gnome-session-monitor.service.d/50-oom-protection.conf`
- Create: `/etc/modprobe.d/zfs-arc-max.conf`

**Interfaces:**
- Consumes: systemd user manager for UID 1000 and loaded ZFS module.
- Produces: GNOME unit OOM preference `avoid`, next-login kernel OOM adjustment
  `-500`, live core-process adjustment `-500`, and ZFS ARC ceiling 8 GiB.

- [x] **Step 1: Verify desired settings are initially absent**

  Inspect `systemctl cat`, `systemctl --user cat`, and
  `/sys/module/zfs/parameters/zfs_arc_max`; expect no custom drop-ins and ARC
  value `0`.

- [x] **Step 2: Install and validate drop-ins**

  Stage files with `OOMScoreAdjust=-500` and
  `ManagedOOMPreference=avoid`, install the root-owned files with mode 0644,
  then run `systemd-analyze verify` for system and user units.

- [x] **Step 3: Reload managers without restarting the desktop**

  Run `systemctl daemon-reload` and `systemctl --user daemon-reload`. Lower the
  four current core GNOME process scores through their exact live MainPIDs.

- [x] **Step 4: Apply and persist the ARC ceiling**

  Install `options zfs zfs_arc_max=8589934592` under `/etc/modprobe.d`, write
  `8589934592` to the live module parameter, and verify both copies.

### Task 4: Remove the xrdp conflict and verify the host

**Files:** APT-managed package state only

**Interfaces:**
- Consumes: APT dry run showing exactly four xrdp-specific removals.
- Produces: No xrdp/xorgxrdp packages, with GNOME Remote Desktop still active
  and listening on TCP 3389.

- [x] **Step 1: Purge only the simulated package set**

  Run `sudo apt-get purge -y xrdp xorgxrdp pipewire-module-xrdp
  libpipewire-0.3-modules-xrdp`; do not autoremove `libfuse2t64`.

- [x] **Step 2: Verify all controls**

  Check the Docker contract, syntax, unit properties, live process scores, ZFS
  parameter, package absence, TCP 3389 listener, GNOME Remote Desktop service,
  stopped validation state, RAM/swap, and new OOM records since remediation.

- [x] **Step 3: Preserve the dirty checkout**

  Run `git status --short`, report only files deliberately added or modified by
  this plan, and do not stage or commit anything.
