use anyhow::Result;
use include_dir::{include_dir, Dir};
use log::{debug, info};
use os_info::Type as OsType;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use tempfile::tempdir;

// Include scripts directory in the binary
static EMBEDDED_SCRIPTS: Dir = include_dir!("$CARGO_MANIFEST_DIR/../scripts");

/// Extracts embedded scripts to a temporary directory and returns paths to them
pub fn extract_embedded_scripts(os_type: OsType) -> Result<Vec<PathBuf>> {
    debug!("Extracting embedded scripts");

    let temp_dir = tempdir()?;
    let scripts_dir = temp_dir.path().to_path_buf();
    debug!(
        "Created temporary scripts directory: {}",
        scripts_dir.display()
    );

    extract_directory(&EMBEDDED_SCRIPTS, &scripts_dir)?;
    info!("Extracted embedded scripts to: {}", scripts_dir.display());

    let scripts = super::scripts::collect_scripts(Some(&scripts_dir), os_type)?;

    std::mem::forget(temp_dir);

    Ok(scripts)
}

fn extract_directory(dir: &Dir, target_dir: &Path) -> Result<()> {
    fs::create_dir_all(target_dir)?;

    for file in dir.files() {
        let target_file = target_dir.join(file.path().file_name().unwrap());
        let mut file_content = fs::File::create(&target_file)?;
        file_content.write_all(file.contents())?;

        if let Some(ext) = target_file.extension() {
            if ext == "sh" || ext == "ps1" {
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let mut perms = fs::metadata(&target_file)?.permissions();
                    perms.set_mode(0o755); // rwxr-xr-x
                    fs::set_permissions(&target_file, perms)?;
                }
            }
        }
    }

    for subdir in dir.dirs() {
        let target_subdir = target_dir.join(subdir.path());
        extract_directory(subdir, &target_subdir)?;
    }

    Ok(())
}

/// Check if there are embedded scripts available
pub fn has_embedded_scripts() -> bool {
    !EMBEDDED_SCRIPTS.entries().is_empty()
}
