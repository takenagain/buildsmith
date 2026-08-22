use anyhow::Result;
use dialoguer::MultiSelect;
use log::{debug, error, info, warn};
use std::fs;
use std::path::{Path, PathBuf};

use crate::cli::ListFormat;
use crate::scripts::display::list_scripts;
use crate::scripts::fs::create_temp_dir;
use crate::scripts::models::PathNames;
use crate::scripts::runner::run_scripts;

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

pub fn run_all_scripts(
    scripts: &[PathBuf],
    scripts_root: &Path,
    exclusions: &[String],
) -> Result<()> {
    let selections: Vec<usize> = scripts
        .iter()
        .enumerate()
        .filter_map(|(index, script)| {
            if exclusions
                .iter()
                .any(|exclusion| path_matches_exclusion(script, scripts_root, exclusion))
            {
                info!("Excluding script: {}", script.display());
                None
            } else {
                Some(index)
            }
        })
        .collect();

    if selections.is_empty() {
        warn!("No scripts remain after applying exclusions.");
        return Ok(());
    }

    info!("Running {} collected scripts", selections.len());
    execute_scripts(scripts, &selections)
}

fn path_matches_exclusion(path: &Path, scripts_root: &Path, exclusion: &str) -> bool {
    let relative_path = path
        .strip_prefix(scripts_root)
        .map(Path::to_path_buf)
        .unwrap_or_else(|_| {
            path.parent()
                .and_then(Path::file_name)
                .map(PathBuf::from)
                .unwrap_or_default()
                .join(path.file_name().unwrap_or_default())
        });

    relative_path
        .to_string_lossy()
        .to_ascii_lowercase()
        .contains(&exclusion.to_ascii_lowercase())
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

#[cfg(test)]
mod tests {
    use super::path_matches_exclusion;
    use std::path::{Path, PathBuf};

    #[test]
    fn exclusions_match_path_terms_case_insensitively() {
        let docker = PathBuf::from("scripts/debian/docker-engine.sh");
        let yubikey = PathBuf::from("scripts/arch/yubikey.sh");
        let python = PathBuf::from("scripts/arch/python.sh");
        let scripts_root = Path::new("scripts");

        assert!(path_matches_exclusion(&docker, scripts_root, "docker"));
        assert!(path_matches_exclusion(&yubikey, scripts_root, "YUBIKEY"));
        assert!(!path_matches_exclusion(&python, scripts_root, "docker"));
    }

    #[test]
    fn exclusions_ignore_terms_that_only_appear_in_absolute_parent_paths() {
        let docker_parent = PathBuf::from("/tmp/docker-build/scripts/arch/python.sh");
        let yubikey_parent = PathBuf::from("/tmp/yubikey-cache/scripts/debian/git.sh");

        assert!(!path_matches_exclusion(
            &docker_parent,
            Path::new("/tmp/docker-build/scripts"),
            "docker"
        ));
        assert!(!path_matches_exclusion(
            &yubikey_parent,
            Path::new("/tmp/yubikey-cache/scripts"),
            "yubikey"
        ));
    }
}
