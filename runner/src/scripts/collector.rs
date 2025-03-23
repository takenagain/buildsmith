use anyhow::{Error, Result};
use log::{debug, info, warn};
use os_info::Type as OsType;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// Collects all the scripts in the given directory and its subdirectories.
///
/// # Arguments
/// * `scripts_dir` - The directory containing scripts. Defaults to "../scripts" if None is provided.
/// * `os_type` - The operating system type to determine OS-specific scripts.
pub fn collect_scripts(scripts_dir: Option<&Path>, os_type: OsType) -> Result<Vec<PathBuf>> {
    let scripts_dir = scripts_dir.unwrap_or_else(|| Path::new("../scripts"));
    debug!(
        "Collecting scripts from directory: {}",
        scripts_dir.display()
    );
    let mut scripts = Vec::new();

    let os_dir = match resolve_os_script_directory(os_type) {
        Ok(value) => value,
        Err(error) => {
            warn!(
                "Error resolving OS script directory: {}. Attempting generic unix scripts.",
                error
            );
            String::from("unix")
        }
    };

    if os_type != OsType::Windows {
        collect_unix_scripts(scripts_dir)
            .into_iter()
            .for_each(|script| scripts.push(script));
    }

    let os_specific_scripts = collect_os_specific_scripts(scripts_dir, os_dir.as_str());
    if !os_specific_scripts.is_empty() {
        scripts.extend(os_specific_scripts);
    }

    scripts.sort_by(|a, b| {
        let a_name = a.file_name().unwrap().to_string_lossy().to_string();
        let b_name = b.file_name().unwrap().to_string_lossy().to_string();
        a_name.cmp(&b_name)
    });
    info!("Collected {} scripts total", scripts.len());
    Ok(scripts)
}

fn collect_unix_scripts(scripts_dir: &Path) -> Vec<PathBuf> {
    let mut scripts = Vec::new();
    let unix_dir = scripts_dir.join("unix");
    if unix_dir.exists() {
        for entry in WalkDir::new(&unix_dir)
            .min_depth(1)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.path().extension().map_or(false, |ext| ext == "sh") {
                debug!("Found Unix-compatible script: {}", entry.path().display());
                scripts.push(entry.path().to_path_buf());
            }
        }
    }

    scripts
}

fn collect_os_specific_scripts(scripts_dir: &Path, os_dir: &str) -> Vec<PathBuf> {
    let mut scripts = Vec::new();
    let os_specific_dir = scripts_dir.join(os_dir);

    debug!(
        "Looking for OS-specific scripts in: {}",
        os_specific_dir.display()
    );
    if os_specific_dir.exists() {
        info!(
            "Found OS-specific scripts directory: {}",
            os_specific_dir.display()
        );
        for entry in WalkDir::new(&os_specific_dir)
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
        warn!(
            "OS-specific directory not found: {}",
            os_specific_dir.display()
        );
    }

    scripts
}

fn resolve_os_script_directory(os_type: OsType) -> anyhow::Result<String> {
    let os_dir = match os_type {
        OsType::Ubuntu | OsType::Pop | OsType::Raspbian | OsType::Kali | OsType::Debian => "debian",
        OsType::Macos => "darwin",
        OsType::Alpine => "alpine",
        OsType::Windows => "windows",
        _ => {
            return Err(Error::msg(format!(
                "OS type {:?} not specifically supported, using only root scripts",
                os_type
            )));
        }
    };
    Ok(os_dir.to_string())
}
