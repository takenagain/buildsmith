# Host Resource Isolation Design

## Problem

Buildsmith validation containers can compile with one worker per logical CPU on
this 32-thread workstation. During recent runs, 31 concurrent `cc1plus`
processes consumed more than 19 GiB of resident memory, all 8 GiB of swap was
used, and ZFS ARC retained several additional GiB. The kernel and
`systemd-oomd` then killed GNOME Shell, GNOME Remote Desktop, and the GNOME
session manager, which ended the RDP session and discarded interactive work.

The installed xrdp service is not the RDP server in use. GNOME Remote Desktop
owns TCP port 3389, while xrdp repeatedly fails because the port is already in
use.

## Approved outcome

- Stop the currently running Buildsmith validation without deleting its
  container or logs.
- Give every substantive Buildsmith Docker validation a 12 GiB RAM limit, a
  16 GiB combined RAM-plus-swap limit, a 2,048-process ceiling, and an OOM score
  adjustment of 500.
- Default compiler/build concurrency to four jobs while permitting explicit
  environment overrides.
- Make GNOME's core session services less attractive to `systemd-oomd` and the
  kernel OOM killer.
- Limit ZFS ARC to 8 GiB immediately and persistently.
- Purge only the four unused xrdp-specific packages confirmed by an APT dry
  run; keep GNOME Remote Desktop active on TCP port 3389.

## Design

`scripts/lib/docker-validation-resources.sh` owns the Docker resource defaults
as a Bash array. Docker test entry points source that helper and expand the
array before the image name. Environment variables allow deliberate overrides
without weakening the safe default. The Docker memory cgroup contains an
over-limit build locally, while `--oom-score-adj 500` makes its processes
preferable victims during a host-wide emergency.

Systemd drop-ins protect the four GNOME units that hold the graphical session
together. The user manager starts at `OOMScoreAdjust=-500` on the next login;
the child units request the same value and use
`ManagedOOMPreference=avoid`. The current session's live process scores are
lowered separately so protection does not require restarting the desktop.

ZFS receives `zfs_arc_max=8589934592` through a modprobe configuration file and
the same value through the live sysfs parameter. No pool settings or cached
data are destroyed. The obsolete xrdp packages are purged only after the dry
run shows that no GNOME packages are affected.

## Verification

- A static contract test checks the helper defaults, override behavior, and
  adoption by all Docker test entry points.
- `bash -n` validates every edited shell script.
- `systemd-analyze verify` validates system and user unit drop-ins.
- Live `/proc` values, `systemctl show`, the ZFS module parameter, package
  state, port ownership, and GNOME Remote Desktop health verify the host
  changes.
- The full heavyweight validation is deliberately not restarted during this
  repair; that would recreate the risk being contained.
