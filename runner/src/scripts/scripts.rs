use anyhow::{Context, Result};
use log::{debug, info, warn};
use os_info::Type as OsType;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// Information about a script including its name, path, and OS.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptInfo {
    pub name: String,
    pub path: PathBuf,
    pub os_type: String,
}

/// Trait for converting a collection of paths into a collection of names.
pub trait PathNames {
    fn into_names(&self) -> Vec<String>;
    fn into_script_infos(&self) -> Vec<ScriptInfo>;
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

    fn into_script_infos(&self) -> Vec<ScriptInfo> {
        self.iter()
            .map(|p| {
                let file_name = p.file_name().map_or_else(
                    || String::from("<unknown>"),
                    |name| name.to_string_lossy().to_string(),
                );

                // Extract OS type from parent directory
                let os_type = p
                    .parent()
                    .and_then(|parent| parent.file_name())
                    .map(|dir_name| dir_name.to_string_lossy().to_string())
                    .unwrap_or_else(|| String::from("common"));

                ScriptInfo {
                    name: file_name,
                    path: p.clone(),
                    os_type: if os_type == "scripts" {
                        String::from("common")
                    } else {
                        os_type
                    },
                }
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
        // Skip .sh scripts in root directory on Windows
        if entry.path().extension().map_or(false, |ext| ext == "sh") {
            if os_type != OsType::Windows {
                debug!("Found script: {}", entry.path().display());
                scripts.push(entry.path().to_path_buf());
            }
        } else if entry.path().extension().map_or(false, |ext| ext == "ps1") {
            // Add PowerShell scripts on any platform (they will only execute on Windows)
            debug!("Found script: {}", entry.path().display());
            scripts.push(entry.path().to_path_buf());
        }
    }

    // Get OS-specific directory name
    let os_dir = match os_type {
        OsType::Ubuntu | OsType::Pop | OsType::Raspbian | OsType::Kali | OsType::Debian => "debian",
        OsType::Macos => "darwin",
        OsType::Alpine => "alpine",
        OsType::Windows => "windows",
        _ => {
            info!(
                "OS type {:?} not specifically supported, using only root scripts",
                os_type
            );
            return Ok(scripts); // Return only root scripts for unsupported OS
        }
    };

    // Add unix scripts for all Unix-like systems
    if os_type != OsType::Windows {
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
    }

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
pub fn list_scripts(script_infos: &[ScriptInfo], format: &str) -> Result<()> {
    match format {
        "plain" => {
            for info in script_infos {
                println!("{} [{}]", info.name, info.os_type);
            }
        }
        "json" => {
            let json = serde_json::to_string_pretty(script_infos)?;
            println!("{}", json);
        }
        "csv" => write_scripts_to_csv(script_infos)?,
        "table" => print_scripts_table(),
        _ => return Err(anyhow::anyhow!("Unsupported format: {}", format)),
    }

    Ok(())
}

fn write_scripts_to_csv(script_infos: &[ScriptInfo]) -> Result<(), anyhow::Error> {
    let mut wtr = csv::WriterBuilder::new().from_writer(std::io::stdout());
    wtr.write_record(&["Script Name", "OS Type", "Path"])?;
    for info in script_infos {
        wtr.write_record(&[
            &info.name,
            &info.os_type,
            &info.path.to_string_lossy().to_string(),
        ])?;
    }
    wtr.flush()?;
    Ok(())
}

fn collect_scripts_by_os() -> HashMap<String, Vec<String>> {
    let mut scripts_by_os = HashMap::new();
    let scripts_dir = Path::new("../scripts");

    if let Ok(entries) = std::fs::read_dir(scripts_dir) {
        for entry in entries.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_dir() {
                let os_type = path.file_name().unwrap().to_string_lossy().to_string();
                let mut scripts = Vec::new();

                if let Ok(scripts_entries) = std::fs::read_dir(&path) {
                    for script_entry in scripts_entries.filter_map(Result::ok) {
                        if let Some(name) = script_entry.path().file_name() {
                            scripts.push(name.to_string_lossy().to_string());
                        }
                    }
                }

                scripts.sort();
                scripts_by_os.insert(os_type, scripts);
            }
        }
    }

    scripts_by_os
}

fn print_scripts_table() {
    let scripts_by_os = collect_scripts_by_os();
    let mut os_types: Vec<&String> = scripts_by_os.keys().collect();
    os_types.sort();

    let column_width = print_table_headers(&os_types);
    let max_scripts = scripts_by_os.values().map(|v| v.len()).max().unwrap_or(0);

    for i in 0..max_scripts {
        for os_type in &os_types {
            if let Some(scripts) = scripts_by_os.get(*os_type) {
                if i < scripts.len() {
                    print!("{:<width$}", scripts[i], width = column_width);
                } else {
                    print!("{:<width$}", "", width = column_width);
                }
            } else {
                print!("{:<width$}", "", width = column_width);
            }
        }
        println!();
    }
}

fn print_table_headers(os_types: &Vec<&String>) -> usize {
    let column_width = 30;
    for os_type in os_types {
        print!("{:<width$}", os_type, width = column_width);
    }
    println!();
    for _ in os_types {
        print!("{:-<width$}", "", width = column_width);
    }
    println!();
    column_width
}
