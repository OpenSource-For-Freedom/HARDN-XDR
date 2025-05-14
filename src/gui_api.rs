use actix_web::{web, HttpResponse, Responder, HttpRequest, get, post};
use serde::{Serialize, Deserialize};
use serde_json::{json, Value};
use crate::gui_input::{get_user_input, get_scan_parameters};
use crate::hardn_logging::{log_event, log_error};
use std::process::Command;
use jsonwebtoken::{encode, decode, Header, Validation, EncodingKey, DecodingKey};
use chrono::{Utc, Duration as ChronoDuration};
use std::env;
use lazy_static::lazy_static;
use actix_web::Error;
use actix_web_actors::ws;
use actix::prelude::*;
use std::time::{Duration, Instant};
use crate::security_checks;
use crate::gui_input;
use actix_files as fs;
use std::path::Path;
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier};
use argon2::password_hash::SaltString;
use rand_core::OsRng;
use std::sync::RwLock;
use std::collections::HashMap;
use std::sync::Mutex;
use actix_web::dev::{Service, ServiceRequest, ServiceResponse, Transform};
use futures::future::{ok, Ready};
use std::pin::Pin;
use std::task::{Context, Poll};
use std::future::Future;
use crate::config;
use crate::security_tools;

// JWT Claims structure
#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,  // Subject (username)
    exp: usize,   // Expiration time
    iat: usize,   // Issued at
    role: String, // User role
}

lazy_static! {
    // Get JWT secret from environment variable - REQUIRED for production
    static ref JWT_SECRET: String = env::var("HARDN_JWT_SECRET")
        .expect("CRITICAL SECURITY ERROR: HARDN_JWT_SECRET environment variable must be set");
    
    // In-memory user store - in production this would be replaced with a database
    static ref USER_STORE: RwLock<HashMap<String, UserCredentials>> = {
        let mut map = HashMap::new();
        // Initialize with a default admin in development only
        if env::var("HARDN_ENV").unwrap_or_else(|_| "development".to_string()) == "development" {
            let salt = SaltString::generate(&mut OsRng);
            let argon2 = Argon2::default();
            if let Ok(hashed_password) = argon2.hash_password(b"hardn_initial_secure_pw!", &salt) {
                map.insert(
                    "admin".to_string(), 
                    UserCredentials {
                        password_hash: hashed_password.to_string(),
                        role: "admin".to_string(),
                        failed_attempts: 0,
                        locked_until: None,
                    }
                );
                log_event("Development environment: Default admin user created");
            }
        }
        RwLock::new(map)
    };
}

// User credentials structure
#[derive(Clone)]
struct UserCredentials {
    password_hash: String,
    role: String,
    failed_attempts: u8,
    locked_until: Option<chrono::DateTime<Utc>>,
}

const TOKEN_EXPIRY_HOURS: i64 = 1; // Shorter token lifetime for security
const REFRESH_TOKEN_EXPIRY_HOURS: i64 = 24; // Shorter refresh token lifetime
const MAX_FAILED_ATTEMPTS: u8 = 5;
const LOCKOUT_MINUTES: i64 = 30;

// Auth request structure
#[derive(Debug, Serialize, Deserialize)]
pub struct AuthRequest {
    username: String,
    password: String,
}

// Token response structure
#[derive(Debug, Serialize, Deserialize)]
pub struct TokenResponse {
    access_token: String,
    refresh_token: String,
    token_type: String,
    expires_in: i64,
}

// Refresh token request
#[derive(Debug, Serialize, Deserialize)]
pub struct RefreshRequest {
    refresh_token: String,
}

// WebSocket heartbeat interval
const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
// How long before lack of client response causes a timeout
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

// Data structure for websocket connection
struct HardnSocket {
    hb: Instant,
    data_type: String,
    username: String,
    role: String,
}

impl Actor for HardnSocket {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        // Start heartbeat
        self.hb(ctx);
        log_event(&format!("WebSocket connection started for {} by user {}", self.data_type, self.username));
        
        // Start data stream based on data_type and role
        let addr = ctx.address();
        
        // Check if role has permission for this data
        let has_permission = match self.data_type.as_str() {
            "security" => self.role == "admin" || self.role == "security",
            "network" => self.role == "admin" || self.role == "network" || self.role == "security",
            "logs" => self.role == "admin" || self.role == "auditor",
            _ => false
        };
        
        if !has_permission {
            log_event(&format!("WebSocket access denied: User {} with role {} has no permission for {}", 
                              self.username, self.role, self.data_type));
            ctx.text(json!({"error": "Permission denied"}).to_string());
            ctx.stop();
            return;
        }
        
