use crate::scripts::models::ScriptInfo;
use anyhow::Result;
use std::collections::HashMap;
use std::path::Path;

/// Lists available scripts in various formats
pub fn list_scripts(script_infos: &[ScriptInfo], format: &str) -> Result<()> {
    match format {
        "plain" => {
            for info in script_infos {
                println!("{} [{}]", info.name, info.os_type);
            }
        }
        "json" => {
            let json = serde_json::to_string_pretty(script_infos)?;
            println!("{}", json);
        }
        "csv" => write_scripts_to_csv(script_infos)?,
        "table" => print_scripts_table(),
        _ => return Err(anyhow::anyhow!("Unsupported format: {}", format)),
    }

    Ok(())
}

fn write_scripts_to_csv(script_infos: &[ScriptInfo]) -> Result<(), anyhow::Error> {
    let mut wtr = csv::WriterBuilder::new().from_writer(std::io::stdout());
    wtr.write_record(["Script Name", "OS Type", "Path"])?;
    for info in script_infos {
        wtr.write_record([
            &info.name,
            &info.os_type,
            &info.path.to_string_lossy().to_string(),
        ])?;
    }
    wtr.flush()?;
    Ok(())
}

fn collect_scripts_by_os() -> HashMap<String, Vec<String>> {
    let mut scripts_by_os = HashMap::new();
    let scripts_dir = Path::new("../scripts");

    if let Ok(entries) = std::fs::read_dir(scripts_dir) {
        for entry in entries.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_dir() {
                let os_type = path.file_name().unwrap().to_string_lossy().to_string();
                let mut scripts = Vec::new();

                if let Ok(scripts_entries) = std::fs::read_dir(&path) {
                    for script_entry in scripts_entries.filter_map(Result::ok) {
                        if let Some(name) = script_entry.path().file_name() {
                            scripts.push(name.to_string_lossy().to_string());
                        }
                    }
                }

                scripts.sort();
                scripts_by_os.insert(os_type, scripts);
            }
        }
    }

    scripts_by_os
}

fn print_scripts_table() {
    let scripts_by_os = collect_scripts_by_os();
    let mut os_types: Vec<&String> = scripts_by_os.keys().collect();
    os_types.sort();

    let column_width = print_table_headers(&os_types);
    let max_scripts = scripts_by_os.values().map(|v| v.len()).max().unwrap_or(0);

    for i in 0..max_scripts {
        for os_type in &os_types {
            if let Some(scripts) = scripts_by_os.get(*os_type) {
                if i < scripts.len() {
                    print!("{:<width$}", scripts[i], width = column_width);
                } else {
                    print!("{:<width$}", "", width = column_width);
                }
            } else {
                print!("{:<width$}", "", width = column_width);
            }
        }
        println!();
    }
}

fn print_table_headers(os_types: &Vec<&String>) -> usize {
    let column_width = 30;
    for os_type in os_types {
        print!("{:<width$}", os_type, width = column_width);
    }
    println!();
    for _ in os_types {
        print!("{:-<width$}", "", width = column_width);
    }
    println!();
    column_width
}
