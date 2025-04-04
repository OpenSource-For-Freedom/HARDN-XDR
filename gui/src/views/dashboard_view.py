#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Dashboard view for HARDN Security Interface
"""

from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QLabel, QFrame, QScrollArea

from gui.src.widgets.metric_card import MetricCard
from gui.src.widgets.threat_gauge import ThreatGauge
from gui.src.widgets.status_indicator import StatusIndicator


class DashboardView(QWidget):
    """Main dashboard view showing system status and security metrics"""
    
    def __init__(self, parent=None):
        """Initialize the dashboard view
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Setup UI
        self._setup_ui()
        
        # Setup demo values refresh timer
        self._refresh_timer = QTimer(self)
        self._refresh_timer.timeout.connect(self._update_demo_values)
        self._refresh_timer.start(5000)  # 5 seconds
        
    def _setup_ui(self):
        """Set up the dashboard UI"""
        # Main layout
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Top section - Summary and threat gauge
        top_section = QHBoxLayout()
        
        # System summary section
        summary_frame = QFrame()
        summary_frame.setObjectName("dashboardSummaryFrame")
        summary_frame.setFrameStyle(QFrame.StyledPanel)
        
        summary_layout = QVBoxLayout(summary_frame)
        
        # Title
        title_label = QLabel("SYSTEM SECURITY OVERVIEW")
        title_label.setObjectName("dashboardSectionTitle")
        title_font = QFont("Courier New", 14)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        summary_layout.addWidget(title_label)
        
        # Status indicators in a grid
        status_grid = QGridLayout()
        status_grid.setSpacing(15)
        
        # Row 1
        self.firewall_status = StatusIndicator(color="#00ff00", label="FIREWALL ACTIVE")
        status_grid.addWidget(self.firewall_status, 0, 0)
        
        self.ids_status = StatusIndicator(color="#00ff00", label="INTRUSION DETECTION")
        status_grid.addWidget(self.ids_status, 0, 1)
        
        # Row 2
        self.encryption_status = StatusIndicator(color="#00ff00", label="ENCRYPTION")
        status_grid.addWidget(self.encryption_status, 1, 0)
        
        self.updates_status = StatusIndicator(color="#ffaa00", pulse=True, label="UPDATES AVAILABLE")
        status_grid.addWidget(self.updates_status, 1, 1)
        
        # Row 3
        self.malware_status = StatusIndicator(color="#00ff00", label="MALWARE PROTECTION")
        status_grid.addWidget(self.malware_status, 2, 0)
        
        self.vpn_status = StatusIndicator(color="#00aaff", label="VPN ACTIVE")
        status_grid.addWidget(self.vpn_status, 2, 1)
        
        summary_layout.addLayout(status_grid)
        top_section.addWidget(summary_frame, 3)  # 3 units of stretch
        
        # Threat gauge
        gauge_frame = QFrame()
        gauge_frame.setObjectName("dashboardGaugeFrame")
        gauge_frame.setFrameStyle(QFrame.StyledPanel)
        
        gauge_layout = QVBoxLayout(gauge_frame)
        self.threat_gauge = ThreatGauge()
        self.threat_gauge.threat_level = 35  # Initial value
        gauge_layout.addWidget(self.threat_gauge)
        
        top_section.addWidget(gauge_frame, 2)  # 2 units of stretch
        
        layout.addLayout(top_section, 1)  # 1 unit of stretch
        
        # Middle section - Metric cards
        metrics_layout = QGridLayout()
        metrics_layout.setSpacing(10)
        
        # CPU metrics
        self.cpu_card = MetricCard(title="CPU USAGE", value="32%", icon="📈", color="#00ff00")
        self.cpu_card.subtitle = "8 cores @ 3.5 GHz"
        metrics_layout.addWidget(self.cpu_card, 0, 0)
        
        # Memory metrics
        self.memory_card = MetricCard(title="MEMORY", value="1.2 GB", icon="🧠", color="#00aaff")
        self.memory_card.subtitle = "8.0 GB total"
        metrics_layout.addWidget(self.memory_card, 0, 1)
        
        # Network metrics
        self.network_card = MetricCard(title="NETWORK", value="2.3 MB/s", icon="📡", color="#ffaa00")
        self.network_card.subtitle = "192.168.1.105"
        metrics_layout.addWidget(self.network_card, 0, 2)
        
        # Threat metrics
        self.threats_card = MetricCard(title="THREATS", value="NORMAL", icon="⚠️", color="#00ff00")
        self.threats_card.subtitle = "0 incidents detected"
        metrics_layout.addWidget(self.threats_card, 1, 0)
        
        # Scan metrics
        self.scan_card = MetricCard(title="LAST SCAN", value="12:45 PM", icon="🔍", color="#00aaff")
        self.scan_card.subtitle = "All systems clear"
        metrics_layout.addWidget(self.scan_card, 1, 1)
        
        # Connection metrics
        self.connections_card = MetricCard(title="CONNECTIONS", value="23", icon="🔌", color="#00ff00")
        self.connections_card.subtitle = "8 devices on network"
        metrics_layout.addWidget(self.connections_card, 1, 2)
        
        layout.addLayout(metrics_layout, 1)  # 1 unit of stretch
        
        # Bottom section - Recent activity (placeholder)
        activity_frame = QFrame()
        activity_frame.setObjectName("dashboardActivityFrame")
        activity_frame.setFrameStyle(QFrame.StyledPanel)
        
        activity_layout = QVBoxLayout(activity_frame)
        
        # Title
        activity_title = QLabel("RECENT SECURITY EVENTS")
        activity_title.setObjectName("dashboardSectionTitle")
        activity_title.setFont(title_font)
        activity_title.setAlignment(Qt.AlignCenter)
        activity_layout.addWidget(activity_title)
        
        # Activity list (scrollable)
        activity_scroll = QScrollArea()
        activity_scroll.setWidgetResizable(True)
        activity_scroll.setFrameStyle(QFrame.NoFrame)
        
        activity_content = QWidget()
        activity_content_layout = QVBoxLayout(activity_content)
        
        # Demo events
        event_style = "QLabel { color: #00ff00; background-color: #0a0a0a; padding: 5px; border: 1px solid #00aa00; }"
        
        event1 = QLabel("12:30:45 - System scan completed - No threats detected")
        event1.setStyleSheet(event_style)
        activity_content_layout.addWidget(event1)
        
        event2 = QLabel("12:15:22 - New device connected to network: Printer (192.168.1.110)")
        event2.setStyleSheet(event_style)
        activity_content_layout.addWidget(event2)
        
        warning_style = "QLabel { color: #ffaa00; background-color: #0a0a0a; padding: 5px; border: 1px solid #aa7700; }"
        event3 = QLabel("11:42:17 - WARNING: System updates available")
        event3.setStyleSheet(warning_style)
        activity_content_layout.addWidget(event3)
        
        event4 = QLabel("11:30:05 - Firewall updated to version 2.5.1")
        event4.setStyleSheet(event_style)
        activity_content_layout.addWidget(event4)
        
        event5 = QLabel("10:15:33 - Routine network diagnostic completed - All services operational")
        event5.setStyleSheet(event_style)
        activity_content_layout.addWidget(event5)
        
        activity_content_layout.addStretch(1)  # Add stretch at the end
        
        activity_scroll.setWidget(activity_content)
        activity_layout.addWidget(activity_scroll)
        
        layout.addWidget(activity_frame, 2)  # 2 units of stretch
        
    def _update_demo_values(self):
        """Update demo values with simulated changes"""
        import random
        
        # Update CPU usage (random values for demo)
        cpu_value = random.randint(25, 45)
        self.cpu_card.value = f"{cpu_value}%"
        
        # Update memory usage
        memory_value = round(random.uniform(1.0, 1.5), 1)
        self.memory_card.value = f"{memory_value} GB"
        
        # Update network speed
        network_value = round(random.uniform(1.8, 3.0), 1)
        self.network_card.value = f"{network_value} MB/s"
        
        # Update connections
        connections_value = random.randint(20, 30)
        self.connections_card.value = f"{connections_value}"
        
        # Occasionally update threat gauge
        if random.random() < 0.3:
            # 30% chance of changing threat level
            new_threat = self.threat_gauge.threat_level + random.randint(-5, 5)
            new_threat = max(0, min(100, new_threat))  # Keep within bounds
            self.threat_gauge.threat_level = new_threat
            
            # Update threat card based on gauge level
            if new_threat >= 90:
                self.threats_card.value = "CRITICAL"
                self.threats_card.color = "#ff0000"
                self.threats_card.subtitle = "5 incidents detected"
            elif new_threat >= 70:
                self.threats_card.value = "WARNING"
                self.threats_card.color = "#ffaa00"
                self.threats_card.subtitle = "3 incidents detected"
            else:
                self.threats_card.value = "NORMAL"
                self.threats_card.color = "#00ff00"
                self.threats_card.subtitle = "0 incidents detected"
                
    def showEvent(self, event):
        """Handle show event to start the refresh timer"""
        super().showEvent(event)
        self._refresh_timer.start()
        
    def hideEvent(self, event):
        """Handle hide event to stop the refresh timer"""
        self._refresh_timer.stop()
        super().hideEvent(event)
