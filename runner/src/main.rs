use anyhow::Result;
use clap::Parser;
use log::{debug, info, warn};
use runner::cli::commands::{
    get_profile_from_name, interactive_mode, list_mode, profile_selection_mode,
    run_specified_scripts,
};
use runner::cli::Cli;
use runner::cli::Commands;
use runner::scripts::collector::collect_scripts;
use runner::scripts::embedded;

fn main() -> Result<()> {
    // Initialize the logger with default level INFO
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    debug!("Parsing command line arguments");
    let cli: Cli = Cli::parse();
    let os_info = os_info::get();

    info!("Detected OS: {}", os_info);

    // Try to collect scripts from the specified directory
    debug!("Collecting scripts from: {}", cli.scripts_dir.display());
    let scripts = collect_scripts(Some(&cli.scripts_dir), os_info.os_type());

    // If external scripts are available, use them; otherwise use embedded ones
    let scripts = match scripts {
        Ok(scripts) if !scripts.is_empty() => {
            info!("Using external scripts from: {}", cli.scripts_dir.display());
            scripts
        }
        _ => {
            info!("No external scripts found, checking for embedded scripts");
            if embedded::has_embedded_scripts() {
                match embedded::extract_embedded_scripts(os_info.os_type()) {
                    Ok(scripts) => {
                        if scripts.is_empty() {
                            warn!("No applicable scripts found in embedded scripts");
                            return Ok(());
                        }
                        info!("Using embedded scripts");
                        scripts
                    }
                    Err(e) => {
                        warn!("Failed to extract embedded scripts: {}", e);
                        return Ok(());
                    }
                }
            } else {
                warn!("No scripts found, neither external nor embedded");
                return Ok(());
            }
        }
    };

    info!("Found {} scripts", scripts.len());
    debug!("Scripts: {:?}", scripts);

    match cli.command.unwrap_or(Commands::Interactive { all: false }) {
        Commands::Interactive { all } => {
            let profile = if let Some(profile_name) = &cli.profile {
                match get_profile_from_name(profile_name) {
                    Some(p) => {
                        info!("Using environment profile: {}", p);
                        Some(p)
                    }
                    None => {
                        warn!(
                            "Unknown profile: {}. Using interactive profile selection.",
                            profile_name
                        );
                        Some(profile_selection_mode()?)
                    }
                }
            } else {
                info!("No environment profile specified.");
                Some(profile_selection_mode()?)
            };
            
            interactive_mode(&scripts, all, profile)?
        },
        Commands::Run {
            scripts: script_names,
        } => {
            let profile = if let Some(profile_name) = &cli.profile {
                match get_profile_from_name(profile_name) {
                    Some(p) => {
                        info!("Using environment profile: {}", p);
                        Some(p)
                    }
                    None => {
                        warn!(
                            "Unknown profile: {}. Using interactive profile selection.",
                            profile_name
                        );
                        Some(profile_selection_mode()?)
                    }
                }
            } else {
                info!("No environment profile specified.");
                Some(profile_selection_mode()?)
            };
            
            run_specified_scripts(&scripts, script_names)?
        },
        Commands::List { format } => list_mode(&scripts, format)?,
    }

    Ok(())
}
