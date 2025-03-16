use anyhow::{Context, Result};
use log::{debug, info, warn};
use os_info::Type as OsType;
use std::collections::HashMap;
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

/// Collect scripts organized by OS type
///
/// Returns a HashMap where the key is the OS name (or "common" for root scripts)
/// and the value is a vector of script paths for that OS
pub fn collect_scripts_by_os(scripts_dir: Option<&Path>) -> Result<HashMap<String, Vec<PathBuf>>> {
    let scripts_dir = scripts_dir.unwrap_or_else(|| Path::new("../scripts"));
    debug!(
        "Collecting scripts by OS from directory: {}",
        scripts_dir.display()
    );

    let mut scripts_by_os: HashMap<String, Vec<PathBuf>> = HashMap::new();
    let root_scripts = scripts_by_os
        .entry("common".to_string())
        .or_insert_with(Vec::new);

    // Collect scripts from the root scripts directory
    for entry in WalkDir::new(scripts_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        if entry.path().extension().map_or(false, |ext| ext == "sh") {
            debug!("Found common script: {}", entry.path().display());
            root_scripts.push(entry.path().to_path_buf());
        }
    }

    // Sort the root scripts
    root_scripts.sort_by(|a, b| {
        let a_name = a.file_name().unwrap().to_string_lossy();
        let b_name = b.file_name().unwrap().to_string_lossy();
        a_name.cmp(&b_name)
    });

    // Collect OS-specific scripts
    for entry in WalkDir::new(scripts_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if path.is_dir() && path.file_name().is_some() {
            let os_name = path.file_name().unwrap().to_string_lossy().to_string();
            if os_name != "scripts" {
                // Skip the scripts directory itself
                let os_scripts = scripts_by_os.entry(os_name).or_insert_with(Vec::new);

                // Collect scripts from this OS directory
                for script_entry in WalkDir::new(path)
                    .min_depth(1)
                    .into_iter()
                    .filter_map(|e| e.ok())
                {
                    if script_entry
                        .path()
                        .extension()
                        .map_or(false, |ext| ext == "sh")
                    {
                        debug!(
                            "Found OS-specific script: {}",
                            script_entry.path().display()
                        );
                        os_scripts.push(script_entry.path().to_path_buf());
                    }
                }

                // Sort the OS-specific scripts
                os_scripts.sort_by(|a, b| {
                    let a_name = a.file_name().unwrap().to_string_lossy();
                    let b_name = b.file_name().unwrap().to_string_lossy();
                    a_name.cmp(&b_name)
                });
            }
        }
    }

    Ok(scripts_by_os)
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
            // Group script names by OS type
            let mut scripts_by_os: HashMap<String, Vec<String>> = HashMap::new();

            // Initialize common scripts list
            scripts_by_os.insert("common".to_string(), Vec::new());

            for name in script_names {
                // Check if this script has an OS tag like " [debian]"
                if let Some(bracket_pos) = name.rfind(" [") {
                    // Extract the OS type from the brackets
                    let os_type = name[bracket_pos + 2..name.len() - 1].to_string();
                    let script_name = name[0..bracket_pos].to_string();

                    scripts_by_os
                        .entry(os_type)
                        .or_insert_with(Vec::new)
                        .push(script_name);
                } else {
                    // This is a common script (no OS tag)
                    scripts_by_os.get_mut("common").unwrap().push(name.clone());
                }
            }

            // Get all OS types
            let mut os_types: Vec<&String> = scripts_by_os.keys().collect();
            os_types.sort();

            // Make sure "common" comes first
            if let Some(pos) = os_types.iter().position(|os| *os == "common") {
                let common = os_types.remove(pos);
                os_types.insert(0, common);
            }

            // Determine column width for each column
            let column_width = 30;

            // Print headers
            for os_type in &os_types {
                print!("{:<width$}", os_type, width = column_width);
            }
            println!();

            for os_type in &os_types {
                print!("{:-<width$}", "", width = column_width);
            }
            println!();

            // Find the maximum number of scripts for any OS type
            let max_scripts = scripts_by_os.values().map(|v| v.len()).max().unwrap_or(0);

            // Print rows
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
        _ => {
            return Err(anyhow::anyhow!("Unsupported format: {}", format));
        }
    }

    Ok(())
}

/// Print a table of scripts organized by OS type
pub fn list_scripts_by_os(scripts_by_os: &HashMap<String, Vec<PathBuf>>) -> Result<()> {
    // Determine all OS types available
    let mut os_types: Vec<&String> = scripts_by_os.keys().collect();
    os_types.sort();

    // Ensure "common" is first if it exists
    if let Some(pos) = os_types.iter().position(|os| *os == "common") {
        let common = os_types.remove(pos);
        os_types.insert(0, common);
    }

    // Determine table width for each column
    let column_width = 30;

    // Print headers
    for os_type in &os_types {
        print!("{:<width$}", os_type, width = column_width);
    }
    println!();

    for os_type in &os_types {
        print!("{:-<width$}", "", width = column_width);
    }
    println!();

    // Find the maximum number of scripts for any OS type
    let max_scripts = scripts_by_os.values().map(|v| v.len()).max().unwrap_or(0);

    // Print rows
    for i in 0..max_scripts {
        for os_type in &os_types {
            if let Some(scripts) = scripts_by_os.get(*os_type) {
                if i < scripts.len() {
                    let script_name = scripts[i]
                        .file_name()
                        .map(|name| name.to_string_lossy().to_string())
                        .unwrap_or_else(|| String::from("<unknown>"));
                    print!("{:<width$}", script_name, width = column_width);
                } else {
                    print!("{:<width$}", "", width = column_width);
                }
            } else {
                print!("{:<width$}", "", width = column_width);
            }
        }
        println!();
    }

    Ok(())
}
