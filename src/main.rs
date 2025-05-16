use std::fs::{self, OpenOptions};
use std::io::{BufReader, BufRead, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::Path;
use std::process::{Command as ProcessCommand, exit};
use std::sync::{mpsc::channel, Arc, Mutex};
use std::time::{Duration, Instant};
use serde::{Serialize};
use serde_json::{json, Value};
use actix_web::{web, App, HttpServer};
use std::collections::HashMap;
use rand::{distributions::Alphanumeric, Rng};
use notify::{Watcher, RecursiveMode};

use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2, Algorithm, Version, Params
};

mod gui_input;
mod hardn_logging;
mod gui_api;
mod setup;

//mod r#main_func
// use for unit testing
// mod main_auth_srv;

#[cfg(test)]
mod test {
    pub mod network_monitor_tests;
}

mod setup;


// =================== Constants ===================
const LOG_FILE: &str = "/var/log/hardn.log";
const SYSTEMD_UNIT: &str = "/etc/systemd/system/hardn.service";

// =================== GUI Modules ===================
#[derive(Serialize)]
struct Connection {
    ip: String,
    port: u16,

}

struct NetworkMonitor;
impl NetworkMonitor {
    fn new() -> Self { Self }

    fn start_monitoring(&self) {
        println!("[+] Monitoring network...");
        loop {
            for _ in 0..10 {
                std::thread::sleep(Duration::from_secs(30));
            }
        }
    }

    fn get_active_connections(&self) -> Vec<Connection> {
        vec![
            Connection { ip: "192.168.0.1".into(), port: 22 },
            Connection { ip: "10.0.0.5".into(), port: 443 },
            Connection { ip: "172.16.0.1".into(), port: 80 },
            Connection { ip: "172.16.0.2".into(), port: 8080 },
        ]
    }
}

#[derive(Serialize)]
struct Threat {
    id: u32,
    description: String,
    level: u8,
}
#[derive(Serialize)]
struct ThreatSummary {
    level: u8,
    items: Vec<Threat>,
}
struct ThreatDetector;
impl ThreatDetector {
    fn new() -> Self { Self }
    fn watch_threats(&self) {
        println!("[+] Threat detection started...");
        for _ in 0..10 {
            std::thread::sleep(Duration::from_secs(60));
        }
        println!("[+] Threat detection completed.");
    }
    fn get_current_threats(&self) -> ThreatSummary {
        ThreatSummary {
            level: 3,
            items: vec![
                Threat { id: 1, description: "Suspicious SSH login".into(), level: 2 },
            ],
        }
    }
}

#[derive(Serialize)]
struct AuthResponse {
    success: bool,
    user: Option<String>,
    message: String,
}
struct AuthResult {
    success: bool,
    user: Option<String>,
    message: String,
}

struct AuthAttempt {
    attempts: u32,
    last_attempt: Instant,
}

struct AuthService {
    tokens: Mutex<HashMap<String, String>>,                  // Maps tokens to usernames
    credentials: Mutex<HashMap<String, String>>,             // Maps usernames to hashed passwords
    failed_attempts: Mutex<HashMap<String, AuthAttempt>>,    // Tracks failed login attempts
}

impl AuthService {
    fn new() -> Self {
        // Initialize with a securely hashed default admin password
        let mut credentials = HashMap::new();

        // Pre-hash the default password (in production, this would be set during installation)
        let salt = generate_salt();
        let hashed_password = hash_password("hardn123", &salt);
        credentials.insert("admin".to_string(), hashed_password);

        Self {
            tokens: Mutex::new(HashMap::new()),
            credentials: Mutex::new(credentials),
            failed_attempts: Mutex::new(HashMap::new()),
        }
    }

