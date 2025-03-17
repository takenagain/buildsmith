# Dev Box Setup Scripts

A collection of scripts to set up development environments with a simple runner interface.

## Usage

### Interactive Mode

Run all scripts in interactive mode:

```bash
make install
```

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
- `runner/`: Contains the Rust runner application
