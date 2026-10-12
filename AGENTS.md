# Repository instructions

- Run all tests and installation validations for this repository only inside Podman containers.
- Never run project install scripts or package installations on the host environment.
- Prefer an ephemeral container (`--rm`), a read-only bind mount of the workspace, and container-local temporary paths for build and package caches.
- Clean up any containers, volumes, or build caches created for a task before finishing. If Podman is unavailable or blocked, do not fall back to testing or installing on the host.
- Preserve base images during cleanup; remove only task-created containers, volumes, and build cache.
