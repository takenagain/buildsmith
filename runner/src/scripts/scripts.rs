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
                let file_name = p.file_name().map_or_else(
                    || String::from("<unknown>"),
                    |name| name.to_string_lossy().to_string(),
                );

                // Check if the path contains a platform-specific directory
                let platform_info = p
                    .parent()
                    .and_then(|parent| parent.file_name())
                    .map(|dir_name| {
                        let dir_str = dir_name.to_string_lossy();
                        if dir_str != "scripts" {
                            format!(" [{}]", dir_str)
                        } else {
                            String::new()
                        }
                    })
                    .unwrap_or_default();

                format!("{}{}", file_name, platform_info)
            })
            .collect()
    }
}

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

    // Always collect scripts from the root scripts directory
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

    // Get OS-specific directory name
    let os_dir = match os_type {
        OsType::Ubuntu | OsType::Pop | OsType::Raspbian | OsType::Kali | OsType::Debian => "debian",
        OsType::Macos => "darwin",
        OsType::Alpine => "alpine",
        _ => {
            info!(
                "OS type {:?} not specifically supported, using only root scripts",
                os_type
            );
            return Ok(scripts); // Return only root scripts for unsupported OS
        }
    };

    // Look for OS-specific scripts in '{scripts_dir}/{os_dir}'
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
        // Even if OS-specific scripts aren't found, we still return the root scripts
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
            warn!(
                "Script failed: {} with exit code: {}",
                script.display(),
                exit_code
            );
            return Err(anyhow::anyhow!(
                "Script failed: {} with exit code: {:?}",
                script.display(),
                status.code()
            ));
        }
        info!("Script completed successfully: {}", script.display());
    }
    Ok(())
}

/// Lists available scripts in various formats
pub fn list_scripts(script_names: &[String], format: &str) -> Result<()> {
    match format {
        "plain" => {
            for name in script_names {
                println!("{}", name);
            }
        }
        "json" => {
            let json = serde_json::to_string_pretty(script_names)?;
            println!("{}", json);
        }
        "csv" => {
            let mut wtr = csv::WriterBuilder::new().from_writer(std::io::stdout());

            wtr.write_record(&["Script Name"])?;
            for name in script_names {
                wtr.write_record(&[name])?;
            }
            wtr.flush()?;
        }
        "table" => {
            println!("{:<4} {:<30}", "No.", "Script Name");
            println!("{:-<4} {:-<30}", "", "");
            for (i, name) in script_names.iter().enumerate() {
                println!("{:<4} {:<30}", i + 1, name);
            }
        }
        _ => {
            return Err(anyhow::anyhow!("Unsupported format: {}", format));
        }
    }

    Ok(())
}