    fn authenticate(&self, username: &str, password: &str) -> AuthResult {
        // Rate limiting check
        if self.is_rate_limited(username) {
            return AuthResult {
                success: false,
                user: None,
                message: "Too many failed attempts. Please try again later.".into(),
            };
        }

        // Get stored credentials
        let credentials = self.credentials.lock().unwrap();

        // Check if user exists and verify password
        match credentials.get(username) {
            Some(stored_hash) => {
                if verify_password(password, stored_hash) {
                    // Reset failed attempts on success
                    self.reset_failed_attempts(username);

                    // Generate authentication token
                    let token = self.generate_token(username);

                    AuthResult {
                        success: true,
                        user: Some(username.to_string()),
                        message: token,
                    }
                } else {
                    // Record failed attempt
                    self.record_failed_attempt(username);

                    AuthResult {
                        success: false,
                        user: None,
                        message: "Invalid credentials".into(),
                    }
                }
            },
            None => {
                // Still record the attempt to prevent username enumeration
                self.record_failed_attempt(username);

                AuthResult {
                    success: false,
                    user: None,
                    message: "Invalid credentials".into(),
                }
            }
        }
    }

    // Record a failed login attempt
    fn record_failed_attempt(&self, username: &str) {
        let mut attempts = self.failed_attempts.lock().unwrap();

        let entry = attempts.entry(username.to_string()).or_insert(AuthAttempt {
            attempts: 0,
            last_attempt: Instant::now(),
        });

        entry.attempts += 1;
        entry.last_attempt = Instant::now();
    }

    // Reset failed attempts counter
    fn reset_failed_attempts(&self, username: &str) {
        let mut attempts = self.failed_attempts.lock().unwrap();
        attempts.remove(username);
    }

    // Check if user is rate limited
    fn is_rate_limited(&self, username: &str) -> bool {
        let attempts = self.failed_attempts.lock().unwrap();

        if let Some(attempt) = attempts.get(username) {
            // Define rate limiting tiers
            let rate_limits = [
                (10, 300), // 10+ attempts: wait 5 minutes (300 seconds)
                (5, 30),   // 5-9 attempts: wait 30 seconds
                (3, 5),    // 3-4 attempts: wait 5 seconds
            ];

            let elapsed = attempt.last_attempt.elapsed();

            // Check each tier in descending order of severity
            for &(attempt_threshold, wait_time) in &rate_limits {
                if attempt.attempts >= attempt_threshold && elapsed < Duration::from_secs(wait_time) {
                    return true;
                }
            }
        }

        false
    }

    // Add a new user (for admin functionality)
    fn add_user(&self, username: &str, password: &str) -> bool {
        let mut credentials = self.credentials.lock().unwrap();

        if credentials.contains_key(username) {
            return false; // User already exists
        }

        let salt = generate_salt();
        let hashed_password = hash_password(password, &salt);
        credentials.insert(username.to_string(), hashed_password);

        true
    }

    // Change a user's password
    fn change_password(&self, username: &str, old_password: &str, new_password: &str) -> bool {
        let mut credentials = self.credentials.lock().unwrap();

        if let Some(stored_hash) = credentials.get(username) {
            if verify_password(old_password, stored_hash) {
                let salt = generate_salt();
                let new_hash = hash_password(new_password, &salt);
                credentials.insert(username.to_string(), new_hash);
                return true;
            }
        }

        false
    }

    fn generate_token(&self, username: &str) -> String {
        let token: String = rand::thread_rng()
            .sample_iter(&Alphanumeric)
            .take(30)
            .map(char::from)
            .collect();

        self.tokens.lock().unwrap().insert(token.clone(), username.to_string());
        token
    }

    fn validate_token(&self, token: &str) -> bool {
        self.tokens.lock().unwrap().contains_key(token)
    }
}

#[derive(Serialize)]
struct LogManager;
impl LogManager {
    fn new() -> Self { Self }
    fn get_recent_logs(&self) -> Vec<String> {
        vec![
            "2025-04-20: System initialized.".into(),
            "2025-04-20: Threat level warning.".into(),
        ]
    }
}

