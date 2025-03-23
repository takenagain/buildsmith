use log::debug;
use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};

pub fn create_temp_dir() -> Result<PathBuf> {
    let temp_dir = PathBuf::from("/tmp").join(format!("script-runner-{}", uuid::Uuid::new_v4()));
    debug!("Creating temporary directory at: {}", temp_dir.display());

    fs::create_dir(&temp_dir).with_context(|| {
        format!(
            "Failed to create temporary directory: {}",
            temp_dir.display()
        )
    })?;

    debug!("Temporary directory created successfully");
    Ok(temp_dir)
}
