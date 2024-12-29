use anyhow::{Context, Result};
use clap::Parser;
use dialoguer::MultiSelect;
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
    let cli: Cli = Cli::parse();
    let os_info = os_info::get();

    let scripts: Vec<PathBuf> = collect_scripts(&cli.scripts_dir, os_info.os_type())?;

    if scripts.is_empty() {
        println!("No scripts found in the specified directory.");
        return Ok(());
    }

    // Assume clean install, so run all scripts by default
    let default_selections: Vec<bool> = vec![cli.all; scripts.len()];
    let script_names: Vec<String> = scripts.into_names();
    let selections = MultiSelect::new()
        .with_prompt("Select scripts to run (space to toggle, enter to confirm)")
        .items(&script_names)
        .defaults(&default_selections)
        .interact()?;

    if selections.is_empty() {
        println!("No scripts selected.");
        return Ok(());
    }

    // Create and navigate to a temporary directory for script execution
    // to isolate and remove artifacts downloaded or built by the scripts.
    let temp_dir = create_temp_dir()?;
    println!("Created temporary directory: {}", temp_dir.display());

    println!("\nSelected scripts:");
    run_scripts(scripts, selections, &temp_dir)?;

    fs::remove_dir_all(&temp_dir).with_context(|| {
        format!(
            "Failed to remove temporary directory: {}",
            temp_dir.display()
        )
    })?;
    println!("Cleaned up temporary directory: {}", temp_dir.display());

    Ok(())
}
