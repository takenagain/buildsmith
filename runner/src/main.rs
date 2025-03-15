use anyhow::{Context, Result};
use clap::Parser;
use dialoguer::MultiSelect;
use log::{debug, error, info, warn};
use runner::scripts::fs::create_temp_dir;
use runner::scripts::scripts::{collect_scripts, run_scripts, PathNames};
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to the scripts directory
    #[arg(short, long, default_value = ".")]
    scripts_dir: PathBuf,

    /// Flag to control whether all options are selected by default
    #[arg(short, long, default_value_t = false)]
    all: bool,
}

fn main() -> Result<()> {
    // Initialize the logger with default level INFO
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Parsing command line arguments");
    let cli: Cli = Cli::parse();
    let os_info = os_info::get();
    info!("Detected OS: {}", os_info);

    debug!("Collecting scripts from: {}", cli.scripts_dir.display());
    let scripts: Vec<PathBuf> = collect_scripts(&cli.scripts_dir, os_info.os_type())?;

    if scripts.is_empty() {
        warn!("No scripts found in the specified directory.");
        return Ok(());
    }
    info!("Found {} scripts", scripts.len());
    debug!("Scripts: {:?}", scripts);

    // Assume clean install, so run all scripts by default
    let default_selections: Vec<bool> = vec![cli.all; scripts.len()];
    let script_names: Vec<String> = scripts.into_names();
    debug!("Showing script selection dialog");
    let selections = MultiSelect::new()
        .with_prompt("Select scripts to run (space to toggle, enter to confirm)")
        .items(&script_names)
        .defaults(&default_selections)
        .interact()?;

    if selections.is_empty() {
        warn!("No scripts selected.");
        return Ok(());
    }

    info!("Selected {} scripts to run", selections.len());
    
    // Create and navigate to a temporary directory for script execution
    // to isolate and remove artifacts downloaded or built by the scripts.
    debug!("Creating temporary directory");
    let temp_dir = create_temp_dir()?;
    info!("Created temporary directory: {}", temp_dir.display());

    info!("Running selected scripts...");
    if let Err(e) = run_scripts(&scripts, &selections, &temp_dir) {
        error!("Failed to run scripts: {}", e);
        return Err(e);
    }

    debug!("Removing temporary directory");
    fs::remove_dir_all(&temp_dir).with_context(|| {
        format!(
            "Failed to remove temporary directory: {}",
            temp_dir.display()
        )
    })?;
    info!("Cleaned up temporary directory: {}", temp_dir.display());
    info!("All selected scripts completed successfully");

    Ok(())
}
