use anyhow::{Context, Result};
use log::{info, warn};
use std::path::{Path, PathBuf};

pub fn run_scripts(
    scripts: &[PathBuf],
    selections: &[usize],
    temp_dir: &Path,
) -> Result<(), anyhow::Error> {
    for &index in selections {
        let script = &scripts[index];
        info!("Running script: {}", script.display());

        let (command, args) = match script.extension().and_then(|ext| ext.to_str()) {
            Some("ps1") => {
                #[cfg(windows)]
                {
                    (
                        "powershell",
                        vec![
                            "-ExecutionPolicy",
                            "Bypass",
                            "-File",
                            script.to_str().unwrap(),
                        ],
                    )
                }
                #[cfg(not(windows))]
                {
                    warn!("PowerShell script detected but not running on Windows");
                    (
                        "pwsh",
                        vec![
                            "-ExecutionPolicy",
                            "Bypass",
                            "-File",
                            script.to_str().unwrap(),
                        ],
                    )
                }
            }
            _ => {
                #[cfg(unix)]
                {
                    ("bash", vec![script.to_str().unwrap()])
                }
                #[cfg(windows)]
                {
                    ("bash", vec![script.to_str().unwrap()])
                }
            }
        };

        let status = std::process::Command::new(command)
            .args(args)
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