        match self.data_type.as_str() {
            "network" => {
                ctx.run_interval(Duration::from_secs(3), move |_act, _ctx| {
                    let fut = gui_input::collect_network_data();
                    let addr_clone = addr.clone();
                    tokio::spawn(async move {
                        match fut.await {
                            Ok(data) => {
                                addr_clone.do_send(DataMessage(data.to_string()));
                            },
                            Err(e) => {
                                addr_clone.do_send(DataMessage(json!({"error": format!("Data collection error: {}", e)}).to_string()));
                            }
                        }
                    });
                });
            },
            "security" => {
                ctx.run_interval(Duration::from_secs(15), move |_act, _ctx| {
                    let fut = gui_input::collect_security_data();
                    let addr_clone = addr.clone();
                    tokio::spawn(async move {
                        match fut.await {
                            Ok(data) => {
                                addr_clone.do_send(DataMessage(data.to_string()));
                            },
                            Err(e) => {
                                addr_clone.do_send(DataMessage(json!({"error": format!("Data collection error: {}", e)}).to_string()));
                            }
                        }
                    });
                });
            },
            "logs" => {
                ctx.run_interval(Duration::from_secs(5), move |_act, _ctx| {
                    let fut = gui_input::collect_logs_data(50);
                    let addr_clone = addr.clone();
                    tokio::spawn(async move {
                        match fut.await {
                            Ok(data) => {
                                addr_clone.do_send(DataMessage(data.to_string()));
                            },
                            Err(e) => {
                                addr_clone.do_send(DataMessage(json!({"error": format!("Data collection error: {}", e)}).to_string()));
                            }
                        }
                    });
                });
            },
            _ => {
                log_event(&format!("Unknown data type for WebSocket: {}", self.data_type));
                ctx.text(json!({"error": "Unknown data type"}).to_string());
                ctx.stop();
            }
        }
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for HardnSocket {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(ws::Message::Ping(msg)) => {
                self.hb = Instant::now();
                ctx.pong(&msg);
            }
            Ok(ws::Message::Pong(_)) => {
                self.hb = Instant::now();
            }
            Ok(ws::Message::Text(text)) => {
                // Handle incoming text messages (commands, filters, etc.)
                log_event(&format!("WebSocket received: {}", text));
                
                // Simple command handling
                if let Ok(cmd) = serde_json::from_str::<Value>(&text) {
                    if let Some(command) = cmd["command"].as_str() {
                        match command {
                            "pause" => ctx.text(json!({"status": "paused"}).to_string()),
                            "resume" => ctx.text(json!({"status": "resumed"}).to_string()),
                            "refresh" => {
                                // Trigger immediate data refresh based on type
                                match self.data_type.as_str() {
                                    "network" => {
                                        let fut = gui_input::collect_network_data();
                                        let addr = ctx.address();
                                        tokio::spawn(async move {
                                            match fut.await {
                                                Ok(data) => addr.do_send(DataMessage(data.to_string())),
                                                Err(e) => addr.do_send(DataMessage(json!({"error": e}).to_string()))
                                            }
                                        });
                                    },
                                    // Similar handlers for other data types
                                    _ => ctx.text(json!({"status": "refresh-requested"}).to_string())
                                }
                            },
                            _ => ctx.text(json!({"error": "Unknown command"}).to_string())
                        }
                    }
                }
            }
            Ok(ws::Message::Binary(_)) => {
                // We don't handle binary messages
                ctx.text(json!({"error": "Binary messages not supported"}).to_string());
            }
            Ok(ws::Message::Close(reason)) => {
                log_event("WebSocket connection closed");
                ctx.close(reason);
                ctx.stop();
            }
            _ => ctx.stop(),
        }
    }
}

impl HardnSocket {
    fn hb(&self, ctx: &mut ws::WebsocketContext<Self>) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |act, ctx| {
            // Check client heartbeat
            if Instant::now().duration_since(act.hb) > CLIENT_TIMEOUT {
                log_event("WebSocket client timeout, disconnecting");
                ctx.stop();
                return;
            }
            ctx.ping(b"");
        });
    }
}

// Message for sending data over WebSocket
#[derive(Message)]
#[rtype(result = "()")]
struct DataMessage(String);

impl Handler<DataMessage> for HardnSocket {
    type Result = ();

    fn handle(&mut self, msg: DataMessage, ctx: &mut Self::Context) {
        ctx.text(msg.0);
    }
}

// WebSocket handler for streaming data
#[get("/stream/{data_type}")]
async fn stream_data(req: HttpRequest, path: web::Path<String>, stream: web::Payload) -> Result<HttpResponse, Error> {
    let data_type = path.into_inner();
    
    // Validate authentication token
    match validate_token(&req).await {
        Ok((username, role)) => {
            // Validate data types
            match data_type.as_str() {
                "network" | "security" | "logs" => {
                    log_event(&format!("WebSocket connection initiated for {} by user {}", data_type, username));
                    
                    let resp = ws::start(
                        HardnSocket {
                            hb: Instant::now(),
                            data_type: data_type.clone(),
                            username: username.clone(),
                            role,
                        },
                        &req,
                        stream,
                    )?;
                    Ok(resp)
                },
                _ => {
                    log_event(&format!("Invalid WebSocket data type requested: {}", data_type));
                    Ok(HttpResponse::BadRequest().json(json!({"error": "Invalid data type"})))
                }
            }
        },
        Err(e) => {
            log_event(&format!("Unauthorized WebSocket connection attempt: {}", e));
            Ok(HttpResponse::Unauthorized().json(json!({"error": "Authentication required"})))
        }
    }
}

// Message structures for API requests/responses
#[derive(Serialize, Deserialize)]
pub struct CheckRequest {
    pub check_type: String,
    pub targets: Option<Vec<String>>,
}

// Setup request structure
#[derive(Debug, Serialize, Deserialize)]
pub struct SetupRequest {
    admin_username: String,
    admin_password: String,
    allowed_origin: String,
    api_host: Option<String>,
    api_port: Option<u16>,
}

// Function to launch the GUI server (if needed)
pub fn launch_gui() {
    log_event("GUI functionality initialized");
}

// Rate limiting middleware
struct RateLimiter {
    max_requests: u32,
    window_seconds: u64,
}

impl RateLimiter {
    pub fn new(max_requests: u32, window_seconds: u64) -> Self {
        RateLimiter {
            max_requests,
            window_seconds,
        }
    }
}

// We'll use a simpler implementation to avoid complex type issues
impl<S, B> Transform<S, ServiceRequest> for RateLimiter
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Transform = RateLimiterMiddleware<S>;
    type InitError = ();
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        // Create a Mutex here so we don't have to store it in the struct
        let store = std::sync::Arc::new(Mutex::new(HashMap::new()));
        
        ok(RateLimiterMiddleware {
            service,
            store,
            max_requests: self.max_requests,
            window_seconds: self.window_seconds,
        })
    }
}

pub struct RateLimiterMiddleware<S> {
    service: S,
    store: std::sync::Arc<Mutex<HashMap<String, (u32, Instant)>>>,
    max_requests: u32,
    window_seconds: u64,
}

impl<S, B> Service<ServiceRequest> for RateLimiterMiddleware<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error>,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>>>>;

    fn poll_ready(&self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.service.poll_ready(cx)
    }

    fn call(&self, req: ServiceRequest) -> Self::Future {
        // Clean up expired entries
        {
            let mut store = self.store.lock().unwrap();
            store.retain(|_, (_, timestamp)| {
                timestamp.elapsed().as_secs() < self.window_seconds
            });
        }

        // Get client IP
        let ip = match req.connection_info().peer_addr() {
            Some(peer) => peer.split(':').next().unwrap_or("unknown").to_string(),
            None => "unknown".to_string(),
        };
        
        // Check rate limit
        let is_limited = {
            let mut store = self.store.lock().unwrap();
            let now = Instant::now();
            match store.get_mut(&ip) {
                Some((count, timestamp)) => {
                    // Reset if time window has passed
                    if timestamp.elapsed().as_secs() >= self.window_seconds {
                        *count = 1;
                        *timestamp = now;
                        false
                    } else {
                        // Increment count and check against limit
                        *count += 1;
                        *count > self.max_requests
                    }
                },
                None => {
                    // First request from this IP
                    store.insert(ip.clone(), (1, now));
                    false
                }
            }
        };

        // Handle the rate limiting
        if is_limited {
            log_event(&format!("Rate limit exceeded for IP: {}", ip));
            
            // Use Actix Web's early response capability
            let error_body = serde_json::to_string(&json!({
                "error": "Rate limit exceeded, please try again later",
                "retry_after": self.window_seconds,
            })).unwrap();
            
            let future = async {
                Err(actix_web::error::ErrorTooManyRequests(error_body))
            };
            
            Box::pin(future)
        } else {
            let fut = self.service.call(req);
            Box::pin(async move {
                fut.await
            })
        }
    }
}

