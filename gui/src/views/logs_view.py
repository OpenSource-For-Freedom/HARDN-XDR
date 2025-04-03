#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Logs view for HARDN Security Interface
"""

from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont, QTextCharFormat
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QFrame, QLabel, QComboBox,
    QLineEdit, QPushButton, QGroupBox, QPlainTextEdit, QToolButton
)

class LogsView(QWidget):
    """Logs view for displaying system and security events"""
    
    def __init__(self, parent=None):
        """Initialize the logs view
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Setup UI
        self._setup_ui()
        
    def _setup_ui(self):
        """Set up the logs view UI"""
        # Main layout
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Header with title
        header_frame = QFrame()
        header_frame.setObjectName("logsHeaderFrame")
        header_frame.setFrameStyle(QFrame.StyledPanel)
        header_frame.setMaximumHeight(80)
        
        header_layout = QHBoxLayout(header_frame)
        
        title_label = QLabel("SYSTEM LOGS")
        title_label.setObjectName("viewTitle")
        title_font = QFont("Courier New", 18)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        header_layout.addWidget(title_label)
        
        layout.addWidget(header_frame)
        
        # Filter controls
        filter_group = QGroupBox("Log Filters")
        filter_group.setObjectName("settingsGroup")
        filter_layout = QHBoxLayout(filter_group)
        
        # Date range filter
        date_layout = QVBoxLayout()
        date_layout.addWidget(QLabel("Date Range:"))
        
        date_range = QComboBox()
        date_range.addItems(["Last Hour", "Last 24 Hours", "Last 7 Days", "Last 30 Days", "All Logs"])
        date_range.setCurrentIndex(1)  # Last 24 Hours
        date_range.setMinimumWidth(200)
        date_layout.addWidget(date_range)
        
        filter_layout.addLayout(date_layout)
        
        # Log level filter
        level_layout = QVBoxLayout()
        level_layout.addWidget(QLabel("Log Level:"))
        
        level_filter = QComboBox()
        level_filter.addItems(["All Levels", "Error+", "Warning+", "Info+", "Debug+"])
        level_filter.setCurrentIndex(2)  # Warning+
        level_filter.setMinimumWidth(200)
        level_layout.addWidget(level_filter)
        
        filter_layout.addLayout(level_layout)
        
        # Log type filter
        type_layout = QVBoxLayout()
        type_layout.addWidget(QLabel("Log Type:"))
        
        type_filter = QComboBox()
        type_filter.addItems(["All Types", "System", "Security", "Network", "User"])
        type_filter.setCurrentIndex(0)  # All Types
        type_filter.setMinimumWidth(200)
        type_layout.addWidget(type_filter)
        
        filter_layout.addLayout(type_layout)
        
        # Search box
        search_layout = QVBoxLayout()
        search_layout.addWidget(QLabel("Search:"))
        
        search_box = QLineEdit()
        search_box.setPlaceholderText("Search logs...")
        search_box.setMinimumWidth(300)
        search_layout.addWidget(search_box)
        
        filter_layout.addLayout(search_layout)
        
        # Filter button
        btn_layout = QVBoxLayout()
        btn_layout.addWidget(QLabel(""))  # Empty label for alignment
        
        filter_btn = QPushButton("Apply Filters")
        filter_btn.setObjectName("primaryButton")
        btn_layout.addWidget(filter_btn)
        
        filter_layout.addLayout(btn_layout)
        
        layout.addWidget(filter_group)
        
        # Log display area
        log_display = QPlainTextEdit()
        log_display.setReadOnly(True)
        log_display.setFont(QFont("Courier New", 10))
        log_display.setStyleSheet("background-color: #000000; color: #00ff00; border: 1px solid #00ff00;")
        log_display.setMinimumHeight(400)
        
        # Add some sample logs
        sample_logs = [
            "[2025-03-31 10:15:22] [INFO] [SYSTEM] System startup complete",
            "[2025-03-31 10:18:47] [INFO] [NETWORK] Network interfaces initialized",
            "[2025-03-31 11:32:19] [WARNING] [SECURITY] Failed login attempt from 192.168.1.105",
            "[2025-03-31 11:33:05] [WARNING] [SECURITY] Failed login attempt from 192.168.1.105",
            "[2025-03-31 11:33:42] [WARNING] [SECURITY] Failed login attempt from 192.168.1.105",
            "[2025-03-31 11:34:01] [CRITICAL] [SECURITY] IP 192.168.1.105 blocked for suspicious activity",
            "[2025-03-31 12:45:33] [INFO] [SYSTEM] Scan scheduled for 13:00",
            "[2025-03-31 13:00:00] [INFO] [SYSTEM] Starting scheduled scan",
            "[2025-03-31 13:15:27] [INFO] [SYSTEM] Scan completed - No threats detected",
            "[2025-03-31 13:22:18] [DEBUG] [NETWORK] Connection statistics: RX: 1.2GB, TX: 0.3GB"
        ]
        
        for log in sample_logs:
            # Color-code log entries based on log level
            if "[CRITICAL]" in log or "[ERROR]" in log:
                log_display.appendHtml(f'<span style="color: #ff0000;">{log}</span>')
            elif "[WARNING]" in log:
                log_display.appendHtml(f'<span style="color: #ffaa00;">{log}</span>')
            else:
                log_display.appendHtml(f'<span style="color: #00ff00;">{log}</span>')
        
        layout.addWidget(log_display)
        
        # Control buttons
        button_layout = QHBoxLayout()
        
        refresh_btn = QPushButton("Refresh")
        export_btn = QPushButton("Export Logs")
        clear_btn = QPushButton("Clear Filters")
        
        button_layout.addWidget(refresh_btn)
        button_layout.addWidget(export_btn)
        button_layout.addWidget(clear_btn)
        button_layout.addStretch(1)
        
        layout.addLayout(button_layout)