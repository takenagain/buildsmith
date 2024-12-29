use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};

pub fn create_temp_dir() -> Result<PathBuf> {
    let temp_dir = PathBuf::from("/tmp").join(format!("script-runner-{}", uuid::Uuid::new_v4()));
    fs::create_dir(&temp_dir).with_context(|| {
        format!(
            "Failed to create temporary directory: {}",
            temp_dir.display()
        )
    })?;
    Ok(temp_dir)
}