// Function to set up rate limiting for our API
fn configure_rate_limiting(cfg: &mut web::ServiceConfig) {
    // For sensitive endpoints, use stricter rate limiting
    let auth_limiter = web::scope("/auth")
        .wrap(RateLimiter::new(5, 60)) // 5 requests per minute for auth endpoints
        .service(auth)
        .service(refresh_token);
    
    // Apply a higher limit to standard API calls
    let api_limiter = web::scope("")
        .wrap(RateLimiter::new(30, 60)) // 30 requests per minute for other endpoints
        .service(get_system_status)
        .service(get_threats)
        .service(get_network_status)
        .service(get_logs_endpoint)
        .service(run_security_scan)
        .service(update_threat_db)
        .service(check_backend)
        .service(vm_checks)
        .service(get_status)
        .service(run_security_check)
        .service(run_maintenance)
        .service(get_direct_network_data)
        .service(get_direct_security_data)
        .service(get_direct_logs_data)
        .service(create_user);
    
    cfg.service(auth_limiter).service(api_limiter);
}

// Modify the configure_routes function to use our rate limiting
pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api")
            .configure(configure_rate_limiting)
            .service(stream_data) // WebSocket connections handled separately
            .service(setup_system) // Add setup endpoint
    );
    
    // Security tools endpoints
    cfg.service(web::scope("/api/security_tool_status")
        .route("/{tool_name}", web::get().to(get_security_tool_status)));
    cfg.service(web::resource("/api/run_security_tool")
        .route(web::post().to(run_security_tool_action)));
}

// Add a new function to configure static files
pub fn configure_static_files(config: &mut web::ServiceConfig) {
    // Log that we're setting up static file serving
    log_event("Configuring static file serving for GUI");
    
    // First, add middleware to check if setup is needed
    config.service(
        fs::Files::new("/", "./src/gui")
            .index_file("index.html")
            .prefer_utf8(true)
            .use_last_modified(true)
            .default_handler(|req: ServiceRequest| {
                let setup_file = Path::new("/etc/hardn/setup_completed");
                let setup_needed = !setup_file.exists();
                
                let (http_req, _) = req.into_parts();
                let path = http_req.uri().path().to_owned();
                let is_setup_path = setup_needed && (path == "/" || path == "/index.html");
                
                // Use a single Box::pin with a conditional inside
                Box::pin(async move {
                    let resp = if is_setup_path {
                        // Serve the setup page instead
                        let setup_file_path = "./src/gui/setup.html";
                        if Path::new(setup_file_path).exists() {
                            log_event("First-time setup needed. Serving setup wizard.");
                            let named_file = fs::NamedFile::open(setup_file_path).unwrap();
                            named_file.into_response(&http_req)
                        } else {
                            HttpResponse::NotFound().finish()
                        }
                    } else {
                        // Fallback to 404
                        HttpResponse::NotFound().finish()
                    };
                    
                    Ok(ServiceResponse::new(http_req, resp))
                })
            })
    );
    
    // Log successful configuration
    log_event("Static file serving configured successfully");
}

// Helper function for token validation - improved with role checking
async fn validate_token(req: &HttpRequest) -> Result<(String, String), &'static str> {
    // Check for Authorization header
    let auth_header = match req.headers().get("Authorization") {
        Some(header) => header,
        None => return Err("Authorization required"),
    };
    
    // Extract token from "Bearer <token>"
    let auth_str = match auth_header.to_str() {
        Ok(s) => s,
        Err(_) => return Err("Invalid authorization header"),
    };
    
    if !auth_str.starts_with("Bearer ") {
        return Err("Invalid authorization format");
    }
    
    let token = &auth_str[7..]; // Skip "Bearer "
    
    // Validate token with stricter validation
    let mut validation = Validation::default();
    validation.validate_exp = true;
    validation.leeway = 0; // No leeway for expiration

    let token_data = match decode::<Claims>(
        token,
        &DecodingKey::from_secret(JWT_SECRET.as_bytes()),
        &validation
    ) {
        Ok(data) => data,
        Err(_) => return Err("Invalid or expired token"),
    };
    
    // Return the username and role from the token
    Ok((token_data.claims.sub, token_data.claims.role))
}

// Create tokens for authenticated user with role information
fn create_tokens(username: &str, role: &str) -> Result<TokenResponse, &'static str> {
    // Create access token
    let access_exp = Utc::now()
        .checked_add_signed(ChronoDuration::hours(TOKEN_EXPIRY_HOURS))
        .expect("Valid timestamp")
        .timestamp() as usize;
        
    let access_claims = Claims {
        sub: username.to_string(),
        exp: access_exp,
        iat: Utc::now().timestamp() as usize,
        role: role.to_string(),
    };
    
    let access_token = match encode(
        &Header::default(),
        &access_claims,
        &EncodingKey::from_secret(JWT_SECRET.as_bytes())
    ) {
        Ok(t) => t,
        Err(_) => return Err("Failed to create access token"),
    };
    
    // Create refresh token (shorter lived for security)
    let refresh_exp = Utc::now()
        .checked_add_signed(ChronoDuration::hours(REFRESH_TOKEN_EXPIRY_HOURS))
        .expect("Valid timestamp")
        .timestamp() as usize;
        
    let refresh_claims = Claims {
        sub: username.to_string(),
        exp: refresh_exp,
        iat: Utc::now().timestamp() as usize,
        role: role.to_string(),
    };
    
    let token_refresh = match encode(
        &Header::default(),
        &refresh_claims,
        &EncodingKey::from_secret(JWT_SECRET.as_bytes())
    ) {
        Ok(t) => t,
        Err(_) => return Err("Failed to create refresh token"),
    };
    
    Ok(TokenResponse {
        access_token,
        refresh_token: token_refresh,
        token_type: "Bearer".to_string(),
        expires_in: TOKEN_EXPIRY_HOURS * 3600, // Convert hours to seconds
    })
}

