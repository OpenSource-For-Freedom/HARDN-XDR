#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Threat analysis view for HARDN Security Interface
"""

from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont, QColor
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QLabel, QFrame, 
    QTableWidget, QTableWidgetItem, QHeaderView, QPushButton
)

from gui.src.widgets.threat_gauge import ThreatGauge


class ThreatView(QWidget):
    """Threat analysis view showing security incidents and threats"""
    
    def __init__(self, parent=None):
        """Initialize the threat view
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Setup UI
        self._setup_ui()
        
    def _setup_ui(self):
        """Set up the threat view UI"""
        # Main layout
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Header with title
        header_frame = QFrame()
        header_frame.setObjectName("threatHeaderFrame")
        header_frame.setFrameStyle(QFrame.StyledPanel)
        header_frame.setMaximumHeight(80)
        
        header_layout = QHBoxLayout(header_frame)
        
        title_label = QLabel("THREAT ANALYSIS CENTER")
        title_label.setObjectName("viewTitle")
        title_font = QFont("Courier New", 18)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        header_layout.addWidget(title_label)
        
        layout.addWidget(header_frame)
        
        # Top section with threat gauges and controls
        top_section = QHBoxLayout()
        
        # System threat gauge
        gauge_frame = QFrame()
        gauge_frame.setObjectName("threatGaugeFrame")
        gauge_frame.setFrameStyle(QFrame.StyledPanel)
        
        gauge_layout = QVBoxLayout(gauge_frame)
        
        gauge_title = QLabel("SYSTEM THREAT LEVEL")
        gauge_title.setObjectName("sectionTitle")
        section_font = QFont("Courier New", 14)
        section_font.setBold(True)
        gauge_title.setFont(section_font)
        gauge_title.setAlignment(Qt.AlignCenter)
        gauge_layout.addWidget(gauge_title)
        
        self.threat_gauge = ThreatGauge()
        self.threat_gauge.threat_level = 25  # Initial value
        gauge_layout.addWidget(self.threat_gauge)
        
        top_section.addWidget(gauge_frame)
        
        # Quick action buttons
        actions_frame = QFrame()
        actions_frame.setObjectName("threatActionsFrame")
        actions_frame.setFrameStyle(QFrame.StyledPanel)
        
        actions_layout = QVBoxLayout(actions_frame)
        
        actions_title = QLabel("THREAT RESPONSE")
        actions_title.setObjectName("sectionTitle")
        actions_title.setFont(section_font)
        actions_title.setAlignment(Qt.AlignCenter)
        actions_layout.addWidget(actions_title)
        
        buttons_grid = QGridLayout()
        buttons_grid.setSpacing(10)
        
        # Create action buttons
        scan_button = QPushButton("FULL SCAN")
        scan_button.setObjectName("actionButton")
        buttons_grid.addWidget(scan_button, 0, 0)
        
        isolate_button = QPushButton("ISOLATE SYSTEM")
        isolate_button.setObjectName("actionButton")
        buttons_grid.addWidget(isolate_button, 0, 1)
        
        block_button = QPushButton("BLOCK IP")
        block_button.setObjectName("actionButton")
        buttons_grid.addWidget(block_button, 1, 0)
        
        update_button = QPushButton("UPDATE DEFINITIONS")
        update_button.setObjectName("actionButton")
        buttons_grid.addWidget(update_button, 1, 1)
        
        quarantine_button = QPushButton("QUARANTINE")
        quarantine_button.setObjectName("actionButton")
        buttons_grid.addWidget(quarantine_button, 2, 0)
        
        report_button = QPushButton("GENERATE REPORT")
        report_button.setObjectName("actionButton")
        buttons_grid.addWidget(report_button, 2, 1)
        
        actions_layout.addLayout(buttons_grid)
        top_section.addWidget(actions_frame)
        
        layout.addLayout(top_section)
        
        # Detected threats table
        threats_frame = QFrame()
        threats_frame.setObjectName("threatListFrame")
        threats_frame.setFrameStyle(QFrame.StyledPanel)
        
        threats_layout = QVBoxLayout(threats_frame)
        
        threats_title = QLabel("DETECTED THREATS")
        threats_title.setObjectName("sectionTitle")
        threats_title.setFont(section_font)
        threats_title.setAlignment(Qt.AlignCenter)
        threats_layout.addWidget(threats_title)
        
        # Create threats table
        self.threats_table = QTableWidget()
        self.threats_table.setColumnCount(5)
        self.threats_table.setHorizontalHeaderLabels([
            "Timestamp", "Threat Type", "Source", "Severity", "Status"
        ])
        
        # Set column widths
        header = self.threats_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeToContents)
        
        # Add some sample data
        self._populate_sample_threats()
        
        threats_layout.addWidget(self.threats_table)
        layout.addWidget(threats_frame, 1)  # 1 = stretch factor
        
    def _populate_sample_threats(self):
        """Add sample data to the threats table"""
        threats = [
            ("2023-08-15 07:32:14", "Port Scan Attempt", "203.0.113.25", "Medium", "Blocked"),
            ("2023-08-14 23:15:06", "Malware Signature", "Email Attachment", "High", "Quarantined"),
            ("2023-08-14 18:42:51", "Suspicious Login", "192.168.1.105", "Medium", "Investigating"),
            ("2023-08-14 12:33:20", "SQL Injection Attempt", "Web Server", "Critical", "Blocked"),
            ("2023-08-13 09:30:45", "Unauthorized Access", "Admin Portal", "High", "Resolved"),
            ("2023-08-12 14:22:33", "DDoS Attempt", "Multiple Sources", "Medium", "Mitigated"),
            ("2023-08-10 10:15:28", "Outdated SSL Certificate", "mail.example.com", "Low", "Fixed"),
        ]
        
        self.threats_table.setRowCount(len(threats))
        
        # Severity colors
        severity_colors = {
            "Critical": QColor(255, 0, 0),      # Red
            "High": QColor(255, 100, 0),        # Orange
            "Medium": QColor(255, 200, 0),      # Yellow
            "Low": QColor(0, 200, 0),           # Green
        }
        
        # Status colors
        status_colors = {
            "Blocked": QColor(0, 150, 0),       # Green
            "Quarantined": QColor(0, 150, 0),   # Green
            "Resolved": QColor(0, 150, 0),      # Green
            "Fixed": QColor(0, 150, 0),         # Green
            "Mitigated": QColor(200, 200, 0),   # Yellow
            "Investigating": QColor(200, 100, 0), # Orange
        }
        
        for i, (timestamp, threat_type, source, severity, status) in enumerate(threats):
            self.threats_table.setItem(i, 0, QTableWidgetItem(timestamp))
            self.threats_table.setItem(i, 1, QTableWidgetItem(threat_type))
            self.threats_table.setItem(i, 2, QTableWidgetItem(source))
            
            severity_item = QTableWidgetItem(severity)
            if severity in severity_colors:
                severity_item.setForeground(severity_colors[severity])
                severity_item.setBackground(QColor(20, 20, 20))  # Dark background
            self.threats_table.setItem(i, 3, severity_item)
            
            status_item = QTableWidgetItem(status)
            if status in status_colors:
                status_item.setForeground(status_colors[status])
                status_item.setBackground(QColor(20, 20, 20))  # Dark background
            self.threats_table.setItem(i, 4, status_item)
            
        self.threats_table.sortItems(0, Qt.DescendingOrder)  # Sort by timestamp, newest first
