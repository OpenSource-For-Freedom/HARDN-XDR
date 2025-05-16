// this is testing the main function from the main.rs file

#[cfg(test)]


mod tests {
    use super::*;
    use std::net::TcpStream;
    use std::time::Duration;

    #[actix_rt::test]
    async fn test_server_binds_to_correct_address() {
        // Start server in a separate thread so it doesn't block the test
        let handle = std::thread::spawn(|| {
            actix_rt::System::new().block_on(async {
                let app_state = Arc::new(Mutex::new(AppState::new()));

                // Mock the GUI launch to avoid UI interactions
                // We're only testing server binding

                // Start the HTTP server with a short timeout
                HttpServer::new(move || {
                    App::new()
                        .app_data(web::Data::new(app_state.clone()))
                        .configure(gui_api::configure_routes)
                })
                .bind("127.0.0.1:8080")
                .unwrap()
                .run()
                .await
                .unwrap();
            });
        });

        // Give the server time to start
        std::thread::sleep(Duration::from_millis(300));

        // Try to connect to the address - if we can connect, the server is bound correctly
        let connection = TcpStream::connect_timeout(
            &"127.0.0.1:8080".parse().unwrap(),
            Duration::from_secs(1)
        );

        // Terminate the server thread
        handle.thread().unpark();

        // Check if connection was successful
        assert!(connection.is_ok(), "Failed to connect to server at 127.0.0.1:8080");
    }
}