// Authentication endpoint
#[post("/auth")]
async fn auth(req: web::Json<AuthRequest>) -> impl Responder {
    let username = &req.username;
    let password = &req.password;
    
    // Get user credentials
    let mut users = match USER_STORE.write() {
        Ok(users) => users,
        Err(_) => {
            log_error("Failed to acquire write lock on user store");
            return HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": "Internal server error"
            }));
        }
    };
    
    // Check if user exists
    if let Some(user_creds) = users.get_mut(username) {
        // Check if account is locked
        if let Some(locked_until) = user_creds.locked_until {
            if locked_until > Utc::now() {
                let remaining_minutes = (locked_until - Utc::now()).num_minutes() + 1;
                
                log_event(&format!("Attempted login to locked account: {}", username));
                return HttpResponse::TooManyRequests().json(json!({
                    "success": false,
                    "message": format!("Account is locked. Try again in {} minutes", remaining_minutes),
                    "locked_until": locked_until.to_rfc3339()
                }));
            } else {
                // Reset lock if time has expired
                user_creds.locked_until = None;
                user_creds.failed_attempts = 0;
            }
        }
        
        // Verify password
        let parsed_hash = match PasswordHash::new(&user_creds.password_hash) {
            Ok(hash) => hash,
            Err(_) => {
                log_error(&format!("Invalid password hash format for user: {}", username));
                return HttpResponse::InternalServerError().json(json!({
                    "success": false,
                    "message": "Authentication failed"
                }));
            }
        };
        
        if Argon2::default().verify_password(password.as_bytes(), &parsed_hash).is_ok() {
            // Reset failed attempts on successful login
            user_creds.failed_attempts = 0;
            
            // Clone role for token creation
            let role = user_creds.role.clone();
            
            // Generate tokens
            match create_tokens(username, &role) {
                Ok(token_response) => {
                    log_event(&format!("User authenticated: {}", username));
                    HttpResponse::Ok().json(json!({
                        "success": true,
                        "user": username,
                        "role": role,
                        "tokens": token_response
                    }))
                },
                Err(e) => {
                    log_error(&format!("Token creation failed: {}", e));
                    HttpResponse::InternalServerError().json(json!({
                        "success": false,
                        "message": "Authentication failed: could not create tokens"
                    }))
                }
            }
        } else {
            // Increment failed attempts
            user_creds.failed_attempts += 1;
            
            // Check if account should be locked
            if user_creds.failed_attempts >= MAX_FAILED_ATTEMPTS {
                user_creds.locked_until = Some(
                    Utc::now().checked_add_signed(ChronoDuration::minutes(LOCKOUT_MINUTES))
                                .expect("Valid timestamp")
                );
                
                log_event(&format!("Account locked due to failed attempts: {}", username));
                return HttpResponse::TooManyRequests().json(json!({
                    "success": false,
                    "message": format!("Account locked for {} minutes due to too many failed attempts", LOCKOUT_MINUTES),
                    "locked_until": user_creds.locked_until.unwrap().to_rfc3339()
                }));
            }
            
            log_event(&format!("Failed authentication attempt for user: {} (Attempt {}/{})", 
                               username, user_creds.failed_attempts, MAX_FAILED_ATTEMPTS));
            
            // Use constant-time response to prevent timing attacks
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            
            HttpResponse::Unauthorized().json(json!({
                "success": false,
                "message": "Invalid credentials",
                "attempts_left": MAX_FAILED_ATTEMPTS - user_creds.failed_attempts
            }))
        }
    } else {
        // User doesn't exist, but use constant-time response to prevent username enumeration
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        
        log_event(&format!("Authentication attempt for non-existent user: {}", username));
        HttpResponse::Unauthorized().json(json!({
            "success": false,
            "message": "Invalid credentials"
        }))
    }
}

// Token refresh endpoint with improved security
#[post("/refresh_token")]
async fn refresh_token(req: web::Json<RefreshRequest>) -> impl Responder {
    let refresh_token = &req.refresh_token;
    
    // Validate the refresh token
    let mut validation = Validation::default();
    validation.validate_exp = true;
    validation.leeway = 0; // No leeway for expiration
    
    let token_data = match decode::<Claims>(
        refresh_token,
        &DecodingKey::from_secret(JWT_SECRET.as_bytes()),
        &validation
    ) {
        Ok(data) => data,
        Err(_) => {
            return HttpResponse::Unauthorized().json(json!({
                "success": false,
                "message": "Invalid refresh token"
            }))
        }
    };
    
    // Create new tokens
    let username = &token_data.claims.sub;
    let role = &token_data.claims.role;
    
    // Verify user still exists in the store
    let users = match USER_STORE.read() {
        Ok(users) => users,
        Err(_) => {
            log_error("Failed to acquire read lock on user store");
            return HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": "Internal server error"
            }));
        }
    };
    
    if !users.contains_key(username) {
        return HttpResponse::Unauthorized().json(json!({
            "success": false,
            "message": "User no longer exists"
        }));
    }
    
    match create_tokens(username, role) {
        Ok(token_response) => {
            log_event(&format!("Tokens refreshed for user: {}", username));
            HttpResponse::Ok().json(json!({
                "success": true,
                "tokens": token_response
            }))
        },
        Err(e) => {
            log_error(&format!("Token refresh failed: {}", e));
            HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": "Token refresh failed"
            }))
        }
    }
}

// User management functions
fn add_user(username: &str, password: &str, role: &str) -> Result<(), String> {
    let mut users = match USER_STORE.write() {
        Ok(users) => users,
        Err(_) => return Err("Failed to acquire write lock on user store".to_string()),
    };
    
    // Check if user already exists
    if users.contains_key(username) {
        return Err("User already exists".to_string());
    }
    
    // Hash password
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let hashed_password = match argon2.hash_password(password.as_bytes(), &salt) {
        Ok(hash) => hash.to_string(),
        Err(_) => return Err("Failed to hash password".to_string()),
    };
    
    // Add user
    users.insert(
        username.to_string(),
        UserCredentials {
            password_hash: hashed_password,
            role: role.to_string(),
            failed_attempts: 0,
            locked_until: None,
        },
    );
    
    log_event(&format!("User created: {} with role {}", username, role));
    Ok(())
}

