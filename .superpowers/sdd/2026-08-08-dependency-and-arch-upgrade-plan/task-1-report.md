# Task 1 implementation report

## Scope completed

- Updated `runner/Cargo.toml` direct dependencies to every version specified in the task brief.
- Refreshed and force-added `runner/Cargo.lock`; the repository ignore rule otherwise excludes Cargo lockfiles.
- Added Arch mapping to the collector (`OsType::Arch` resolves to `"arch"`).
- Changed unsupported-OS fallback behavior so it collects common Unix scripts only once and does not re-collect the `unix` directory as OS-specific scripts.
- Added the two requested real-filesystem collector unit tests using `tempfile::tempdir()`.

## TDD evidence

Before implementation, ran:

```text
cargo test --manifest-path runner/Cargo.toml collector::tests -- --nocapture
```

Result: failed as expected. The mapping test returned `OS type Arch not specifically supported`; the collection test observed the duplicate Unix script (`left: 2`, `right: 1`).

After implementation, ran:

```text
cargo test --manifest-path runner/Cargo.toml collector::tests -- --nocapture
cargo fmt --manifest-path runner/Cargo.toml -- --check
cargo clippy --manifest-path runner/Cargo.toml -- -D warnings
```

Result: all commands exited 0; collector tests passed (2 passed, 0 failed), formatting was clean, and Clippy reported no warnings.

## Commit

- `00d77d1fc93717fe397fd2f442c1a87eb3425dab` — `build: refresh Rust dependencies and support Arch scripts`

## Scope and concerns

- No files outside Task 1 were modified, except this required task report. The pre-existing `install.sh` change was left untouched.
- `runner/Cargo.lock` was previously ignored and untracked. It is now explicitly tracked because the task explicitly requires a refreshed lockfile.
