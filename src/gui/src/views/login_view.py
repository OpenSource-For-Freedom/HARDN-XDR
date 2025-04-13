#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Login view for HARDN Security Interface
"""

import random
from PyQt5.QtCore import Qt, QTimer, QSize, pyqtSignal
from PyQt5.QtGui import QPainter, QColor, QFont, QPen, QBrush, QLinearGradient, QPixmap
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, 
    QFrame, QGridLayout, QCheckBox, QSizePolicy
)

from gui.src.widgets.matrix_rain import MatrixRain


class LoginView(QWidget):
    """Login view with Matrix-style authentication screen"""
    
    # Signal emitted when login is successful
    login_successful = pyqtSignal()
    
    def __init__(self, parent=None):
        """Initialize the login view
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Setup UI
        self._setup_ui()
        
        # Animation and effects
        self._setup_animations()
        
    def _setup_ui(self):
        """Set up the login UI"""
        # Main layout
        layout = QVBoxLayout(self)
        layout.setSpacing(0)
        layout.setContentsMargins(0, 0, 0, 0)

        # Matrix rain background (covers entire widget)
        self.matrix_rain = MatrixRain(density=3, speed=60)
        layout.addWidget(self.matrix_rain)

        # Login panel container (centered)
        self.login_container = QWidget(self)
        self.login_container.setObjectName("loginContainer")
        self.login_container.setFixedSize(400, 500)

        # Set main layout for login container
        login_layout = QVBoxLayout(self.login_container)
        login_layout.setSpacing(15)
        login_layout.setContentsMargins(20, 20, 20, 20)

        # Logo and title using vertical layout
        logo_layout = QVBoxLayout()
        logo_layout.setAlignment(Qt.AlignCenter)
        logo_layout.setSpacing(10)

        # Add the logo
        logo_label = QLabel()
        logo_pixmap = QPixmap("/home/testuser/HARDN/gui/src/resources/images/hardn_logo.png")
        logo_pixmap = logo_pixmap.scaled(80, 80, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        logo_label.setPixmap(logo_pixmap)
        logo_layout.addWidget(logo_label, 0, Qt.AlignCenter)

        # Add title
        title_label = QLabel("HARDN SECURITY")
        title_label.setObjectName("loginTitle")
        title_font = QFont("Courier New", 24, QFont.Bold)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        logo_layout.addWidget(title_label)

        # Add subtitle
        subtitle_label = QLabel("Hardened Autonomous Response Defense Network")
        subtitle_label.setObjectName("loginSubtitle")
        subtitle_font = QFont("Courier New", 10)
        subtitle_label.setFont(subtitle_font)
        subtitle_label.setAlignment(Qt.AlignCenter)
        logo_layout.addWidget(subtitle_label)

        # Add the logo layout to the main login layout
        login_layout.addLayout(logo_layout)

        # Add a separator
        separator = QFrame()
        separator.setFrameShape(QFrame.HLine)
        separator.setFrameShadow(QFrame.Sunken)
        separator.setObjectName("loginSeparator")
        login_layout.addWidget(separator)

        # Login form
        form_layout = QGridLayout()
        form_layout.setSpacing(15)

        username_label = QLabel("USERNAME")
        username_label.setObjectName("loginLabel")
        form_layout.addWidget(username_label, 0, 0)

        self.username_field = QLineEdit()
        self.username_field.setObjectName("loginField")
        self.username_field.setPlaceholderText("Enter username")
        form_layout.addWidget(self.username_field, 0, 1)

        password_label = QLabel("PASSWORD")
        password_label.setObjectName("loginLabel")
        form_layout.addWidget(password_label, 1, 0)

        self.password_field = QLineEdit()
        self.password_field.setObjectName("loginField")
        self.password_field.setEchoMode(QLineEdit.Password)
        self.password_field.setPlaceholderText("Enter password")
        form_layout.addWidget(self.password_field, 1, 1)

        login_layout.addLayout(form_layout)

        # Remember me checkbox
        remember_layout = QHBoxLayout()
        self.remember_checkbox = QCheckBox("Remember Credentials")
        self.remember_checkbox.setObjectName("loginCheckbox")
        remember_layout.addWidget(self.remember_checkbox)
        remember_layout.addStretch(1)
        login_layout.addLayout(remember_layout)

        # Login button
        self.login_button = QPushButton("ACCESS SYSTEM")
        self.login_button.setObjectName("loginButton")
        self.login_button.clicked.connect(self._handle_login)
        login_layout.addWidget(self.login_button)

        # Status message
        self.status_label = QLabel("")
        self.status_label.setObjectName("loginStatus")
        self.status_label.setAlignment(Qt.AlignCenter)
        login_layout.addWidget(self.status_label)

        # Stretcher at the bottom
        login_layout.addStretch(1)

        # Security note at bottom
        security_label = QLabel("SECURITY NOTICE: Unauthorized access is prohibited.")
        security_label.setObjectName("loginSecurityNotice")
        security_label.setAlignment(Qt.AlignCenter)
        login_layout.addWidget(security_label)

        # Ensure login_container is initially centered
        self._center_login_panel()

        
    def _setup_animations(self):
        """Set up animations and visual effects"""
        # Resize timer for keeping login panel centered during window resize
        self._resize_timer = QTimer(self)
        self._resize_timer.timeout.connect(self._center_login_panel)
        self._resize_timer.start(100)  # Check every 100ms
        
    def _center_login_panel(self):
        """Center the login panel in the widget"""
        if self.isVisible():
            self.login_container.setGeometry(
                (self.width() - self.login_container.width()) // 2,
                (self.height() - self.login_container.height()) // 2,
                self.login_container.width(),
                self.login_container.height()
            )
    
    def resizeEvent(self, event):
        """Handle window resize events"""
        super().resizeEvent(event)
        self._center_login_panel()
        
    def _handle_login(self):
        """Handle login button click"""
        username = self.username_field.text()
        password = self.password_field.text()
        
        # For demo purposes, accept any non-empty username/password
        if username and password:
            # Show authentication animation
            self.status_label.setText("AUTHENTICATING...")
            self.status_label.setStyleSheet("color: #00ff00;")
            
            # Simulate authentication delay
            QTimer.singleShot(1500, self._complete_login)
        else:
            self.status_label.setText("ERROR: INVALID CREDENTIALS")
            self.status_label.setStyleSheet("color: #ff0000;")
            
    def _complete_login(self):
        """Complete the login process after authentication"""
        self.status_label.setText("ACCESS GRANTED")
        
        # Emit login successful signal after a short delay
        QTimer.singleShot(500, self.login_successful.emit)
        
    def paintEvent(self, event):
        """Custom paint for login container with Matrix-style border effects"""
        super().paintEvent(event)
        
        # The matrix rain widget will automatically paint the background
        
        # Paint a semi-transparent border around the login container for better visibility
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Get login container rect
        rect = self.login_container.geometry()
        
        # Semi-transparent background for login panel
        bg_gradient = QLinearGradient(rect.topLeft(), rect.bottomRight())
        bg_gradient.setColorAt(0, QColor(0, 0, 0, 200))
        bg_gradient.setColorAt(0.5, QColor(0, 10, 0, 220))
        bg_gradient.setColorAt(1, QColor(0, 0, 0, 200))
        
        painter.fillRect(rect, bg_gradient)
        
        # Draw glowing border
        glow_pen = QPen(QColor("#00ff00"), 2)
        painter.setPen(glow_pen)
        painter.drawRect(rect)
