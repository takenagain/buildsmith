use anyhow::{Context, Result};
use clap::Parser;
use dialoguer::MultiSelect;
use os_info::Type as OsType;
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

fn main() -> Result<()> {
    let cli = Cli::parse();
    let os_info = os_info::get();
    
    let scripts = collect_scripts(&cli.scripts_dir, os_info.os_type())?;
    
    if scripts.is_empty() {
        println!("No scripts found in the specified directory.");
        return Ok(());
    }

    let script_names: Vec<String> = scripts
        .iter()
        .map(|p| p.file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string())
        .collect();

    let selections = MultiSelect::new()
        .with_prompt("Select scripts to run (space to toggle, enter to confirm)")
        .items(&script_names)
        .interact()?;

    if selections.is_empty() {
        println!("No scripts selected.");
        return Ok(());
    }

    println!("\nSelected scripts:");
    for &index in selections.iter() {
        let script = &scripts[index];
        println!("Running: {}", script.display());
        
        std::process::Command::new("bash")
            .arg(script)
            .spawn()
            .with_context(|| format!("Failed to execute script: {}", script.display()))?
            .wait()
            .with_context(|| format!("Failed to wait for script: {}", script.display()))?;
    }

    Ok(())
}