use anyhow::{Context, Result};
use log::{info, warn};
use std::path::{Path, PathBuf};

fn interpreter_for_script(script: &Path) -> &'static str {
    if script
        .extension()
        .is_some_and(|extension| extension == "ps1")
    {
        if cfg!(windows) {
            "powershell.exe"
        } else {
            "pwsh"
        }
    } else {
        "bash"
    }
}

fn command_for_script(script: &Path) -> std::process::Command {
    let mut command = std::process::Command::new(interpreter_for_script(script));
    if script
        .extension()
        .is_some_and(|extension| extension == "ps1")
    {
        command.args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]);
    }
    command.arg(script);
    command
}

pub fn run_scripts(
    scripts: &[PathBuf],
    selections: &[usize],
    temp_dir: &Path,
) -> Result<(), anyhow::Error> {
    for &index in selections {
        let script = &scripts[index];
        info!("Running script: {}", script.display());

        let status = command_for_script(script)
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsStr;

    #[test]
    fn powershell_scripts_use_the_platform_powershell() {
        let expected = if cfg!(windows) {
            "powershell.exe"
        } else {
            "pwsh"
        };

        assert_eq!(interpreter_for_script(Path::new("setup.ps1")), expected);
    }

    #[test]
    fn shell_scripts_use_bash() {
        assert_eq!(interpreter_for_script(Path::new("setup.sh")), "bash");
    }

    #[test]
    fn powershell_scripts_run_as_files_with_noninteractive_options() {
        let command = command_for_script(Path::new("setup.ps1"));

        assert_eq!(
            command.get_args().collect::<Vec<_>>(),
            vec![
                OsStr::new("-NoProfile"),
                OsStr::new("-ExecutionPolicy"),
                OsStr::new("Bypass"),
                OsStr::new("-File"),
                OsStr::new("setup.ps1"),
            ]
        );
    }
}