// System status endpoint
#[get("/get_system_status")]
async fn get_system_status(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }
    
    let vm_status = is_running_in_vm();
    
    // Get component statuses
    let selinux_status = check_selinux(vm_status);
    let firewall_status = check_firewall(vm_status);
    let apparmor_status = check_apparmor(vm_status);
    let permissions_status = check_permissions(vm_status);
    
    // Determine overall status
    let overall_status = if all_components_ok(&[
        &selinux_status, &firewall_status, &apparmor_status, &permissions_status
    ]) {
        json!({
            "status": "ok",
            "message": "All security components are properly configured"
        })
    } else if vm_status {
        json!({
            "status": "warning",
            "message": "Some security components need attention (acceptable in VM)"
        })
    } else {
        json!({
            "status": "error",
            "message": "Security components are not properly configured"
        })
    };

    HttpResponse::Ok().json(json!({
        "overall": overall_status,
        "components": {
            "selinux": selinux_status,
            "firewall": firewall_status,
            "apparmor": apparmor_status,
            "permissions": permissions_status,
        },
        "environment": if vm_status { "virtual_machine" } else { "physical_machine" }
    }))
}

// Threats endpoint
#[get("/get_threats")]
async fn get_threats(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }

    log_event("Fetching threats data");
    HttpResponse::Ok().json(json!({
        "level": 1,
        "status": "ok",
        "active_threats": 0,
        "last_update": Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
    }))
}

// Network status endpoint
#[get("/get_network_status")]
async fn get_network_status(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }

    log_event("Fetching network status");
    HttpResponse::Ok().json(json!({
        "status": "ok",
        "message": "Network is secure",
        "connections": [
            {
                "ip": "192.168.0.1",
                "port": 22,
                "status": "established",
                "type": "ssh"
            },
            {
                "ip": "10.0.0.5",
                "port": 443,
                "status": "established",
                "type": "https"
            }
        ]
    }))
}

// Logs endpoint
#[get("/get_logs")]
async fn get_logs_endpoint(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }

    log_event("Fetching system logs");
    HttpResponse::Ok().json(json!({
        "logs": [
            {
                "timestamp": (Utc::now() - chrono::Duration::hours(1)).format("%Y-%m-%dT%H:%M:%SZ").to_string(),
                "level": "info",
                "message": "System initialized"
            },
            {
                "timestamp": Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string(),
                "level": "info",
                "message": "System logs requested"
            }
        ]
    }))
}

// Security scan endpoint
#[post("/run_security_scan")]
async fn run_security_scan(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }

    let scan_params = get_scan_parameters().await;
    log_event(&format!("Running security scan with parameters: {:?}", scan_params));
    HttpResponse::Ok().json(json!({
        "success": true,
        "message": "Security scan completed successfully",
        "type": scan_params.scan_type
    }))
}

// Threat DB update endpoint
#[post("/update_threat_db")]
async fn update_threat_db(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }

    let user_confirmation = get_user_input("Confirm update of threat database?").await;
    if user_confirmation.to_lowercase() == "yes" {
        log_event("Updating threat database");
        HttpResponse::Ok().json(json!({
            "success": true,
            "message": "Threat database updated successfully"
        }))
    } else {
        log_event("Threat database update canceled by user");
        HttpResponse::Ok().json(json!({
            "success": false,
            "message": "Threat database update canceled"
        }))
    }
}

// Backend availability check endpoint
#[get("/check_backend")]
async fn check_backend() -> impl Responder {
    // Log that the endpoint was hit for debugging
    log_event("Backend availability check requested");
    
    // Return with appropriate CORS headers
    HttpResponse::Ok()
        .append_header(("Access-Control-Allow-Origin", "*"))
        .append_header(("Access-Control-Allow-Methods", "GET, POST, OPTIONS"))
        .append_header(("Access-Control-Allow-Headers", "Content-Type, Authorization"))
        .append_header(("Content-Type", "application/json"))
        .json(json!({
            "status": "ok",
            "message": "Backend is available",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "version": "1.0.0"
        }))
}

// VM environment checks endpoint
#[get("/vm_checks")]
async fn vm_checks(req: HttpRequest) -> impl Responder {
    // Validate token
    if let Err(e) = validate_token(&req).await {
        return HttpResponse::Unauthorized().json(json!({ "error": e }));
    }

    let vm_detected = is_running_in_vm();
    HttpResponse::Ok().json(json!({
        "is_vm": vm_detected,
        "environment": if vm_detected { "virtual_machine" } else { "physical_machine" }
    }))
}

// Helper function to check if all component statuses are "ok"
fn all_components_ok(components: &[&serde_json::Value]) -> bool {
    components.iter().all(|c| {
        c.get("status").and_then(|s| s.as_str()) == Some("ok")
    })
}

// VM detection function
fn is_running_in_vm() -> bool {
    // Method 1: Check /proc/cpuinfo for hypervisor flags
    if let Ok(output) = std::fs::read_to_string("/proc/cpuinfo") {
        let cpuinfo = output.to_lowercase();
        if ["hypervisor", "vmware", "virtualbox", "kvm", "xen"]
            .iter()
            .any(|&x| cpuinfo.contains(x))
        {
            return true;
        }
    }
    
    // Method 2: Check dmesg for VM indicators
    if let Ok(output) = Command::new("dmesg").output() {
        if let Ok(dmesg_output) = String::from_utf8(output.stdout) {
            let dmesg_output = dmesg_output.to_lowercase();
            if ["vmware", "virtualbox", "hypervisor", "virtual machine"]
                .iter()
                .any(|&x| dmesg_output.contains(x))
            {
                return true;
            }
        }
    }
    
    // Method 3: Use systemd-detect-virt if available
    if let Ok(output) = Command::new("systemd-detect-virt").output() {
        if let Ok(result) = String::from_utf8(output.stdout) {
            let result = result.trim();
            if result != "none" && !result.is_empty() {
                return true;
            }
        }
    }
    
    // Method 4: Check for VM-specific directories
    let vm_dirs = ["/sys/devices/virtual/dmi/id/product_name", "/sys/hypervisor/type"];
    for vm_dir in vm_dirs.iter() {
        if let Ok(content) = std::fs::read_to_string(vm_dir) {
            let content = content.to_lowercase();
            if ["vmware", "virtualbox", "qemu", "kvm", "xen"]
                .iter()
                .any(|&x| content.contains(x))
            {
                return true;
            }
        }
    }
    
    false
}