struct AppState {
    auth_service: Arc<Mutex<AuthService>>,
    network_monitor: Arc<Mutex<NetworkMonitor>>,
    threat_detector: Arc<Mutex<ThreatDetector>>,
    log_manager: Arc<Mutex<LogManager>>,
}
impl AppState {
    fn new() -> Self {
        Self {
            auth_service: Arc::new(Mutex::new(AuthService::new())),
            network_monitor: Arc::new(Mutex::new(NetworkMonitor::new())),
            threat_detector: Arc::new(Mutex::new(ThreatDetector::new())),
            log_manager: Arc::new(Mutex::new(LogManager::new())),
        }
    }
}

// =================== IPC Server ===================
fn handle_ipc_request(stream: UnixStream, state: &AppState) {
    let reader = BufReader::new(&stream);
    for line in reader.lines() {
        if let Ok(text) = line {
            let req: Value = serde_json::from_str(&text).unwrap_or(json!({}));
            let response = match req["action"].as_str() {
                Some("auth") => {
                    let username = req["username"].as_str().unwrap_or_default();
                    let password = req["password"].as_str().unwrap_or_default();
                    let result = state.auth_service.lock().unwrap().authenticate(username, password);
                    json!(AuthResponse {
                        success: result.success,
                        user: result.user,
                        message: result.message,
                    })
                }
                Some("network") => {
                    let conns = state.network_monitor.lock().unwrap().get_active_connections();
                    json!(conns)
                }
                Some("threats") => {
                    let threats = state.threat_detector.lock().unwrap().get_current_threats();
                    json!(threats)
                }
                Some("logs") => {
                    let logs = state.log_manager.lock().unwrap().get_recent_logs();
                    json!(logs)
                }
                _ => json!({ "error": "Invalid action" }),
            };
            writeln!(&stream, "{}", response.to_string()).unwrap();
        }
    }
}

fn start_ipc_server(state: Arc<AppState>) {
    let socket_path = "/tmp/hardn.sock";
    let _ = std::fs::remove_file(socket_path);
    let listener = UnixListener::bind(socket_path).expect("Failed to bind IPC socket");
    println!("[+] IPC server started at {}", socket_path);

    for stream in listener.incoming() {
        if let Ok(stream) = stream {
            let state = Arc::clone(&state);
            std::thread::spawn(move || {
                handle_ipc_request(stream, &state);
            });
        }
    }
}
// =================== Orchetration ===================
fn validate_environment() {
    if !nix::unistd::Uid::effective().is_root() {
        eprintln!("This script must be run as root.");
        exit(1);
    }
}
fn set_executable_permissions(base_dir: &str) {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::path::Path;

    let files = vec![
        format!("{}/src/setup/setup.sh", base_dir),
        format!("{}/src/setup/packages.sh", base_dir),
        format!("{}/src/gui/main.py", base_dir),
    ];

    for file in files {
        if Path::new(&file).exists() {
            let mut permissions = fs::metadata(&file).unwrap().permissions();
            permissions.set_mode(0o755); // Read, write, and execute for owner; read and execute for group and others
            fs::set_permissions(&file, permissions).unwrap();
            println!("[+] Set executable permissions for: {}", file);
        } else {
            println!("[!] File not found: {}", file);
        }
    }
}
fn run_script(script_name: &str) {
    if !Path::new(script_name).exists() {
        eprintln!("Script not found: {}", script_name);
        exit(1);
    }
    let status = match ProcessCommand::new("/bin/bash").arg(script_name).status() {
        Ok(status) => status,
        Err(e) => {
            eprintln!("Failed to execute script {}: {}", script_name, e);
            exit(1);
        }
    };
    if !status.success() {
        eprintln!("Script failed: {}", script_name);
        exit(1);
    }
}

// Removed run_kernel function

