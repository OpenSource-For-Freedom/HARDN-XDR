use std::fs::OpenOptions;
use std::io::Write;
use chrono::Local;

// Log an event to the HARDN log file
pub fn log_event(message: &str) {
    let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    let log_entry = format!("[{}] {}\n", timestamp, message);

    println!("{}", log_entry);

    // In a production environment, write to a log file
    if let Ok(mut file) = OpenOptions::new()
        .create(true)
        .append(true)
        .open("/var/log/hardn_gui.log")
    {
        let _ = file.write_all(log_entry.as_bytes());
    }
}