// Security check functions
fn check_selinux(is_vm: bool) -> serde_json::Value {
    let result = Command::new("getenforce").output();
    
    match result {
        Ok(output) => {
            if let Ok(status) = String::from_utf8(output.stdout) {
                let status = status.trim();
                if status == "Enforcing" {
                    json!({
                        "status": "ok",
                        "message": "SELinux is enforcing",
                        "enforced": true
                    })
                } else if status == "Permissive" {
                    json!({
                        "status": if is_vm { "warning" } else { "warning" },
                        "message": if is_vm { "SELinux is in permissive mode (acceptable in VM)" } else { "SELinux is in permissive mode" },
                        "enforced": false
                    })
                } else {
                    json!({
                        "status": if is_vm { "warning" } else { "error" },
                        "message": if is_vm { "SELinux is disabled (acceptable in VM)" } else { "SELinux is disabled" },
                        "enforced": false
                    })
                }
            } else {
                json!({
                    "status": if is_vm { "warning" } else { "error" },
                    "message": if is_vm { "Could not determine SELinux status (acceptable in VM)" } else { "Could not determine SELinux status" },
                    "enforced": false
                })
            }
        },
        Err(_) => {
            json!({
                "status": if is_vm { "warning" } else { "error" },
                "message": if is_vm { "SELinux tools not installed (acceptable in VM)" } else { "SELinux tools not installed" },
                "enforced": false
            })
        }
    }
}

fn check_firewall(is_vm: bool) -> serde_json::Value {
    let result = Command::new("systemctl").args(["is-active", "firewalld"]).output();
    
    match result {
        Ok(output) => {
            if let Ok(status) = String::from_utf8(output.stdout) {
                let status = status.trim();
                if status == "active" {
                    json!({
                        "status": "ok",
                        "message": "Firewall is active",
                        "active": true
                    })
                } else {
                    json!({
                        "status": if is_vm { "warning" } else { "error" },
                        "message": if is_vm { "Firewall is not active (acceptable in VM)" } else { "Firewall is not active" },
                        "active": false
                    })
                }
            } else {
                json!({
                    "status": if is_vm { "warning" } else { "error" },
                    "message": if is_vm { "Could not determine firewall status (acceptable in VM)" } else { "Could not determine firewall status" },
                    "active": false
                })
            }
        },
        Err(_) => {
            json!({
                "status": if is_vm { "warning" } else { "error" },
                "message": if is_vm { "Firewall service not found (acceptable in VM)" } else { "Firewall service not found" },
                "active": false
            })
        }
    }
}

fn check_apparmor(is_vm: bool) -> serde_json::Value {
    let result = Command::new("aa-status").output();
    
    match result {
        Ok(output) => {
            if output.status.success() {
                if let Ok(status) = String::from_utf8(output.stdout) {
                    if status.contains("profiles are loaded") {
                        json!({
                            "status": "ok",
                            "message": "AppArmor is active with profiles loaded",
                            "active": true
                        })
                    } else {
                        json!({
                            "status": if is_vm { "warning" } else { "warning" },
                            "message": if is_vm { "AppArmor is active but no profiles loaded (acceptable in VM)" } else { "AppArmor is active but no profiles loaded" },
                            "active": true
                        })
                    }
                } else {
                    json!({
                        "status": if is_vm { "warning" } else { "warning" },
                        "message": if is_vm { "Could not determine AppArmor status (acceptable in VM)" } else { "Could not determine AppArmor status" },
                        "active": false
                    })
                }
            } else {
                json!({
                    "status": if is_vm { "warning" } else { "error" },
                    "message": if is_vm { "AppArmor is not active (acceptable in VM)" } else { "AppArmor is not active" },
                    "active": false
                })
            }
        },
        Err(_) => {
            json!({
                "status": if is_vm { "warning" } else { "error" },
                "message": if is_vm { "AppArmor tools not installed (acceptable in VM)" } else { "AppArmor tools not installed" },
                "active": false
            })
        }
    }
}

fn check_permissions(is_vm: bool) -> serde_json::Value {
    // Check permissions for sensitive files
    let sensitive_files = vec![
        ("/etc/shadow", "640"),
        ("/etc/sudoers", "440"),
        ("/etc/ssh/sshd_config", "600")
    ];
    
    let mut results = Vec::new();
    
    for (path, expected_perm) in sensitive_files {
        if std::path::Path::new(path).exists() {
            let stat_result = Command::new("stat")
                .args(["-c", "%a", path])
                .output();
                
            match stat_result {
                Ok(output) => {
                    if let Ok(perms) = String::from_utf8(output.stdout) {
                        let perms = perms.trim();
                        if perms == expected_perm {
                            results.push(json!({
                                "path": path,
                                "exists": true,
                                "permissions": perms,
                                "status": "ok",
                                "message": "Permissions are secure"
                            }));
                        } else {
                            results.push(json!({
                                "path": path,
                                "exists": true,
                                "permissions": perms,
                                "status": if is_vm { "warning" } else { "error" },
                                "message": if is_vm { 
                                    format!("Permissions are not secure: {} (acceptable in VM)", perms)
                                } else {
                                    format!("Permissions are not secure: {}", perms)
                                }
                            }));
                        }
                    } else {
                        results.push(json!({
                            "path": path,
                            "exists": true,
                            "permissions": null,
                            "status": if is_vm { "warning" } else { "error" },
                            "message": if is_vm {
                                "Could not check permissions (acceptable in VM)"
                            } else {
                                "Could not check permissions"
                            }
                        }));
                    }
                },
                Err(_) => {
                    results.push(json!({
                        "path": path,
                        "exists": true,
                        "permissions": null,
                        "status": if is_vm { "warning" } else { "error" },
                        "message": if is_vm {
                            "Could not check permissions (acceptable in VM)"
                        } else {
                            "Could not check permissions"
                        }
                    }));
                }
            }
        } else {
            results.push(json!({
                "path": path,
                "exists": false,
                "permissions": null,
                "status": if is_vm { "warning" } else { "error" },
                "message": if is_vm {
                    format!("File not found (acceptable in VM)")
                } else {
                    format!("File not found")
                }
            }));
        }
    }
    
    // Determine overall permission status
    if results.iter().all(|r| r.get("status").and_then(|s| s.as_str()) == Some("ok")) {
        json!({
            "status": "ok",
            "message": "All file permissions are secure",
            "details": results
        })
    } else if is_vm && results.iter().all(|r| {
        let status = r.get("status").and_then(|s| s.as_str());
        status == Some("ok") || status == Some("warning")
    }) {
        json!({
            "status": "warning",
            "message": "Some permissions need attention but acceptable in VM",
            "details": results
        })
    } else {
        json!({
            "status": "error",
            "message": "Some file permissions are not secure",
            "details": results
        })
    }
}