fn launch_gui(base_dir: &str) {
    let gui_file = format!("{}/gui/main.py", base_dir);
    let status = ProcessCommand::new("python3").arg(&gui_file).status().unwrap();
    if !status.success() {
        eprintln!("GUI failed to launch");
        exit(1);
    }
}

use std::sync::mpsc::{Sender, Receiver};


fn monitor_system() {
    let (tx, rx): (Sender<String>, Receiver<String>) = channel();

    // Create watcher with simplified event handling
    let mut watcher = match setup_file_watcher(tx) {
        Ok(w) => w,
        Err(e) => {
            eprintln!("Failed to create file watcher: {}", e);
            return;
        }
    };

    // Configure directories to monitor
    configure_watch_directories(&mut watcher);

    // Process events from the channel
    process_file_events(rx);
}
// Handle file system events and filter for security-relevant changes
fn handle_file_event(event: &notify::Event, tx: &Sender<String>) {
    use notify::EventKind;

    // Filter for relevant events
    match event.kind {
        EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_) => {
            // Get paths affected by this event
            let paths: Vec<String> = event.paths.iter()
                .map(|path| path.to_string_lossy().to_string())
                .collect();

            // Skip temporary files and other noise
            if paths.iter().any(|p| {
                p.contains(".swp") || p.contains(".tmp") || p.contains("~") ||
                p.contains(".cache") || p.contains("/proc/")
            }) {
                return;
            }

            // Format a message about the event
            let event_type = match event.kind {
                EventKind::Create(_) => "Created",
                EventKind::Modify(_) => "Modified",
                EventKind::Remove(_) => "Removed",
                _ => "Accessed",
            };

            let message = format!(
                "[SECURITY] {} file(s): {}",
                event_type,
                paths.join(", ")
            );

            // Send the message through the channel
            tx.send(message).unwrap_or_default();
        },
        _ => {}, // Ignore other event types
    }
}

// Set up the file watcher with event filtering
fn setup_file_watcher(tx: Sender<String>) -> Result<impl Watcher, notify::Error> {
    notify::recommended_watcher(move |res| {
        match res {
            Ok(event) => handle_file_event(&event, &tx),
            Err(e) => {
                let error_msg = format!("Watch error: {:?}", e);
                tx.send(error_msg.clone()).unwrap_or_default();
                eprintln!("{}", error_msg);
            },
        }
    })
}

// Configure which directories to watch
fn configure_watch_directories(watcher: &mut impl Watcher) {
    let security_dirs = [
        "/etc",
        "/var/log",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/home"
    ];

    println!("[+] Setting up system monitoring for security-relevant directories");

    for dir in security_dirs {
        if Path::new(dir).exists() {
            match watcher.watch(Path::new(dir), RecursiveMode::Recursive) {
                Ok(_) => println!("[+] Monitoring directory: {}", dir),
                Err(e) => eprintln!("Failed to watch {}: {}", dir, e),
            }
        }
    }

    println!("[+] System monitoring active");
}

// Process events from the channel
fn process_file_events(rx: Receiver<String>) {
    loop {
        match rx.recv() {
            Ok(event) => {
                println!("{}", event);
                log_message(&event);
            },
            Err(e) => {
                let error = format!("Channel error in monitor_system: {:?}", e);
                eprintln!("{}", error);
                log_message(&error);
                break;
            }
        }
    }
}

fn create_systemd_service(exec_path: &str) {
    let unit = format!(
        "[Unit]\nDescription=HARDN Service\n[Service]\nExecStart={} --all\n[Install]\nWantedBy=multi-user.target\n",
        exec_path
    );
    let mut file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(SYSTEMD_UNIT)
        .unwrap();
    file.write_all(unit.as_bytes()).unwrap();
    ProcessCommand::new("systemctl").args(["daemon-reload"]).status().ok();
    ProcessCommand::new("systemctl").args(["enable", "--now", "hardn.service"]).status().ok();
}

