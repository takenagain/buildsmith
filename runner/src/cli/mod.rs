use clap::{Parser, Subcommand};
use std::path::PathBuf;

pub mod commands;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// Path to the scripts directory
    #[arg(short, long, default_value = "../scripts")]
    pub scripts_dir: PathBuf,

    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Interactive selection of scripts to run
    Interactive {
        /// Flag to control whether all options are selected by default
        #[arg(short, long, default_value_t = false)]
        all: bool,
    },

    /// Run specific scripts by name without interactive selection
    Run {
        /// List of script names to run
        #[arg(required = true)]
        scripts: Vec<String>,
    },

    /// List available scripts
    List {
        /// Output format for the script list
        #[arg(short, long, value_enum, default_value = "table")]
        format: ListFormat,
    },
}

#[derive(clap::ValueEnum, Clone, Debug)]
pub enum ListFormat {
    /// Simple plain text list
    Plain,
    /// JSON format
    Json,
    /// CSV format
    Csv,
    /// Table format
    Table,
}
