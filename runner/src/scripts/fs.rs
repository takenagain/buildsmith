use log::debug;
use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};

pub fn create_temp_dir() -> Result<PathBuf> {
    let temp_dir = std::env::temp_dir().join(format!("script-runner-{}", uuid::Uuid::new_v4()));
    debug!("Creating temporary directory at: {}", temp_dir.display());

    fs::create_dir_all(&temp_dir).with_context(|| {
        format!(
            "Failed to create temporary directory: {}",
            temp_dir.display()
        )
    })?;

    debug!("Temporary directory created successfully");
    Ok(temp_dir)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn creates_and_returns_a_usable_platform_temp_directory() {
        let platform_temp_dir = std::env::temp_dir();
        let temp_dir = create_temp_dir().expect("temporary directory should be created");
        let is_in_platform_temp_dir = temp_dir.starts_with(&platform_temp_dir);
        let is_directory = temp_dir.is_dir();
        let write_result = fs::write(temp_dir.join("write-test"), b"usable");
        let cleanup_result = fs::remove_dir_all(&temp_dir);

        assert!(
            is_in_platform_temp_dir,
            "temporary directory should be inside {}",
            platform_temp_dir.display()
        );
        assert!(is_directory, "temporary path should be a directory");
        write_result.expect("temporary directory should be writable");
        cleanup_result.expect("temporary directory should be removed");
    }
}
