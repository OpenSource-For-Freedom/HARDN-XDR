#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Network view for HARDN Security Interface
"""

from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame, 
    QTableWidget, QTableWidgetItem, QHeaderView
)


class NetworkView(QWidget):
    """Network monitoring view showing connections and traffic"""
    
    def __init__(self, parent=None):
        """Initialize the network view
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Setup UI
        self._setup_ui()
        
    def _setup_ui(self):
        """Set up the network view UI"""
        # Main layout
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Header with title
        header_frame = QFrame()
        header_frame.setObjectName("networkHeaderFrame")
        header_frame.setFrameStyle(QFrame.StyledPanel)
        header_frame.setMaximumHeight(80)
        
        header_layout = QHBoxLayout(header_frame)
        
        title_label = QLabel("NETWORK SECURITY MONITOR")
        title_label.setObjectName("viewTitle")
        title_font = QFont("Courier New", 18)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        header_layout.addWidget(title_label)
        
        layout.addWidget(header_frame)
        
        # Network connections table
        connections_frame = QFrame()
        connections_frame.setObjectName("networkConnectionsFrame")
        connections_frame.setFrameStyle(QFrame.StyledPanel)
        
        connections_layout = QVBoxLayout(connections_frame)
        
        connections_title = QLabel("ACTIVE CONNECTIONS")
        connections_title.setObjectName("sectionTitle")
        section_font = QFont("Courier New", 14)
        section_font.setBold(True)
        connections_title.setFont(section_font)
        connections_title.setAlignment(Qt.AlignCenter)
        connections_layout.addWidget(connections_title)
        
        # Create connections table
        self.connections_table = QTableWidget()
        self.connections_table.setColumnCount(5)
        self.connections_table.setHorizontalHeaderLabels([
            "IP Address", "Protocol", "Port", "Status", "Traffic"
        ])
        
        # Set column widths
        header = self.connections_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(2, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeToContents)
        
        # Add some sample data
        self._populate_sample_connections()
        
        connections_layout.addWidget(self.connections_table)
        layout.addWidget(connections_frame)
        
        # Network traffic frame
        traffic_frame = QFrame()
        traffic_frame.setObjectName("networkTrafficFrame")
        traffic_frame.setFrameStyle(QFrame.StyledPanel)
        
        traffic_layout = QVBoxLayout(traffic_frame)
        
        traffic_title = QLabel("TRAFFIC ANALYSIS")
        traffic_title.setObjectName("sectionTitle")
        traffic_title.setFont(section_font)
        traffic_title.setAlignment(Qt.AlignCenter)
        traffic_layout.addWidget(traffic_title)
        
        # Placeholder for traffic graph
        traffic_placeholder = QLabel("Network traffic visualization coming soon...")
        traffic_placeholder.setAlignment(Qt.AlignCenter)
        traffic_layout.addWidget(traffic_placeholder)
        
        layout.addWidget(traffic_frame)
        
    def _populate_sample_connections(self):
        """Add sample data to the connections table"""
        connections = [
            ("192.168.1.105", "TCP", "443", "ESTABLISHED", "1.2 MB/s"),
            ("192.168.1.110", "TCP", "80", "ESTABLISHED", "0.5 MB/s"),
            ("10.0.0.25", "UDP", "53", "ACTIVE", "0.1 MB/s"),
            ("172.16.0.12", "TCP", "22", "ESTABLISHED", "0.3 MB/s"),
            ("8.8.8.8", "UDP", "53", "ACTIVE", "0.2 MB/s"),
            ("203.0.113.45", "TCP", "443", "ESTABLISHED", "0.8 MB/s"),
            ("192.168.1.120", "TCP", "8080", "ESTABLISHED", "0.4 MB/s"),
            ("192.168.1.1", "TCP", "443", "ESTABLISHED", "0.6 MB/s"),
        ]
        
        self.connections_table.setRowCount(len(connections))
        
        for i, (ip, protocol, port, status, traffic) in enumerate(connections):
            self.connections_table.setItem(i, 0, QTableWidgetItem(ip))
            self.connections_table.setItem(i, 1, QTableWidgetItem(protocol))
            self.connections_table.setItem(i, 2, QTableWidgetItem(port))
            self.connections_table.setItem(i, 3, QTableWidgetItem(status))
            self.connections_table.setItem(i, 4, QTableWidgetItem(traffic))
            
            # Color code some rows
            if "8.8.8.8" in ip:
                # DNS server - highlight in blue
                for col in range(5):
                    self.connections_table.item(i, col).setBackground(
                        Qt.darkBlue
                    )
            elif "172.16" in ip:
                # Internal VPN - highlight in green
                for col in range(5):
                    self.connections_table.item(i, col).setBackground(
                        Qt.darkGreen
                    )
        
        self.connections_table.sortItems(0)  # Sort by IP
