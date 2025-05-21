use gtk::prelude::*;
use gtk::{Application, ApplicationWindow, Button, ScrolledWindow, TextBuffer, TextView};
use std::process::{Command, Stdio};
use std::io::{BufReader, BufRead};
use std::thread;

fn main() {
    let app = gtk::Application::builder()
        .application_id("org.hardn.gui")
        .build();

    app.connect_activate(build_ui);
    app.run();
}

fn build_ui(app: &gtk::Application) {
    // Create the main window
    let window = ApplicationWindow::builder()
        .application(app)
        .title("HARDN-XDR - Linux Security Hardening")
        .default_width(800)
        .default_height(600)
        .build();

    // Create the run button
    let run_button = Button::with_label("Run HARDN-XDR");

    // Create the output text view
    let text_view = TextView::new();
    text_view.set_editable(false);
    text_view.set_cursor_visible(false);
    let buffer = text_view.buffer().clone();

    let scroll = ScrolledWindow::builder()
        .child(&text_view)
        .vexpand(true)
        .hexpand(true)
        .build();

    // On button click, run the script and stream output to GUI
    run_button.connect_clicked(move |_| {
        let buffer = buffer.clone();

        thread::spawn(move || {
            let mut cmd = Command::new("bash")
                .arg("-c")
                .arg("sudo /opt/HARDN/src/setup/hardn-main.sh")
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .expect("Failed to launch HARDN script");

            if let Some(stdout) = cmd.stdout.take() {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(text) = line {
                        glib::MainContext::default().spawn_local(clone!(@strong buffer => async move {
                            let mut end = buffer.end_iter();
                            buffer.insert(&mut end, &format!("{}\n", text));
                        }));
                    }
                }
            }

            let _ = cmd.wait();
        });
    });

    // Layout
    let layout = gtk::Box::new(gtk::Orientation::Vertical, 10);
    layout.set_margin_top(10);
    layout.set_margin_bottom(10);
    layout.set_margin_start(10);
    layout.set_margin_end(10);
    layout.append(&run_button);
    layout.append(&scroll);

    window.set_child(Some(&layout));
    window.show();
}