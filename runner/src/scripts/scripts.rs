use anyhow::{Context, Result};
use log::{debug, info, warn};
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
                    .map_or_else(
                        || String::from("<unknown>"),
                        |name| name.to_string_lossy().to_string()
                    )
            })
            .collect()
    }
}

/// Collects all the scripts in the given directory and its subdirectories.
pub fn collect_scripts(scripts_dir: &Path, os_type: OsType) -> Result<Vec<PathBuf>> {
    debug!("Collecting scripts from directory: {}", scripts_dir.display());
    let mut scripts = Vec::new();

    for entry in WalkDir::new(scripts_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        if entry.path().extension().map_or(false, |ext| ext == "sh") {
            debug!("Found script: {}", entry.path().display());
            scripts.push(entry.path().to_path_buf());
        }
    }

    let os_dir = match os_type {
        OsType::Ubuntu | OsType::Pop | OsType::Raspbian | OsType::Kali | OsType::Debian => "debian",
        _ => {
            info!("OS type {:?} not specifically supported, using only root scripts", os_type);
            return Ok(scripts); // Return only root scripts for unsupported OS
        }
    };
    
    debug!("Looking for OS-specific scripts in: {}", os_dir);
    let os_specific_dir = scripts_dir.join(os_dir);
    if os_specific_dir.exists() {
        info!("Found OS-specific scripts directory: {}", os_specific_dir.display());
        for entry in WalkDir::new(os_specific_dir)
            .min_depth(1)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.path().extension().map_or(false, |ext| ext == "sh") {
                debug!("Found OS-specific script: {}", entry.path().display());
                scripts.push(entry.path().to_path_buf());
            }
        }
    } else {
        warn!("OS-specific directory not found: {}", os_specific_dir.display());
    }

    scripts.sort_by(|a, b| {
        let a_name = a.file_name().unwrap().to_string_lossy().to_string();
        let b_name = b.file_name().unwrap().to_string_lossy().to_string();
        a_name.cmp(&b_name)
    });
    info!("Collected {} scripts total", scripts.len());
    Ok(scripts)
}

pub fn run_scripts(
    scripts: &[PathBuf],
    selections: &[usize],
    temp_dir: &Path,
) -> Result<(), anyhow::Error> {
    for &index in selections {
        let script = &scripts[index];
        info!("Running script: {}", script.display());

        let status = std::process::Command::new("bash")
            .arg(script)
            .current_dir(temp_dir)
            .spawn()
            .with_context(|| format!("Failed to execute script: {}", script.display()))?
            .wait()
            .with_context(|| format!("Failed to wait for script: {}", script.display()))?;
            
        if !status.success() {
            let exit_code = status.code().unwrap_or(-1);
            warn!("Script failed: {} with exit code: {}", script.display(), exit_code);
            return Err(anyhow::anyhow!("Script failed: {} with exit code: {:?}", 
                                      script.display(), status.code()));
        }
        info!("Script completed successfully: {}", script.display());
    }
    Ok(())
}
