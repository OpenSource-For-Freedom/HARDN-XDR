use std::fs::{self, OpenOptions};
use std::io::{BufReader, BufRead, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::Path;
use std::process::{Command as ProcessCommand, exit};
use std::sync::{Arc, Mutex};
use serde::{Serialize};
use serde_json::{json, Value};
use actix_cors::Cors;
use actix_web::{middleware, web, App, HttpServer};
use std::collections::HashMap;
use rand::{distributions::Alphanumeric, Rng};
use std::os::unix::fs::PermissionsExt;

mod config;
mod file_permissions;
mod gui_api;
mod gui_input;
mod hardn_logging;
mod network_scan;
mod security_checks;
mod security_tools;
mod system_checks;
mod vm_detection;

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

    fn get_active_connections(&self) -> Vec<Connection> {
        vec![
            Connection { ip: "192.168.0.1".into(), port: 22 },
            Connection { ip: "10.0.0.5".into(), port: 443 },
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
    fn get_current_threats(&self) -> ThreatSummary {
        ThreatSummary {
            level: 1,
            items: vec![],
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
struct AuthService {
    tokens: Mutex<HashMap<String, String>>, // Maps tokens to usernames
}

impl AuthService {
    fn new() -> Self {
        Self {
            tokens: Mutex::new(HashMap::new()),
        }
    }

    fn authenticate(&self, username: &str, password: &str) -> AuthResult {
        if username == "admin" && password == "hardn123" {
            let token = self.generate_token(username);
            AuthResult {
                success: true,
                user: Some(username.to_string()),
                message: token,
            }
        } else {
            AuthResult {
                success: false,
                user: None,
                message: "Invalid credentials".into(),
            }
        }
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
            "2025-04-20: Threat level low.".into(),
        ]
    }
}

// Main application state
pub struct AppState {
    auth_service: Mutex<AuthService>,
    network_monitor: Mutex<NetworkMonitor>,
    threat_detector: Mutex<ThreatDetector>,
    log_manager: Mutex<LogManager>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            auth_service: Mutex::new(AuthService::new()),
            network_monitor: Mutex::new(NetworkMonitor::new()),
            threat_detector: Mutex::new(ThreatDetector::new()),
            log_manager: Mutex::new(LogManager::new()),
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
    if !std::os::unix::process::parent_id() == 0 {
        eprintln!("This script must be run as root.");
        exit(1);
    }
}
fn set_executable_permissions(base_dir: &str) {
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

fn monitor_system() {
    // Simplified system monitoring without using notify
    println!("System monitoring started (simplified version)");
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


/* holding for more testing befoe I lock the door completly 
fn lock_down_hardn_files(base_dir: &str) {

    let files = vec![
        format!("{}/setup/setup.sh", base_dir),
        format!("{}/setup/packages.sh", base_dir),
        format!("{}/kernel.c", base_dir),
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

// =================== Main ===================
#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logging
    hardn_logging::init().expect("Failed to initialize logging");
    hardn_logging::log_event("HARDN starting up");

    // Load configuration
    let hardn_config = match config::load_config() {
        Ok(config) => config,
        Err(e) => {
            eprintln!("Error loading configuration: {}", e);
            return Err(std::io::Error::new(std::io::ErrorKind::Other, e));
        }
    };

    // Start security services
    let file_perm_checker = Arc::new(Mutex::new(file_permissions::FilePermissionChecker::new()));
    let network_scanner = Arc::new(Mutex::new(network_scan::NetworkScanner::new()));

    let file_perm_checker_clone = file_perm_checker.clone();
    std::thread::spawn(move || {
        if let Err(e) = file_perm_checker_clone.lock().unwrap().check_all_files() {
            eprintln!("Error checking file permissions: {}", e);
        }
    });

    let network_scanner_clone = network_scanner.clone();
    std::thread::spawn(move || {
        if let Err(e) = network_scanner_clone.lock().unwrap().scan_network() {
            eprintln!("Error scanning network: {}", e);
        }
    });

    // Check for VM environment
    std::thread::spawn(|| {
        match vm_detection::detect_vm() {
            Ok(is_vm) => {
                if is_vm {
                    println!("Running in a virtual machine environment");
                } else {
                    println!("Running on physical hardware");
                }
            }
            Err(e) => eprintln!("Error detecting VM environment: {}", e),
        }
    });

    // Start the HTTP server for GUI API
    hardn_logging::log_event("Starting HTTP server for GUI API");
    println!("Starting HTTP server on {}:{}", hardn_config.api_host, hardn_config.api_port);

    HttpServer::new(move || {
        // Configure CORS with strict security settings
        let cors = Cors::default()
            // In production, specify exact allowed origins instead of any_origin
            .allowed_origin(&hardn_config.allowed_origin) // This should be configured in config.rs
            .allowed_methods(vec!["GET", "POST", "OPTIONS"])
            .allowed_headers(vec!["Authorization", "Content-Type"])
            .expose_headers(vec!["content-length"])
            .max_age(3600);

        App::new()
            .wrap(cors)
            // Add security headers middleware
            .wrap(middleware::DefaultHeaders::new()
                .add(("X-Content-Type-Options", "nosniff"))
                .add(("X-Frame-Options", "DENY"))
                .add(("X-XSS-Protection", "1; mode=block"))
                .add(("Strict-Transport-Security", "max-age=31536000; includeSubDomains"))
                .add(("Content-Security-Policy", "default-src 'self' http://localhost:8000 http://localhost:8080; script-src 'self'; connect-src 'self' http://localhost:8080"))
                .add(("Referrer-Policy", "strict-origin-when-cross-origin"))
                .add(("Cache-Control", "no-store"))
                .add(("Pragma", "no-cache"))
            )
            // Rate limiting middleware would be added here in a production environment
            .app_data(web::Data::new(file_perm_checker.clone()))
            .app_data(web::Data::new(network_scanner.clone()))
            // Configure API routes first
            .configure(gui_api::configure_routes)
            // Configure static files serving
            .configure(gui_api::configure_static_files)
    })
    .bind(format!("{}:{}", hardn_config.api_host, hardn_config.api_port))?
    .run()
    .await
}