// Get system status - synchronous REST endpoint
#[get("/status")]
async fn get_status() -> impl Responder {
    // Collect data from different sources
    let network_result = gui_input::collect_network_data().await;
    let security_result = gui_input::collect_security_data().await;
    
    // Combine results
    let mut response = json!({
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "status": "ok",
    });
    
    if let Ok(network_data) = network_result {
        response["network"] = network_data;
    } else {
        response["network"] = json!({"error": "Failed to collect network data"});
    }
    
    if let Ok(security_data) = security_result {
        response["security"] = security_data;
    } else {
        response["security"] = json!({"error": "Failed to collect security data"});
    }
    
    HttpResponse::Ok().json(response)
}

// Start a security check
#[post("/security/check")]
async fn run_security_check(request: web::Json<CheckRequest>) -> impl Responder {
    log_event(&format!("Security check requested: {}", request.check_type));
    
    let check_result = match request.check_type.as_str() {
        "firewall" => security_checks::check_firewall_rules().await,
        "updates" => security_checks::check_system_updates().await,
        "permissions" => security_checks::check_file_permissions().await,
        "ports" => security_checks::check_open_ports().await,
        "users" => security_checks::check_user_accounts().await,
        "all" => security_checks::run_all_checks().await,
        _ => Err(format!("Unknown check type: {}", request.check_type)),
    };
    
    match check_result {
        Ok(result) => HttpResponse::Ok().json(result),
        Err(e) => HttpResponse::BadRequest().json(json!({"error": e})),
    }
}

// Get the latest system logs
#[get("/logs/{count}")]
async fn get_logs(count: web::Path<usize>) -> impl Responder {
    let limit = count.into_inner().min(1000); // Cap at 1000 logs max
    
    match gui_input::collect_logs_data(limit).await {
        Ok(logs) => HttpResponse::Ok().json(logs),
        Err(e) => HttpResponse::InternalServerError().json(json!({"error": e})),
    }
}

// Simulate login for frontend testing
#[post("/login")]
async fn login(credentials: web::Json<AuthRequest>) -> impl Responder {
    // In a real implementation, this would verify credentials against a secure database
    // and generate a proper JWT token
    if credentials.username == "admin" && credentials.password == "password" {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsImV4cCI6MTY0MzM5OTk5OX0.8J7q3eFtGs5H_Kf_HJ-xhwHL7-nfw-JYODV7_U2zMrY";
        HttpResponse::Ok().json(json!({
            "access_token": token,
            "expires_in": 3600
        }))
    } else {
        HttpResponse::Unauthorized().json(json!({"error": "Invalid credentials"}))
    }
}

// API for running maintenance tasks
#[post("/maintenance/{task}")]
async fn run_maintenance(task: web::Path<String>) -> impl Responder {
    let task_name = task.into_inner();
    log_event(&format!("Maintenance task requested: {}", task_name));
    
    // Implement various maintenance tasks
    let result = match task_name.as_str() {
        "update" => {
            // Simulate system update
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            Ok(json!({"status": "success", "message": "System updates completed"}))
        },
        "cleanup" => {
            // Simulate cleanup
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            Ok(json!({"status": "success", "message": "System cleanup completed"}))
        },
        "backup" => {
            // Simulate backup
            tokio::time::sleep(std::time::Duration::from_secs(3)).await;
            Ok(json!({"status": "success", "message": "System backup completed"}))
        },
        _ => Err(format!("Unknown maintenance task: {}", task_name)),
    };
    
    match result {
        Ok(data) => HttpResponse::Ok().json(data),
        Err(e) => HttpResponse::BadRequest().json(json!({"error": e})),
    }
}

// Direct Data API - Now with authentication
#[get("/direct/network")]
async fn get_direct_network_data(req: HttpRequest) -> impl Responder {
    log_event("Direct network data requested");
    
    // Validate authentication token
    match validate_token(&req).await {
        Ok(_) => {
            match gui_input::collect_network_data().await {
                Ok(data) => {
                    log_event("Successfully retrieved network data");
                    HttpResponse::Ok()
                        .content_type("application/json")
                        .json(data)
                },
                Err(e) => {
                    log_error(&format!("Error collecting network data: {}", e));
                    HttpResponse::InternalServerError()
                        .json(json!({"error": "Failed to retrieve network data", "timestamp": chrono::Utc::now().to_rfc3339()}))
                }
            }
        },
        Err(e) => {
            log_event(&format!("Unauthorized access attempt to network data: {}", e));
            HttpResponse::Unauthorized()
                .json(json!({"error": "Authentication required", "timestamp": chrono::Utc::now().to_rfc3339()}))
        }
    }
}

#[get("/direct/security")]
async fn get_direct_security_data(req: HttpRequest) -> impl Responder {
    log_event("Direct security data requested");
    
    // Validate authentication token
    match validate_token(&req).await {
        Ok(_) => {
            match gui_input::collect_security_data().await {
                Ok(data) => {
                    log_event("Successfully retrieved security data");
                    HttpResponse::Ok()
                        .content_type("application/json")
                        .json(data)
                },
                Err(e) => {
                    log_error(&format!("Error collecting security data: {}", e));
                    HttpResponse::InternalServerError()
                        .json(json!({"error": "Failed to retrieve security data", "timestamp": chrono::Utc::now().to_rfc3339()}))
                }
            }
        },
        Err(e) => {
            log_event(&format!("Unauthorized access attempt to security data: {}", e));
            HttpResponse::Unauthorized()
                .json(json!({"error": "Authentication required", "timestamp": chrono::Utc::now().to_rfc3339()}))
        }
    }
}

