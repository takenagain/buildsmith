use anyhow::{Context, Result};
use clap::Parser;
use dialoguer::MultiSelect;
use os_info::Type as OsType;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to the scripts directory
    #[arg(short, long, default_value = ".")]
    scripts_dir: PathBuf,
}

fn collect_scripts(scripts_dir: &Path, os_type: OsType) -> Result<Vec<PathBuf>> {
    let mut scripts = Vec::new();

    // First, collect scripts from root directory
    for entry in WalkDir::new(scripts_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        if entry.path().extension().map_or(false, |ext| ext == "sh") {
            scripts.push(entry.path().to_path_buf());
        }
    }

    // Then, collect scripts from OS-specific directory
    let os_dir = match os_type {
        OsType::Ubuntu | OsType::Pop | OsType::Raspbian | OsType::Kali | OsType::Debian => "debian",
        _ => return Ok(scripts), // Return only root scripts for unsupported OS
    };

    let os_specific_dir = scripts_dir.join(os_dir);
    if os_specific_dir.exists() {
        for entry in WalkDir::new(os_specific_dir)
            .min_depth(1)
            .max_depth(1)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.path().extension().map_or(false, |ext| ext == "sh") {
                scripts.push(entry.path().to_path_buf());
            }
        }
    }

    Ok(scripts)
}

fn create_temp_dir() -> Result<PathBuf> {
    let temp_dir = PathBuf::from("/tmp").join(format!("script-runner-{}", uuid::Uuid::new_v4()));
    fs::create_dir(&temp_dir).with_context(|| {
        format!(
            "Failed to create temporary directory: {}",
            temp_dir.display()
        )
    })?;
    Ok(temp_dir)
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let os_info = os_info::get();

    let scripts: Vec<PathBuf> = collect_scripts(&cli.scripts_dir, os_info.os_type())?;

    if scripts.is_empty() {
        println!("No scripts found in the specified directory.");
        return Ok(());
    }

    let script_names: Vec<String> = scripts
        .iter()
        .map(|p: &PathBuf| {
            p.file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string()
        })
        .collect();

    // Assume clean install, so run all scripts by default
    let default_selections: Vec<bool> = vec![true; scripts.len()];
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
    for &index in selections.iter() {
        let script = &scripts[index];
        println!("Running: {}", script.display());

        std::process::Command::new("bash")
            .arg(script)
            .current_dir(&temp_dir)
            .spawn()
            .with_context(|| format!("Failed to execute script: {}", script.display()))?
            .wait()
            .with_context(|| format!("Failed to wait for script: {}", script.display()))?;
    }

    fs::remove_dir_all(&temp_dir).with_context(|| {
        format!(
            "Failed to remove temporary directory: {}",
            temp_dir.display()
        )
    })?;
    println!("Cleaned up temporary directory: {}", temp_dir.display());

    Ok(())
}
