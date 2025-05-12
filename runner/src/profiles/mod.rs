use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EnvironmentProfile {
    Development,
    Server,
    EdgeRuntime,
    Minimal,
    Custom,
}

impl EnvironmentProfile {
    pub fn all() -> Vec<EnvironmentProfile> {
        vec![
            EnvironmentProfile::Development,
            EnvironmentProfile::Server,
            EnvironmentProfile::EdgeRuntime,
            EnvironmentProfile::Minimal,
            EnvironmentProfile::Custom,
        ]
    }

    pub fn get_default_scripts(&self) -> Vec<&str> {
        match self {
            EnvironmentProfile::Development => vec![
                "apt.sh",
                "git.sh",
                "python.sh",
                "nodejs.sh",
                "flutter.sh",
                "docker-desktop.sh",
                "neovim.sh",
            ],
            EnvironmentProfile::Server => vec![
                "apt.sh",
                "git.sh",
                "python.sh",
                "nodejs.sh",
                "openssh-server.sh",
                "podman.sh",
            ],
            EnvironmentProfile::EdgeRuntime => vec!["apt.sh", "git.sh", "python.sh", "nodejs.sh"],
            EnvironmentProfile::Minimal => vec!["apt.sh", "git.sh"],
            EnvironmentProfile::Custom => vec![],
        }
    }
}

impl fmt::Display for EnvironmentProfile {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EnvironmentProfile::Development => write!(f, "Development Machine"),
            EnvironmentProfile::Server => write!(f, "Server"),
            EnvironmentProfile::EdgeRuntime => write!(f, "Edge Runtime"),
            EnvironmentProfile::Minimal => write!(f, "Minimal"),
            EnvironmentProfile::Custom => write!(f, "Custom"),
        }
    }
}

#[cfg(test)]
mod tests;
