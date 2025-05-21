use gtk::prelude::*;
use gtk::{
    Application, ApplicationWindow, Box, Button, Notebook, Orientation, ScrolledWindow,
    TextBuffer, TextView,
};
use std::process::{Command, Stdio};
use std::io::{BufReader, BufRead};
use std::thread;

fn run_command_async(command: &str, buffer: &TextBuffer) {
    let command_string = command.to_string();
    let buffer = buffer.clone();

    thread::spawn(move || {
        let child = Command::new("bash")
            .arg("-c")
            .arg(command_string)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn();

        if let Ok(mut child) = child {
            if let Some(stdout) = child.stdout.take() {
                let reader = BufReader::new(stdout);
                for line in reader.lines().flatten() {
                    let buffer = buffer.clone();
                    glib::MainContext::default().spawn_local(async move {
                        let mut end = buffer.end_iter();
                        buffer.insert(&mut end, &format!("{}\n", line));
                    });
                }
            }

            let _ = child.wait();
        } else {
            glib::MainContext::default().spawn_local(async move {
                let mut end = buffer.end_iter();
                buffer.insert(&mut end, "[!] Failed to execute command.\n");
            });
        }
    });
}

fn main() {
    let app = Application::builder()
        .application_id("org.hardn.gui")
        .build();

    app.connect_activate(|app| {
        let window = ApplicationWindow::builder()
            .application(app)
            .title("HARDN-XDR Security GUI")
            .default_width(900)
            .default_height(600)
            .build();

        let notebook = Notebook::new();

        // Create shared log view
        let log_view = TextView::new();
        log_view.set_editable(false);
        log_view.set_cursor_visible(false);
        let log_buffer = log_view.buffer().clone();

        let scroll_log = ScrolledWindow::builder()
            .child(&log_view)
            .vexpand(true)
            .hexpand(true)
            .build();

        // === Dashboard Tab ===
        let dashboard = Box::new(Orientation::Vertical, 10);
        let enable_all = Button::with_label("Enable All Security Tools");
        let disable_all = Button::with_label("Disable All Security Tools");
        let status_all = Button::with_label("Check All Status");
        dashboard.append(&enable_all);
        dashboard.append(&disable_all);
        dashboard.append(&status_all);
        dashboard.set_margin_top(20);
        dashboard.set_margin_start(20);

        // === Tools Tab ===
        let tools = Box::new(Orientation::Vertical, 8);
        let aide_btn = Button::with_label("Check AIDE");
        let rkhunter_btn = Button::with_label("Run rkhunter");
        let chkrootkit_btn = Button::with_label("Run chkrootkit");
        let fail2ban_btn = Button::with_label("Fail2Ban Status");
        let ufw_btn = Button::with_label("UFW Rules");
        let suricata_btn = Button::with_label("Test Suricata Config");

        for b in [&aide_btn, &rkhunter_btn, &chkrootkit_btn, &fail2ban_btn, &ufw_btn, &suricata_btn] {
            tools.append(b);
        }

        tools.set_margin_top(20);
        tools.set_margin_start(20);

        // === Logs Tab ===
        let logs_tab = Box::new(Orientation::Vertical, 5);
        let clear_btn = Button::with_label("Clear Logs");
        logs_tab.append(&scroll_log);
        logs_tab.append(&clear_btn);

        // Add tabs to notebook
        notebook.append_page(&dashboard, Some(&gtk::Label::new(Some("Dashboard"))));
        notebook.append_page(&tools, Some(&gtk::Label::new(Some("Tools"))));
        notebook.append_page(&logs_tab, Some(&gtk::Label::new(Some("Logs"))));

        window.set_child(Some(&notebook));
        window.show();

        // === Button Actions ===

        enable_all.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async(
                "sudo apt install -y ufw fail2ban apparmor aide suricata rkhunter chkrootkit firejail maldet && \
                 sudo systemctl enable --now ufw fail2ban apparmor suricata",
                &log_buffer
            );
        }));

        disable_all.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async(
                "sudo systemctl disable --now ufw fail2ban apparmor suricata",
                &log_buffer
            );
        }));

        status_all.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async(
                "echo '[*] UFW:' && sudo systemctl status ufw --no-pager && \
                 echo '\n[*] Fail2Ban:' && sudo systemctl status fail2ban --no-pager && \
                 echo '\n[*] AppArmor:' && sudo systemctl status apparmor --no-pager && \
                 echo '\n[*] Suricata:' && sudo systemctl status suricata --no-pager",
                &log_buffer
            );
        }));

        aide_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async("sudo aide --check", &log_buffer);
        }));

        rkhunter_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async("sudo rkhunter --check --sk", &log_buffer);
        }));

        chkrootkit_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async("sudo chkrootkit", &log_buffer);
        }));

        fail2ban_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async("sudo fail2ban-client status", &log_buffer);
        }));

        ufw_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async("sudo ufw status verbose", &log_buffer);
        }));

        suricata_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            run_command_async("sudo suricata -T", &log_buffer);
        }));

        clear_btn.connect_clicked(clone!(@strong log_buffer => move |_| {
            log_buffer.set_text("");
        }));
    });

    app.run();
}