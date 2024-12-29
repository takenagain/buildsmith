use anyhow::{Context, Result};
use os_info::Type as OsType;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// Trait for converting a collection of paths into a collection of names.
pub trait PathNames {
    fn into_names(&self) -> Vec<String>;
}

impl PathNames for Vec<PathBuf> {
    fn into_names(&self) -> Vec<String> {
        self.iter()
            .map(|p| {
                p.file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string()
            })
            .collect()
    }
}

/// Collects all the scripts in the given directory and its subdirectories.
pub fn collect_scripts(scripts_dir: &Path, os_type: OsType) -> Result<Vec<PathBuf>> {
    let mut scripts = Vec::new();

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

/// Runs the selected scripts.
pub fn run_scripts(
    scripts: Vec<PathBuf>,
    selections: Vec<usize>,
    temp_dir: &PathBuf,
) -> Result<(), anyhow::Error> {
    Ok(for &index in selections.iter() {
        let script = &scripts[index];
        println!("Running: {}", script.display());

        std::process::Command::new("bash")
            .arg(script)
            .current_dir(temp_dir)
            .spawn()
            .with_context(|| format!("Failed to execute script: {}", script.display()))?
            .wait()
            .with_context(|| format!("Failed to wait for script: {}", script.display()))?;
    })
}
