#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Main window for HARDN Security Interface
"""

import os
from PyQt5.QtCore import Qt, QSize, QTimer
from PyQt5.QtGui import QIcon, QFont, QPixmap
from PyQt5.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QStackedWidget, QPushButton, QLabel, QFrame,
    QSizePolicy, QToolButton, QApplication
)

from gui.src.views.login_view import LoginView
from gui.src.views.dashboard_view import DashboardView
from gui.src.views.network_view import NetworkView
from gui.src.views.threat_view import ThreatView
from gui.src.views.settings_view import SettingsView
from gui.src.widgets.terminal_console import TerminalConsole
from gui.src.views.logs_view import LogsView

class MainWindow(QMainWindow):
    """Main window for the HARDN Security Interface application"""
    
    def __init__(self):
        """Initialize the main window"""
        super().__init__()
        
        # Setup window properties
        self.setWindowTitle("HARDN Security Interface")
        self.setMinimumSize(1200, 800)
        self.showMaximized()  # Start maximized
        
        # Set window style
        self._setup_window_style()
        
        # Setup UI components
        self._setup_ui()
        
        # Show login view first
        self._show_login_view()
    
    def _setup_window_style(self):
        """Set up the window style"""
        # Global stylesheet to implement Matrix theme
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #000000;
                color: #00ff00;
            }
            
            QLabel {
                color: #00ff00;
                font-family: 'Courier New';
            }
            
            QPushButton, QToolButton {
                background-color: #000000;
                color: #00ff00;
                border: 1px solid #00ff00;
                border-radius: 2px;
                padding: 5px;
                font-family: 'Courier New';
                font-weight: bold;
            }
            
            QPushButton:hover, QToolButton:hover {
                background-color: #003300;
            }
            
            QPushButton:pressed, QToolButton:pressed {
                background-color: #005500;
            }
            
            QPushButton:checked, QToolButton:checked {
                background-color: #004400;
                border: 2px solid #00ff00;
            }
            
            QLineEdit, QTextEdit, QPlainTextEdit {
                background-color: #000000;
                color: #00ff00;
                border: 1px solid #00aa00;
                border-radius: 2px;
                padding: 3px;
                font-family: 'Courier New';
            }
            
            QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus {
                border: 1px solid #00ff00;
            }
            
            QFrame#mainSidebar {
                background-color: #001100;
                border-right: 1px solid #00aa00;
            }
            
            QPushButton#navButton {
                text-align: left;
                padding: 10px;
                border: none;
                border-left: 3px solid transparent;
            }
            
            QPushButton#navButton:checked {
                background-color: #003300;
                border-left: 3px solid #00ff00;
            }
            
            QLabel#navHeader {
                font-size: 16px;
                font-weight: bold;
                padding: 10px;
            }
            
            QLabel#loginTitle {
                color: #00ff00;
                font-size: 24px;
                font-weight: bold;
            }
            
            QLabel#loginSubtitle {
                color: #00aa00;
                font-size: 12px;
            }
            
            QFrame#loginSeparator {
                background-color: #00aa00;
            }
            
            QLabel#loginLabel {
                font-weight: bold;
                color: #00dd00;
            }
            
            QLineEdit#loginField {
                background-color: #001100;
                border: 1px solid #00aa00;
                padding: 8px;
            }
            
            QPushButton#loginButton {
                background-color: #004400;
                padding: 10px;
                font-size: 14px;
            }
            
            QCheckBox#loginCheckbox {
                font-family: 'Courier New';
                color: #00aa00;
            }
            
            QLabel#loginSecurityNotice {
                color: #008800;
                font-size: 9px;
            }
            
            QLabel#loginStatus {
                font-weight: bold;
                font-family: 'Courier New';
                font-size: 12px;
            }
            
            QFrame#statusBar {
                background-color: #001100;
                border-top: 1px solid #00aa00;
            }
            
            QLabel#statusBarLabel {
                color: #00aa00;
                font-size: 11px;
            }
            
            QLabel#viewHeader {
                font-size: 18px;
                font-weight: bold;
                font-family: 'Courier New';
                color: #00ff00;
                padding: 5px;
            }
        """)
        
    def _setup_ui(self):
        """Set up the main UI components"""
        # Central widget and main layout
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
    
        # Main layout will be created based on whether user is logged in or not
        self.main_layout = QVBoxLayout(self.central_widget)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)
    
        # Stacked widget to manage different views/states
        self.stacked_widget = QStackedWidget()
        self.main_layout.addWidget(self.stacked_widget)
    
        # Create views
        self._create_views()
    
    def _create_views(self):
        """Create all application views"""
        # Login view
        self.login_view = LoginView()
        self.login_view.login_successful.connect(self._handle_login_success)
        self.stacked_widget.addWidget(self.login_view)
        
        # Create main application view (initially hidden)
        self.app_container = QWidget()
        self.app_layout = QHBoxLayout(self.app_container)
        self.app_layout.setContentsMargins(0, 0, 0, 0)
        self.app_layout.setSpacing(0)
        self.stacked_widget.addWidget(self.app_container)
        
        # Create sidebar
        self._create_sidebar()
        
        # Create content area
        self._create_content_area()
        
        # Create status bar
        self._create_status_bar()
    
    def _create_sidebar(self):
        """Create the sidebar navigation panel"""
        # Sidebar container
        self.sidebar = QFrame()
        self.sidebar.setObjectName("mainSidebar")
        self.sidebar.setFixedWidth(200)
        
        # Sidebar layout
        sidebar_layout = QVBoxLayout(self.sidebar)
        sidebar_layout.setContentsMargins(0, 10, 0, 10)
        sidebar_layout.setSpacing(5)
        
        # Logo and title
        logo_layout = QHBoxLayout()
        logo_layout.setContentsMargins(10, 5, 10, 15)
        
        title_label = QLabel("HARDN")
        title_label.setObjectName("navHeader")
        logo_layout.addWidget(title_label)
        sidebar_layout.addLayout(logo_layout)
        
        # Navigation buttons
        self.nav_buttons = []
        
        # Dashboard button
        self.dashboard_btn = QPushButton("DASHBOARD")
        self.dashboard_btn.setObjectName("navButton")
        self.dashboard_btn.setCheckable(True)
        self.dashboard_btn.setChecked(True)  # Default selected
        self.dashboard_btn.clicked.connect(lambda: self._switch_view(0))
        sidebar_layout.addWidget(self.dashboard_btn)
        self.nav_buttons.append(self.dashboard_btn)
        
        # Network button
        self.network_btn = QPushButton("NETWORK")
        self.network_btn.setObjectName("navButton")
        self.network_btn.setCheckable(True)
        self.network_btn.clicked.connect(lambda: self._switch_view(1))
        sidebar_layout.addWidget(self.network_btn)
        self.nav_buttons.append(self.network_btn)
        
        # Threats button
        self.threats_btn = QPushButton("THREATS")
        self.threats_btn.setObjectName("navButton")
        self.threats_btn.setCheckable(True)
        self.threats_btn.clicked.connect(lambda: self._switch_view(2))
        sidebar_layout.addWidget(self.threats_btn)
        self.nav_buttons.append(self.threats_btn)

        # After your settings button, add a logs button
        self.logs_btn = QPushButton("LOGS")
        self.logs_btn.setObjectName("navButton")
        self.logs_btn.setCheckable(True)
        self.logs_btn.clicked.connect(lambda: self._switch_view(3))  # Index 4 for logs view
        sidebar_layout.addWidget(self.logs_btn)
        self.nav_buttons.append(self.logs_btn)
        
        # Settings button
        self.settings_btn = QPushButton("SETTINGS")
        self.settings_btn.setObjectName("navButton")
        self.settings_btn.setCheckable(True)
        self.settings_btn.clicked.connect(lambda: self._switch_view(4))
        sidebar_layout.addWidget(self.settings_btn)
        self.nav_buttons.append(self.settings_btn)
        
        # Spacer
        sidebar_layout.addStretch(1)
        
        # Terminal button
        self.terminal_btn = QPushButton("TERMINAL")
        self.terminal_btn.setObjectName("navButton")
        self.terminal_btn.setCheckable(True)
        self.terminal_btn.clicked.connect(self._toggle_terminal)
        sidebar_layout.addWidget(self.terminal_btn)
        self.nav_buttons.append(self.terminal_btn)
        
        # Logout button
        self.logout_btn = QPushButton("LOGOUT")
        self.logout_btn.setObjectName("navButton")
        self.logout_btn.clicked.connect(self._handle_logout)
        sidebar_layout.addWidget(self.logout_btn)
        
        # Add sidebar to main app layout
        self.app_layout.addWidget(self.sidebar)
    
    def _create_content_area(self):
        """Create the main content area"""
        # Content container
        self.content_container = QWidget()
        content_layout = QVBoxLayout(self.content_container)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(0)
        
        # Stacked widget for different views
        self.view_stack = QStackedWidget()
        content_layout.addWidget(self.view_stack)
        
        # Create views
        self.dashboard_view = DashboardView()
        self.view_stack.addWidget(self.dashboard_view)
        
        self.network_view = NetworkView()
        self.view_stack.addWidget(self.network_view)
        
        self.threat_view = ThreatView()
        self.view_stack.addWidget(self.threat_view)
        
        self.logs_view = LogsView()
        self.view_stack.addWidget(self.logs_view)
        
        self.settings_view = SettingsView()
        self.view_stack.addWidget(self.settings_view)
        # Terminal console (initially hidden)
        self.terminal_container = QWidget()
        self.terminal_container.setVisible(False)
        self.terminal_container.setFixedHeight(250)
        
        terminal_layout = QVBoxLayout(self.terminal_container)
        terminal_layout.setContentsMargins(0, 0, 0, 0)
        terminal_layout.setSpacing(0)
        
        # Terminal header
        terminal_header = QFrame()
        terminal_header.setObjectName("terminalHeader")
        terminal_header.setFixedHeight(25)
        terminal_header_layout = QHBoxLayout(terminal_header)
        terminal_header_layout.setContentsMargins(10, 0, 10, 0)
        
        terminal_title = QLabel("SYSTEM TERMINAL")
        terminal_title.setObjectName("terminalTitle")
        terminal_header_layout.addWidget(terminal_title)
        
        terminal_header_layout.addStretch(1)
        
        close_btn = QToolButton()
        close_btn.setText("X")
        close_btn.setObjectName("terminalCloseButton")
        close_btn.clicked.connect(self._toggle_terminal)
        terminal_header_layout.addWidget(close_btn)
        
        terminal_layout.addWidget(terminal_header)
        
        # Terminal console
        self.terminal_console = TerminalConsole()
        terminal_layout.addWidget(self.terminal_console)
        
        # Add terminal to content layout
        content_layout.addWidget(self.terminal_container)
        
        # Add content container to main app layout
        self.app_layout.addWidget(self.content_container)
    
    def _create_status_bar(self):
        """Create a custom status bar at the bottom of the application"""
        self.status_frame = QFrame()
        self.status_frame.setObjectName("statusBar")
        self.status_frame.setFixedHeight(25)
        
        status_layout = QHBoxLayout(self.status_frame)
        status_layout.setContentsMargins(10, 0, 10, 0)
        
        # Status text
        self.status_text = QLabel("SYSTEM STATUS: SECURE | CPU: 12% | MEMORY: 1.2GB | THREATS DETECTED: 0")
        self.status_text.setObjectName("statusBarLabel")
        status_layout.addWidget(self.status_text)
        
        # Date/Time
        self.time_label = QLabel("2023-08-21 14:32:45")
        self.time_label.setObjectName("statusBarLabel")
        status_layout.addWidget(self.time_label, 0, Qt.AlignRight)
        
        # Update timer for the status bar
        self.status_timer = QTimer(self)
        self.status_timer.timeout.connect(self._update_status_bar)
        
        # Add status bar to main layout
        self.main_layout.addWidget(self.status_frame)
        
        # Initially hide the status bar until logged in
        self.status_frame.setVisible(False)
    
    def _update_status_bar(self):
        """Update status bar information"""
        import datetime
        import random
        
        # Update time
        current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.time_label.setText(current_time)
        
        # Simulate system stats
        cpu = random.randint(5, 20)
        memory = round(random.uniform(0.8, 1.8), 1)
        
        # Get threat level from threat view
        threat_count = 0
        if hasattr(self, 'threat_view') and hasattr(self.threat_view, 'threat_gauge'):
            threat_level = self.threat_view.threat_gauge.threat_level
            threat_count = int(threat_level / 10)  # Approximate threats from gauge level
        
        # Get system status
        status = "SECURE"
        if threat_count > 5:
            status = "WARNING"
        elif threat_count > 10:
            status = "CRITICAL"
        
        self.status_text.setText(f"SYSTEM STATUS: {status} | CPU: {cpu}% | MEMORY: {memory}GB | THREATS DETECTED: {threat_count}")
    
    def _show_login_view(self):
        """Show the login view"""
        # Hide the status bar
        if hasattr(self, 'status_frame'):
            self.status_frame.setVisible(False)
        
        # Show login in stacked widget
        self.stacked_widget.setCurrentIndex(0)
    
    def _handle_login_success(self):
        """Handle successful login"""
        # Switch to main application view
        self.stacked_widget.setCurrentIndex(1)
        
        # Show the status bar
        self.status_frame.setVisible(True)
        
        # Start status update timer
        self.status_timer.start(1000)  # Update every second
    
    def _handle_logout(self):
        """Handle logout button click"""
        # Stop status update timer
        self.status_timer.stop()
        
        # Switch back to login view
        self._show_login_view()
        
        # Clear login fields
        self.login_view.username_field.clear()
        self.login_view.password_field.clear()
        self.login_view.status_label.clear()
    
    def _switch_view(self, index):
        """Switch between main application views
        
        Args:
            index: Index of the view to switch to
        """
        # Uncheck all nav buttons
        for btn in self.nav_buttons:
            btn.setChecked(False)
        
        # Check the selected button (except terminal which is special case)
        if index < 5:  # Only handle main views (not terminal)
            self.nav_buttons[index].setChecked(True)
            
            # Change view
            self.view_stack.setCurrentIndex(index)
    
    def _toggle_terminal(self):
        """Toggle the terminal console visibility"""
        is_visible = self.terminal_container.isVisible()
        self.terminal_container.setVisible(not is_visible)
        self.terminal_btn.setChecked(not is_visible)
        
        if not is_visible:
            # Focus the terminal when shown
            self.terminal_console.setFocus()
            
            # Write welcome message if empty
            if self.terminal_console.toPlainText() == "":
                self.terminal_console.write_output("HARDN Terminal v1.0.0")
                self.terminal_console.write_output("Type 'help' for a list of available commands.")
                self.terminal_console.write_output("")
    
    def closeEvent(self, event):
        """Handle window close event"""
        # Stop any timers
        if hasattr(self, 'status_timer'):
            self.status_timer.stop()
        
        # Accept the close event
        event.accept() 