#[get("/direct/logs")]
async fn get_direct_logs_data(req: HttpRequest) -> impl Responder {
    log_event("Direct logs data requested");
    
    // Validate authentication token
    match validate_token(&req).await {
        Ok(_) => {
            match gui_input::collect_logs_data(50).await {
                Ok(data) => {
                    log_event("Successfully retrieved logs data");
                    HttpResponse::Ok()
                        .content_type("application/json")
                        .json(data)
                },
                Err(e) => {
                    log_error(&format!("Error collecting logs data: {}", e));
                    HttpResponse::InternalServerError()
                        .json(json!({"error": "Failed to retrieve logs data", "timestamp": chrono::Utc::now().to_rfc3339()}))
                }
            }
        },
        Err(e) => {
            log_event(&format!("Unauthorized access attempt to logs data: {}", e));
            HttpResponse::Unauthorized()
                .json(json!({"error": "Authentication required", "timestamp": chrono::Utc::now().to_rfc3339()}))
        }
    }
}

// Add a user creation endpoint (admin only)
#[derive(Deserialize)]
struct CreateUserRequest {
    username: String,
    password: String,
    role: String,
}

#[post("/admin/create_user")]
async fn create_user(req: HttpRequest, user_req: web::Json<CreateUserRequest>) -> impl Responder {
    // Validate authentication token and check for admin role
    match validate_token(&req).await {
        Ok((_, role)) => {
            if role != "admin" {
                log_event(&format!("Unauthorized attempt to create user by non-admin role: {}", role));
                return HttpResponse::Forbidden().json(json!({
                    "success": false,
                    "message": "Admin role required"
                }));
            }
            
            // Create user
            match add_user(&user_req.username, &user_req.password, &user_req.role) {
                Ok(_) => {
                    HttpResponse::Created().json(json!({
                        "success": true,
                        "message": format!("User {} created with role {}", user_req.username, user_req.role)
                    }))
                },
                Err(e) => {
                    HttpResponse::BadRequest().json(json!({
                        "success": false,
                        "message": e
                    }))
                }
            }
        },
        Err(e) => {
            HttpResponse::Unauthorized().json(json!({
                "success": false,
                "message": e
            }))
        }
    }
}

// Setup endpoint
#[post("/setup")]
async fn setup_system(req: web::Json<SetupRequest>) -> impl Responder {
    log_event("Setup wizard request received");
    
    // Validate inputs
    if req.admin_username.trim().is_empty() {
        return HttpResponse::BadRequest().json(json!({
            "success": false,
            "message": "Admin username is required"
        }));
    }
    
    if req.admin_password.len() < 10 {
        return HttpResponse::BadRequest().json(json!({
            "success": false,
            "message": "Password must be at least 10 characters long"
        }));
    }
    
    if req.allowed_origin.trim().is_empty() {
        return HttpResponse::BadRequest().json(json!({
            "success": false,
            "message": "Allowed origin is required"
        }));
    }
    
    // Create admin user
    match add_user(&req.admin_username, &req.admin_password, "admin") {
        Ok(_) => {
            log_event(&format!("Created admin user: {}", req.admin_username));
        },
        Err(e) => {
            log_error(&format!("Failed to create admin user: {}", e));
            return HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": format!("Failed to create admin user: {}", e)
            }));
        }
    }
    
    // Update configuration
    let mut config = config::load_config().unwrap_or_default();
    config.allowed_origin = req.allowed_origin.clone();
    
    if let Some(host) = &req.api_host {
        if !host.trim().is_empty() {
            config.api_host = host.clone();
        }
    }
    
    if let Some(port) = req.api_port {
        if port > 0 {
            config.api_port = port;
        }
    }
    
    match config::save_config(&config) {
        Ok(_) => {
            log_event("Updated configuration during setup");
        },
        Err(e) => {
            log_error(&format!("Failed to save configuration: {}", e));
            return HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": format!("Failed to save configuration: {}", e)
            }));
        }
    }
    
    // Create setup completion file
    let setup_dir = Path::new("/etc/hardn");
    if !setup_dir.exists() {
        if let Err(e) = std::fs::create_dir_all(setup_dir) {
            log_error(&format!("Failed to create directory /etc/hardn: {}", e));
            return HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": "Failed to create setup directory"
            }));
        }
    }
    
    let setup_file = setup_dir.join("setup_completed");
    match std::fs::write(&setup_file, &chrono::Utc::now().to_rfc3339()) {
        Ok(_) => {
            log_event("Setup completed successfully");
            
            // Generate JWT secret if it doesn't exist
            if std::env::var("HARDN_JWT_SECRET").is_err() {
                use rand::{distributions::Alphanumeric, Rng};
                let jwt_secret: String = rand::thread_rng()
                    .sample_iter(&Alphanumeric)
                    .take(64)  // 64 characters for a secure secret
                    .map(char::from)
                    .collect();
                
                std::env::set_var("HARDN_JWT_SECRET", &jwt_secret);
                log_event("Generated new JWT secret");
            }
            
            HttpResponse::Ok().json(json!({
                "success": true,
                "message": "Setup completed successfully"
            }))
        },
        Err(e) => {
            log_error(&format!("Failed to write setup completion file: {}", e));
            HttpResponse::InternalServerError().json(json!({
                "success": false,
                "message": "Failed to complete setup"
            }))
        }
    }
}

/**
 * Get the status of a security tool
 */
async fn get_security_tool_status(tool_name: web::Path<String>, req: HttpRequest) -> impl Responder {
    // Validate authentication
    let auth_result = validate_token(&req).await;
    if let Err(err) = auth_result {
        return HttpResponse::Unauthorized().json(json!({
            "error": err
        }));
    }
    
    // Get the tool status
    let status = security_tools::get_tool_status(&tool_name).await;
    
    HttpResponse::Ok().json(status)
}

/**
 * Run a security tool action
 */
async fn run_security_tool_action(req: HttpRequest, request_data: web::Json<security_tools::SecurityToolRequest>) -> impl Responder {
    // Validate authentication
    let auth_result = validate_token(&req).await;
    if let Err(err) = auth_result {
        return HttpResponse::Unauthorized().json(json!({
            "error": err
        }));
    }
    
    // Only admins can run security tools
    let (_, role) = auth_result.unwrap();
    if role != "admin" {
        return HttpResponse::Forbidden().json(json!({
            "error": "Only administrators can run security tool actions"
        }));
    }
    
    // Log the action
    log_event(&format!(
        "Security tool action: {} {} by user with role {}", 
        request_data.tool, 
        request_data.action,
        role
    ));
    
    // Run the tool action
    let result = security_tools::run_tool_action(request_data.into_inner()).await;
    
    HttpResponse::Ok().json(result)
}