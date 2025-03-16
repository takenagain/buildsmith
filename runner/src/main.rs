use anyhow::Result;
use clap::Parser;
use log::{debug, info, warn};
use runner::cli::commands::{interactive_mode, list_mode, run_specified_scripts};
use runner::cli::Cli;
use runner::cli::Commands;
use runner::scripts::scripts::collect_scripts;

fn main() -> Result<()> {
    // Initialize the logger with default level INFO
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Parsing command line arguments");
    let cli: Cli = Cli::parse();
    let os_info = os_info::get();
    info!("Detected OS: {}", os_info);

    debug!("Collecting scripts from: {}", cli.scripts_dir.display());
    let scripts = collect_scripts(Some(&cli.scripts_dir), os_info.os_type())?;

    if scripts.is_empty() {
        warn!("No scripts found in the specified directory.");
        return Ok(());
    }
    info!("Found {} scripts", scripts.len());
    debug!("Scripts: {:?}", scripts);

    match cli.command.unwrap_or(Commands::Interactive { all: false }) {
        Commands::Interactive { all } => interactive_mode(&scripts, all)?,
        Commands::Run {
            scripts: script_names,
        } => run_specified_scripts(&scripts, script_names)?,
        Commands::List { format } => list_mode(&scripts, format)?,
    }

    Ok(())
}
