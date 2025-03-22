use anyhow::Result;
use dialoguer::MultiSelect;
use log::{debug, error, info, warn};
use std::fs;
use std::path::PathBuf;

use crate::cli::ListFormat;
use crate::scripts::fs::create_temp_dir;
use crate::scripts::scripts::{list_scripts, run_scripts, PathNames};

pub fn interactive_mode(scripts: &[PathBuf], all: bool) -> Result<()> {
    // Assume clean install, so run all scripts by default if all flag is set
    let default_selections: Vec<bool> = vec![all; scripts.len()];
    let script_names: Vec<String> = scripts.to_vec().into_names();
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
    execute_scripts(scripts, &selections)
}

pub fn run_specified_scripts(scripts: &[PathBuf], script_names: Vec<String>) -> Result<()> {
    let mut selections = Vec::new();
    let all_script_names = scripts.to_vec().into_names();

    for name in &script_names {
        if let Some(pos) = all_script_names.iter().position(|n| n == name) {
            selections.push(pos);
        } else {
            warn!("Script not found: {}", name);
        }
    }

    if selections.is_empty() {
        warn!("No matching scripts found.");
        return Ok(());
    }

    info!("Running {} specified scripts", selections.len());
    execute_scripts(scripts, &selections)
}

pub fn list_mode(scripts: &[PathBuf], format: ListFormat) -> Result<()> {
    info!("Listing available scripts");
    let script_infos = scripts.to_vec().into_script_infos();

    match format {
        ListFormat::Plain => list_scripts(&script_infos, "plain")?,
        ListFormat::Json => list_scripts(&script_infos, "json")?,
        ListFormat::Csv => list_scripts(&script_infos, "csv")?,
        ListFormat::Table => list_scripts(&script_infos, "table")?,
    }

    Ok(())
}

fn execute_scripts(scripts: &[PathBuf], selections: &[usize]) -> Result<()> {
    // Create and navigate to a temporary directory for script execution
    // to isolate and remove artifacts downloaded or built by the scripts.
    debug!("Creating temporary directory");
    let temp_dir = create_temp_dir()?;
    info!("Created temporary directory: {}", temp_dir.display());

    info!("Running selected scripts...");
    if let Err(e) = run_scripts(scripts, selections, &temp_dir) {
        error!("Failed to run scripts: {}", e);
        fs::remove_dir_all(&temp_dir).ok(); // Try to clean up even if script fails
        return Err(e);
    }

    debug!("Removing temporary directory");
    fs::remove_dir_all(&temp_dir).map_err(|e| {
        anyhow::anyhow!(
            "Failed to remove temporary directory {}: {}",
            temp_dir.display(),
            e
        )
    })?;
    info!("Cleaned up temporary directory: {}", temp_dir.display());
    info!("All selected scripts completed successfully");

    Ok(())
}
