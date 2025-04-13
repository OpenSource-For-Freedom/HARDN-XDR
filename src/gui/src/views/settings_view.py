#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Settings view for HARDN Security Interface
"""

from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QLabel, QFrame,
    QCheckBox, QComboBox, QSpinBox, QPushButton, QTabWidget, QLineEdit,
    QGroupBox, QFormLayout, QSlider
)


class SettingsView(QWidget):
    """Settings view for configuring system parameters"""
    
    def __init__(self, parent=None):
        """Initialize the settings view
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Setup UI
        self._setup_ui()
        
    def _setup_ui(self):
        """Set up the settings view UI"""
        # Main layout
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Header with title
        header_frame = QFrame()
        header_frame.setObjectName("settingsHeaderFrame")
        header_frame.setFrameStyle(QFrame.StyledPanel)
        header_frame.setMaximumHeight(80)
        
        header_layout = QHBoxLayout(header_frame)
        
        title_label = QLabel("SYSTEM CONFIGURATION")
        title_label.setObjectName("viewTitle")
        title_font = QFont("Courier New", 18)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        header_layout.addWidget(title_label)
        
        layout.addWidget(header_frame)
        
        # Tabbed settings
        settings_tabs = QTabWidget()
        settings_tabs.setObjectName("settingsTabs")
        
        # Security Settings Tab
        security_tab = QWidget()
        security_layout = QVBoxLayout(security_tab)
        
        # Firewall settings group
        firewall_group = QGroupBox("Firewall Configuration")
        firewall_group.setObjectName("settingsGroup")
        firewall_layout = QFormLayout(firewall_group)
        
        firewall_enabled = QCheckBox("Enable Firewall")
        firewall_enabled.setChecked(True)
        firewall_layout.addRow("", firewall_enabled)
        
        firewall_level = QComboBox()
        firewall_level.addItems(["Low", "Medium", "High", "Custom"])
        firewall_level.setCurrentIndex(2)  # High
        firewall_layout.addRow("Security Level:", firewall_level)
        
        custom_rules_btn = QPushButton("Custom Rules")
        firewall_layout.addRow("", custom_rules_btn)
        
        security_layout.addWidget(firewall_group)
        
        # Scan settings group
        scan_group = QGroupBox("Scan Configuration")
        scan_group.setObjectName("settingsGroup")
        scan_layout = QFormLayout(scan_group)
        
        scan_interval = QComboBox()
        scan_interval.addItems(["Manual Only", "Daily", "Weekly", "Monthly"])
        scan_interval.setCurrentIndex(1)  # Daily
        scan_layout.addRow("Scan Interval:", scan_interval)
        
        scan_type = QComboBox()
        scan_type.addItems(["Quick Scan", "Full Scan", "Custom Scan"])
        scan_layout.addRow("Default Scan Type:", scan_type)
        
        auto_quarantine = QCheckBox("Auto-Quarantine Threats")
        auto_quarantine.setChecked(True)
        scan_layout.addRow("", auto_quarantine)
        
        security_layout.addWidget(scan_group)
        
        # Logging and alerting group
        logging_group = QGroupBox("Logging & Alerting")
        logging_group.setObjectName("settingsGroup")
        logging_group.setMinimumHeight(250)
        logging_layout = QFormLayout(logging_group)
        
        log_level = QComboBox()
        log_level.setMinimumWidth(300)
        log_level.addItems(["Error", "Warning", "Info", "Debug", "Trace"])
        log_level.setCurrentIndex(2)  # Info
        logging_layout.addRow("Log Level:", log_level)
        
        retention = QSpinBox()
        retention.setMinimumWidth(300)
        retention.setRange(7, 365)
        retention.setValue(30)
        retention.setSuffix(" days")
        logging_layout.addRow("Log Retention:", retention)
        
        alert_enabled = QCheckBox("Enable Alert Notifications")
        alert_enabled.setChecked(True)
        logging_layout.addRow("", alert_enabled)
        
        alert_level = QComboBox()
        alert_level.setMinimumWidth(300)
        alert_level.addItems(["Critical Only", "High & Critical", "Medium & Above", "All"])
        alert_level.setCurrentIndex(2)  # Medium & Above
        logging_layout.addRow("Alert Level:", alert_level)
        
        security_layout.addWidget(logging_group)
        
        # Add to tabs
        settings_tabs.addTab(security_tab, "Security")
        
        # Network Settings Tab
        network_tab = QWidget()
        network_layout = QVBoxLayout(network_tab)
        
        # Connection monitoring
        monitoring_group = QGroupBox("Connection Monitoring")
        monitoring_group.setObjectName("settingsGroup")
        monitoring_layout = QFormLayout(monitoring_group)
        
        monitor_enabled = QCheckBox("Monitor Network Traffic")
        monitor_enabled.setChecked(True)
        monitoring_layout.addRow("", monitor_enabled)
        
        detect_scan = QCheckBox("Detect Port Scans")
        detect_scan.setChecked(True)
        monitoring_layout.addRow("", detect_scan)
        
        detect_ddos = QCheckBox("Detect DDoS Attempts")
        detect_ddos.setChecked(True)
        monitoring_layout.addRow("", detect_ddos)
        
        network_layout.addWidget(monitoring_group)
        
        # IP Blocking
        blocking_group = QGroupBox("IP Blocking")
        blocking_group.setObjectName("settingsGroup")
        blocking_layout = QFormLayout(blocking_group)
        
        auto_block = QCheckBox("Auto-Block Malicious IPs")
        auto_block.setChecked(True)
        blocking_layout.addRow("", auto_block)
        
        block_duration = QSpinBox()
        block_duration.setMinimumHeight(30)
        block_duration.setRange(1, 999)
        block_duration.setValue(24)
        block_duration.setSuffix(" hours")
        block_duration.setStyleSheet("color: #00ff00;")  # Ensure text is bright green
        blocking_layout.addRow("Block Duration:", block_duration)
        
        
        # Create buttons
        whitelist_btn = QPushButton("Edit Whitelist")
        blacklist_btn = QPushButton("Edit Blacklist")

        # Create horizontal layout and add buttons
        button_layout = QHBoxLayout()
        button_layout.addWidget(whitelist_btn)
        button_layout.addWidget(blacklist_btn)

        # Add the horizontal layout to the form
        blocking_layout.addRow("", button_layout)
        
        network_layout.addWidget(blocking_group)
        
        # VPN Settings
        vpn_group = QGroupBox("VPN Configuration")
        vpn_group.setObjectName("settingsGroup")
        vpn_layout = QFormLayout(vpn_group)
        
        vpn_enabled = QCheckBox("Enable VPN")
        vpn_enabled.setChecked(True)
        vpn_layout.addRow("", vpn_enabled)
        
        vpn_server = QLineEdit("vpn.example.com")
        vpn_layout.addRow("VPN Server:", vpn_server)
        
        vpn_protocol = QComboBox()
        vpn_protocol.addItems(["OpenVPN", "WireGuard", "IKEv2", "L2TP/IPSec"])
        vpn_protocol.setCurrentIndex(1)  # WireGuard
        vpn_layout.addRow("Protocol:", vpn_protocol)
        
        network_layout.addWidget(vpn_group)
        
        # Add to tabs
        settings_tabs.addTab(network_tab, "Network")
        
        # UI Settings Tab
        ui_tab = QWidget()
        ui_layout = QVBoxLayout(ui_tab)
        
        # Theme settings
        theme_group = QGroupBox("Interface Theme")
        theme_group.setObjectName("settingsGroup")
        theme_layout = QFormLayout(theme_group)
        
        theme_selector = QComboBox()
        theme_selector.addItems(["Matrix Green", "Blue Steel", "Midnight Purple", "Orange Alert", "Custom"])
        theme_layout.addRow("Color Scheme:", theme_selector)
        
        animation_enabled = QCheckBox("Enable Animations")
        animation_enabled.setChecked(True)
        theme_layout.addRow("", animation_enabled)
        
        glow_intensity = QSlider(Qt.Horizontal)
        glow_intensity.setRange(0, 100)
        glow_intensity.setValue(70)
        theme_layout.addRow("Glow Intensity:", glow_intensity)
        
        font_size = QSpinBox()
        font_size.setRange(8, 16)
        font_size.setValue(11)
        font_size.setSuffix(" pt")
        theme_layout.addRow("Font Size:", font_size)
        
        ui_layout.addWidget(theme_group)
        
        # Notifications
        notif_group = QGroupBox("Notifications")
        notif_group.setObjectName("settingsGroup")
        notif_layout = QFormLayout(notif_group)
        
        sound_enabled = QCheckBox("Enable Sound Effects")
        sound_enabled.setChecked(True)
        notif_layout.addRow("", sound_enabled)
        
        desktop_notif = QCheckBox("Enable Desktop Notifications")
        desktop_notif.setChecked(True)
        notif_layout.addRow("", desktop_notif)
        
        ui_layout.addWidget(notif_group)
        
        # Add to tabs
        settings_tabs.addTab(ui_tab, "Interface")
        
        # Add tabs widget to main layout
        layout.addWidget(settings_tabs)
        
        # Buttons at bottom
        button_layout = QHBoxLayout()
        button_layout.addStretch(1)
        
        save_button = QPushButton("SAVE SETTINGS")
        save_button.setObjectName("primaryButton")
        button_layout.addWidget(save_button)
        
        reset_button = QPushButton("RESET TO DEFAULTS")
        button_layout.addWidget(reset_button)
        
        layout.addLayout(button_layout)
