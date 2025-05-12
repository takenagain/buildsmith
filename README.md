# Dev Box Setup Scripts

A collection of scripts to set up development environments with a simple runner interface.

## Features

- Cross-platform support: Windows 10, Ubuntu, Debian, Alpine, and macOS
- Environment profile selection (Development, Server, Edge runtime, Minimal, Custom)
- No pre-requisite dependencies required
- Simple interactive interface

## Usage

### Interactive Mode with Profile Selection

Run with interactive profile selection:

```bash
make install
```

### Specify Environment Profile

Run with a specific environment profile:

```bash
make install PROFILE=server
```

Available profiles:
- `development` (or `dev`): Full development environment
- `server` (or `srv`): Server setup
- `edge` (or `edgeruntime`): Edge runtime environment
- `minimal` (or `min`): Minimal setup
- `custom` (or `cus`): Custom selection

### Run Specific Scripts

Run a specific script (e.g., to install nodejs):

```bash
make install-nodejs
```

### List Available Scripts

List all available scripts:

```bash
make list-scripts
```

### Additional Commands

```bash
make install-deps  # Install system dependencies
make build        # Build the runner
make run-scripts  # Run specified scripts (use SCRIPTS variable)
make clean        # Clean build artifacts
make deps         # Update dependencies
make test         # Run tests
make fmt         # Format code
make fmt-check   # Check code formatting
make lint        # Run linter
```

## Project Structure

- `scripts/`: Contains setup scripts
  - `debian/`: Debian/Ubuntu specific scripts
  - `alpine/`: Alpine Linux specific scripts
  - `darwin/`: macOS specific scripts
  - `windows/`: Windows specific scripts
  - `unix/`: Generic Unix scripts
- `runner/`: Contains the Rust runner application
