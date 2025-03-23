use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Information about a script including its name, path, and OS.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptInfo {
    pub name: String,
    pub path: PathBuf,
    pub os_type: String,
}

/// Trait for converting a collection of paths into a collection of names.
pub trait PathNames {
    fn into_names(self) -> Vec<String>;
    fn into_script_infos(self) -> Vec<ScriptInfo>;
}

impl PathNames for Vec<PathBuf> {
    fn into_names(self) -> Vec<String> {
        self.iter()
            .map(|p| {
                let file_name = p.file_name().map_or_else(
                    || String::from("<unknown>"),
                    |name| name.to_string_lossy().to_string(),
                );

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

    fn into_script_infos(self) -> Vec<ScriptInfo> {
        self.iter()
            .map(|p| {
                let file_name = p.file_name().map_or_else(
                    || String::from("<unknown>"),
                    |name| name.to_string_lossy().to_string(),
                );

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