fn install_systemd_timers(base_dir: &str) {
    let timers = [
        ("hardn-packages", format!("{}/setup/packages.sh", base_dir)),
    ];
    for (name, path) in timers.iter() {
        fs::write(
            format!("/etc/systemd/system/{}.service", name),
            format!("[Unit]\n[Service]\nExecStart={}", path),
        )
        .unwrap();
        fs::write(
            format!("/etc/systemd/system/{}.timer", name),
            "[Timer]\nOnCalendar=daily\n[Install]\nWantedBy=timers.target\n",
        )
        .unwrap();
        ProcessCommand::new("systemctl")
            .args(["enable", "--now", &format!("{}.timer", name)])
            .status()
            .ok();
    }
}

fn remove_systemd_timers() {
    for name in ["hardn-packages"] {
        ProcessCommand::new("systemctl")
            .args(["disable", "--now", &format!("{}.timer", name)])
            .status()
            .ok();
        fs::remove_file(format!("/etc/systemd/system/{}.timer", name)).ok();
        fs::remove_file(format!("/etc/systemd/system/{}.service", name)).ok();
    }
    ProcessCommand::new("systemctl").arg("daemon-reload").status().ok();
}


/* holding for more testing before I lock the door completely
fn lock_down_hardn_files(base_dir: &str) {

    let files = vec![
        format!("{}/setup/setup.sh", base_dir),
        format!("{}/setup/packages.sh", base_dir),
       // format!("{}/kernel.c", base_dir), <- file has been removed
        format!("{}/gui/main.py", base_dir),
        format!("{}/src/hardn.rs", base_dir),
    ];

    for file in files {
        if Path::new(&file).exists() {
            let mut permissions = fs::metadata(&file).unwrap().permissions();
            permissions.set_mode(0o444); // Read-only for all users, including root
            fs::set_permissions(&file, permissions).unwrap();
            println!("[+] Set read-only permissions for: {}", file);
        } else {
            println!("[!] File not found: {}", file);
        }
    }

    let main_file = format!("{}/src/main.rs", base_dir);
    if Path::new(&main_file).exists() {
        let mut permissions = fs::metadata(&main_file).unwrap().permissions();
        permissions.set_mode(0o555); // Read and execute for all users, including root
        fs::set_permissions(&main_file, permissions).unwrap();
        println!("[+] Set read and execute permissions for: {}", main_file);
    } else {
        println!("[!] Main file not found: {}", main_file);
    }
}
*/
//}

fn log_message(message: &str) {
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(LOG_FILE)
        .expect("Failed to open log file");
    writeln!(file, "{}", message).expect("Failed to write to log file");
}

// Helper functions for password hashing
fn generate_salt() -> String {
    // Generate a random salt
    let salt = SaltString::generate(&mut OsRng);
    salt.as_str().to_string()
}


fn hash_password(password: &str, salt: &str) -> String {
    // Create an Argon2 instance with default parameters
    let argon2 = Argon2::new(
        Algorithm::Argon2id,
        Version::V0x13,
        Params::new(65536, 3, 4, None).unwrap()
    );

    // Use the provided salt string
    let salt = SaltString::from_b64(salt).unwrap();

    // Hash the password
    let password_hash = argon2.hash_password(password.as_bytes(), &salt)
        .unwrap()
        .to_string();

    password_hash
}

fn verify_password(password: &str, hash: &str) -> bool {
    // Parse the hash string
    let parsed_hash = match PasswordHash::new(hash) {
        Ok(hash) => hash,
        Err(_) => return false,
    };

    // Verify the password against the hash
    Argon2::default().verify_password(password.as_bytes(), &parsed_hash).is_ok()
}

// =================== Main ===================
#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize application state
    let app_state = Arc::new(Mutex::new(AppState::new()));

// Launch the GUI
println!("[+] Starting HARDN system...");
    gui_api::launch_gui();

    // Start REST API server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(app_state.clone()))
            .configure(gui_api::configure_routes)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}