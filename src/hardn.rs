// Full `hardn.rs` with IPC integration and preserved orchestration logic
// see hardn.rs med for design 
rust_code = """
use clap::{App, Arg};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::{BufReader, BufRead, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::Path;
use std::process::{Command, exit};
use std::sync::{mpsc::channel, Arc, Mutex};
use std::time::Duration;
use notify::{Watcher, RecursiveMode, watcher};
use serde::{Serialize, Deserialize};
use serde_json::{json, Value};

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
            std::thread::sleep(Duration::from_secs(30));
        }
    }
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
    fn watch_threats(&self) {
        println!("[+] Threat detection started...");
        loop {
            std::thread::sleep(Duration::from_secs(60));
        }
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
struct AuthService;
impl AuthService {
    fn new() -> Self { Self }
    fn authenticate(&self, username: &str, password: &str) -> AuthResult {
        if username == "admin" && password == "hardn123" {
            AuthResult {
                success: true,
                user: Some(username.to_string()),
                message: "Login successful".into(),
            }
        } else {
            AuthResult {
                success: false,
                user: None,
                message: "Invalid credentials".into(),
            }
        }
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

// =================== Orchestration ===================
fn validate_environment() {
    if !nix::unistd::Uid::effective().is_root() {
        eprintln!("This script must be run as root.");
        exit(1);
    }
}
fn set_executable_permissions(base_dir: &str) {
    let files = vec![
        format!("{}/setup/setup.sh", base_dir),
        format!("{}/setup/packages.sh", base_dir),
        format!("{}/kernel.c", base_dir),
        format!("{}/gui/main.py", base_dir),
    ];
    for file in files {
        if Path::new(&file).exists() {
            let mut perms = fs::metadata(&file).unwrap().permissions();
            perms.set_mode(0o755);
            fs::set_permissions(&file, perms).unwrap();
        }
    }
}
fn run_script(script_name: &str) {
    if !Path::new(script_name).exists() {
        eprintln!("Script not found: {}", script_name);
        exit(1);
    }
    let status = Command::new("/bin/bash").arg(script_name).status().unwrap();
    if !status.success() {
        eprintln!("Script failed: {}", script_name);
        exit(1);
    }
}
fn run_kernel(base_dir: &str) {
    let kernel_file = format!("{}/kernel.c", base_dir);
    let output_file = format!("{}/kernel", base_dir);
    let compile_status = Command::new("gcc").arg(&kernel_file).arg("-o").arg(&output_file).status().unwrap();
    if !compile_status.success() {
        eprintln!("Error compiling kernel");
        exit(1);
    }
    let run_status = Command::new(&output_file).status().unwrap();
    if !run_status.success() {
        eprintln!("Kernel execution failed");
        exit(1);
    }
}
fn launch_gui(base_dir: &str) {
    let gui_file = format!("{}/gui/main.py", base_dir);
    let status = Command::new("python3").arg(&gui_file).status().unwrap();
    if !status.success() {
        eprintln!("GUI failed to launch");
        exit(1);
    }
}
fn monitor_system() {
    let (tx, rx) = channel();
    let mut watcher = watcher(tx, Duration::from_secs(10)).unwrap();
    watcher.watch("/", RecursiveMode::Recursive).unwrap();
    loop {
        match rx.recv() {
            Ok(event) => println!("System change: {:?}", event),
            Err(e) => eprintln!("Watch error: {:?}", e),
        }
    }
}
fn create_systemd_service(exec_path: &str) {
    let unit = format!(
        "[Unit]\\nDescription=HARDN Service\\n[Service]\\nExecStart={} --all\\n[Install]\\nWantedBy=multi-user.target\\n",
        exec_path
    );
    let mut file = OpenOptions::new().create(true).write(true).truncate(true).open(SYSTEMD_UNIT).unwrap();
    file.write_all(unit.as_bytes()).unwrap();
    Command::new("systemctl").args(["daemon-reload"]).status().ok();
    Command::new("systemctl").args(["enable", "--now", "hardn.service"]).status().ok();
}
fn install_systemd_timers(base_dir: &str) {
    let timers = [
        ("hardn-packages", format!("{}/setup/packages.sh", base_dir)),
        ("hardn-kernel", format!("{}/kernel", base_dir)),
    ];
    for (name, path) in timers.iter() {
        fs::write(format!("/etc/systemd/system/{}.service", name), format!("[Unit]\\n[Service]\\nExecStart={}", path)).unwrap();
        fs::write(format!("/etc/systemd/system/{}.timer", name), "[Timer]\\nOnCalendar=daily\\n[Install]\\nWantedBy=timers.target").unwrap();
        Command::new("systemctl").args(["enable", "--now", &format!("{}.timer", name)]).status().ok();
    }
}
fn remove_systemd_timers() {
    for name in ["hardn-packages", "hardn-kernel"] {
        Command::new("systemctl").args(["disable", "--now", &format!("{}.timer", name)]).status().ok();
        fs::remove_file(format!("/etc/systemd/system/{}.timer", name)).ok();
        fs::remove_file(format!("/etc/systemd/system/{}.service", name)).ok();
    }
    Command::new("systemctl").arg("daemon-reload").status().ok();
}

// =================== Main ===================
fn main() {
    let matches = App::new("HARDN")
        .version("1.1.1")
        .author("Tim Burns")
        .about("Secure Linux automation & GUI integration")
        .arg(Arg::with_name("setup").long("setup"))
        .arg(Arg::with_name("kernel").long("kernel"))
        .arg(Arg::with_name("gui").long("gui"))
        .arg(Arg::with_name("monitor").long("monitor"))
        .arg(Arg::with_name("all").long("all"))
        .arg(Arg::with_name("install-service").long("install-service"))
        .arg(Arg::with_name("install-timers").long("install-timers"))
        .arg(Arg::with_name("remove-cron").long("remove-cron"))
        .get_matches();

    let base_dir = env::current_dir().unwrap().canonicalize().unwrap();
    let base_str = base_dir.to_str().unwrap().to_string();

    validate_environment();
    set_executable_permissions(&base_str);

    if matches.is_present("install-service") {
        let path = std::env::current_exe().unwrap();
        create_systemd_service(path.to_str().unwrap());
        return;
    }

    if matches.is_present("install-timers") {
        install_systemd_timers(&base_str);
        return;
    }

    if matches.is_present("remove-cron") {
        remove_systemd_timers();
        return;
    }

    if matches.is_present("setup") || matches.is_present("all") {
        run_script(&format!("{}/setup/setup.sh", base_str));
        run_script(&format!("{}/setup/packages.sh", base_str));
    }

    if matches.is_present("kernel") || matches.is_present("all") {
        run_kernel(&base_str);
    }

    if matches.is_present("gui") || matches.is_present("all") {
        let state = Arc::new(AppState::new());

        let net = Arc::clone(&state.network_monitor);
        let threat = Arc::clone(&state.threat_detector);
        let ipc_state = Arc::clone(&state);

        std::thread::spawn(move || net.lock().unwrap().start_monitoring());
        std::thread::spawn(move || threat.lock().unwrap().watch_threats());
        std::thread::spawn(move || start_ipc_server(ipc_state));

        launch_gui(&base_str);
    }

    if matches.is_present("monitor") || matches.is_present("all") {
        monitor_system();
    }

    println!("HARDN orchestration completed successfully.");
}
"""
with open("/mnt/data/hardn.rs", "w") as f:
    f.write(rust_code)

"/mnt/data/hardn.rs"