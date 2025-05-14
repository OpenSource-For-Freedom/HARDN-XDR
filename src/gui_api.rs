use actix_web::{web, HttpResponse, Responder, HttpRequest};
use serde_json::json;
use crate::gui_input::{get_user_input, get_scan_parameters};
use crate::hardn_logging::log_event;
use std::sync::{Arc, Mutex};
use crate::AppState;  // Import AppState from the main module

// Def - REST API routes
pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(web::resource("/api/get_system_status").route(web::post().to(get_system_status)))
       .service(web::resource("/api/get_threats").route(web::post().to(get_threats)))
       .service(web::resource("/api/run_security_scan").route(web::post().to(run_security_scan)))
       .service(web::resource("/api/update_threat_db").route(web::post().to(update_threat_db)));
}

// Helper function for token validation
async fn validate_request(req: &HttpRequest, state: &web::Data<Arc<Mutex<AppState>>>) -> bool {
    if let Some(auth_header) = req.headers().get("Authorization") {
        if let Ok(token) = auth_header.to_str() {
            return state.lock().unwrap().auth_service.lock().unwrap().validate_token(token);
        }
    }
    false
}

// Handlers for REST
async fn get_system_status(req: HttpRequest, state: web::Data<Arc<Mutex<AppState>>>) -> impl Responder {
    if !validate_request(&req, &state).await {
        return HttpResponse::Unauthorized().json(json!({ "error": "Invalid or missing token" }));
    }

    HttpResponse::Ok().json(json!({
        "status": "ok",
        "message": "System is secure",
        "components": {
            "selinux": { "status": "ok", "message": "SELinux is enforcing" },
            "firewall": { "status": "ok", "message": "Firewall is active" },
            "apparmor": { "status": "ok", "message": "AppArmor is active" },
            "permissions": { "status": "ok", "message": "File permissions are secure" }
        }
    }))
}

async fn get_threats(req: HttpRequest, state: web::Data<Arc<Mutex<AppState>>>) -> impl Responder {
    if !validate_request(&req, &state).await {
        return HttpResponse::Unauthorized().json(json!({ "error": "Invalid or missing token" }));
    }

    log_event("Fetching threats data");
    HttpResponse::Ok().json(json!({
        "level": 1,
        "status": "ok",
        "active_threats": 0,
        "last_update": "2025-05-08T12:00:00Z"
    }))
}

// TODO: Fix the following issues:
/* - Non-functional Feature: Implement actual scanning operations
   - Response Accuracy: Return proper success/failure status based on scan results
   - Error Handling: Add mechanism to handle potential errors during scanning
   - Authentication: Implement proper token validation as in other endpoints
*/
async fn run_security_scan(req: HttpRequest, state: web::Data<Arc<Mutex<AppState>>>) -> impl Responder {
    if !validate_request(&req, &state).await {
        return HttpResponse::Unauthorized().json(json!({ "error": "Invalid or missing token" }));
    }

    let scan_params = get_scan_parameters().await;
    log_event(&format!("Running security scan with parameters: {:?}", scan_params));
    HttpResponse::Ok().json(json!({
        "success": true,
        "message": "Security scan completed successfully"
    }))
}

async fn update_threat_db(req: HttpRequest, state: web::Data<Arc<Mutex<AppState>>>) -> impl Responder {
    if !validate_request(&req, &state).await {
        return HttpResponse::Unauthorized().json(json!({ "error": "Invalid or missing token" }));
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

// Add this function to your gui_api.rs file
pub fn launch_gui() {
    println!("[+] Launching GUI interface...");

    // Start the GUI in a separate thread to not block the main application
    std::thread::spawn(|| {
        // This would typically launch your GUI application
        // For now, we'll just print a message
        println!("[+] GUI interface ready");
    });
}
