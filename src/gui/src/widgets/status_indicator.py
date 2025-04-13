#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Status indicators for HARDN Security Interface
"""

import math
from PyQt5.QtCore import Qt, QTimer, QRectF, pyqtProperty, pyqtSlot
from PyQt5.QtGui import QPainter, QColor, QPen, QFont, QBrush, QRadialGradient, QPainterPath
from PyQt5.QtWidgets import QWidget


class StatusIndicator(QWidget):
    """Status indicator widget that shows an LED-like indicator with Matrix styling"""
    
    def __init__(self, parent=None, color="#00ff00", size=16, pulse=False, label=""):
        """Initialize the status indicator
        
        Args:
            parent: Parent widget
            color: Indicator color as hex string
            size: Indicator size in pixels
            pulse: Whether to use pulsing animation
            label: Optional text label
        """
        super().__init__(parent)
        
        # Properties
        self._color = QColor(color)
        self._size = size
        self._pulse = pulse
        self._label = label
        self._state = True  # On/Off state
        
        # Animation
        self._pulse_opacity = 1.0
        self._pulse_growing = False
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update_pulse)
        
        # Glow effect
        self._glow_intensity = 0.0
        self._glow_increasing = True
        self._glow_timer = QTimer(self)
        self._glow_timer.timeout.connect(self._update_glow)
        self._glow_timer.start(30)
        
        # Digital scan animation
        self._scan_offset = 0
        self._scan_timer = QTimer(self)
        self._scan_timer.timeout.connect(self._update_scan)
        self._scan_timer.start(50)
        
        # Size policy
        min_width = max(size * 2, 100) if label else size * 2
        self.setMinimumSize(min_width, size * 2)
        
        # Start animation if needed
        if pulse:
            self._timer.start(50)  # 50ms updates for smooth animation

    @pyqtProperty(QColor)
    def color(self):
        """Get indicator color"""
        return self._color
        
    @color.setter
    def color(self, color):
        """Set indicator color"""
        if isinstance(color, str):
            self._color = QColor(color)
        else:
            self._color = color
        self.update()
        
    @pyqtProperty(int)
    def size(self):
        """Get indicator size"""
        return self._size
        
    @size.setter
    def size(self, size):
        """Set indicator size"""
        self._size = size
        min_width = max(size * 2, 100) if self._label else size * 2
        self.setMinimumSize(min_width, size * 2)
        self.update()
        
    @pyqtProperty(bool)
    def pulse(self):
        """Get pulse animation state"""
        return self._pulse
        
    @pulse.setter
    def pulse(self, pulse):
        """Set pulse animation state"""
        self._pulse = pulse
        if pulse and not self._timer.isActive():
            self._timer.start(50)
        elif not pulse and self._timer.isActive():
            self._timer.stop()
        self.update()
        
    @pyqtProperty(str)
    def label(self):
        """Get indicator label"""
        return self._label
        
    @label.setter
    def label(self, label):
        """Set indicator label"""
        self._label = label
        min_width = max(self._size * 2, 100) if label else self._size * 2
        self.setMinimumSize(min_width, self._size * 2)
        self.update()
        
    @pyqtProperty(bool)
    def state(self):
        """Get indicator state (on/off)"""
        return self._state
        
    @state.setter
    def state(self, state):
        """Set indicator state (on/off)"""
        self._state = bool(state)
        self.update()
        
    @pyqtSlot()
    def _update_pulse(self):
        """Update pulse animation state"""
        pulse_step = 0.05
        
        if self._pulse_growing:
            self._pulse_opacity += pulse_step
            if self._pulse_opacity >= 1.0:
                self._pulse_opacity = 1.0
                self._pulse_growing = False
        else:
            self._pulse_opacity -= pulse_step
            if self._pulse_opacity <= 0.3:
                self._pulse_opacity = 0.3
                self._pulse_growing = True
                
        self.update()
        
    @pyqtSlot()
    def _update_glow(self):
        """Update glow animation effect"""
        step = 0.03
        
        if self._glow_increasing:
            self._glow_intensity += step
            if self._glow_intensity >= 1.0:
                self._glow_intensity = 1.0
                self._glow_increasing = False
        else:
            self._glow_intensity -= step
            if self._glow_intensity <= 0.3:
                self._glow_intensity = 0.3
                self._glow_increasing = True
        
        # Only update if state is on and pulse is active or critical color
        if self._state and (self._pulse or self._color.red() > 200):
            self.update()
    
    @pyqtSlot()
    def _update_scan(self):
        """Update digital scan animation"""
        self._scan_offset = (self._scan_offset + 1) % 100
        
        # Only update if state is on and pulse is active
        if self._state and self._pulse:
            self.update()
        
    def paintEvent(self, event):
        """Paint the status indicator with Matrix styling"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Get drawing area
        rect = self.rect()
        center_x = rect.center().x()
        if self._label:
            # If we have a label, position the indicator on the left
            indicator_center_x = self._size + 10
            indicator_center_y = rect.center().y()
            
            # Position label to the right of the indicator
            label_rect = QRectF(indicator_center_x + self._size + 5, rect.top(), 
                               rect.width() - indicator_center_x - self._size - 5, rect.height())
        else:
            # Without label, center the indicator
            indicator_center_x = rect.center().x()
            indicator_center_y = rect.center().y()
        
        # Determine indicator color and opacity
        if self._state:
            if self._pulse:
                indicator_color = QColor(self._color)
                indicator_color.setAlphaF(self._pulse_opacity)
            else:
                indicator_color = self._color
        else:
            # Dimmed color for off state
            indicator_color = QColor(self._color.red() * 0.3, 
                                   self._color.green() * 0.3,
                                   self._color.blue() * 0.3)
        
        # Draw digital circuit background
        if self._state:
            # Draw subtle circuit pattern behind active indicator
            circuit_pen = QPen(indicator_color)
            circuit_pen.setWidthF(0.5)
            circuit_pen.setStyle(Qt.DotLine)
            painter.setPen(circuit_pen)
            
            # Horizontal circuit line
            painter.drawLine(indicator_center_x - self._size * 2, indicator_center_y,
                            indicator_center_x + self._size * 2, indicator_center_y)
            
            # Vertical circuit line
            painter.drawLine(int(indicator_center_x), int(indicator_center_y - self._size * 1.5),
                int(indicator_center_x), int(indicator_center_y + self._size * 1.5))
                            
            # Draw small connecting nodes
            for angle in range(0, 360, 90):
                node_x = indicator_center_x + math.cos(math.radians(angle)) * self._size * 1.5
                node_y = indicator_center_y + math.sin(math.radians(angle)) * self._size * 1.5
                
                painter.drawEllipse(int(node_x - 1), int(node_y - 1), 2, 2)
        
        # Draw digital scan lines if active
        if self._state and self._pulse:
            scan_height = 2
            scan_y = indicator_center_y - self._size + (self._scan_offset * self._size * 2) / 100
            
            if scan_y < indicator_center_y + self._size:
                scan_color = QColor(indicator_color)
                scan_color.setAlphaF(0.5)
                
                painter.setPen(Qt.NoPen)
                painter.setBrush(scan_color)
                painter.drawRect(QRectF(
                    indicator_center_x - self._size,
                    scan_y - scan_height / 2,
                    self._size * 2,
                    scan_height
                ))
        
        # Draw indicator glow (only when on)
        if self._state:
            # Create radial gradient for glow effect
            gradient = QRadialGradient(
                indicator_center_x, indicator_center_y, self._size * 1.5
            )
            
            # Determine glow intensity
            glow_alpha = 0.3
            if self._pulse:
                glow_alpha = 0.1 + self._glow_intensity * 0.2
            elif self._color.red() > 200:  # Warning color (red)
                glow_alpha = 0.1 + self._glow_intensity * 0.3
                
            glow_color = QColor(indicator_color)
            glow_color.setAlphaF(glow_alpha)
            
            gradient.setColorAt(0, glow_color)
            gradient.setColorAt(0.5, QColor(glow_color.red(), glow_color.green(), glow_color.blue(), 0))
            gradient.setColorAt(1, Qt.transparent)
            
            painter.setPen(Qt.NoPen)
            painter.setBrush(QBrush(gradient))
            painter.drawEllipse(
                int(indicator_center_x - self._size * 1.5),
                int(indicator_center_y - self._size * 1.5),
                int(self._size * 3),
                int(self._size * 3)
            )
            
        # Draw indicator background
        painter.setPen(Qt.NoPen)
        bg_color = QColor(20, 20, 20)  # Dark background
        painter.setBrush(bg_color)
        painter.drawEllipse(
            int(indicator_center_x - self._size),
            int(indicator_center_y - self._size),
            int(self._size * 2),
            int(self._size * 2)
        )
        
        # Draw indicator fill
        painter.setPen(Qt.NoPen)
        painter.setBrush(indicator_color)
        
        # Digital-style indicator (hexagonal for Matrix feel)
        if self._size >= 10:
            # For larger indicators, use hexagon shape for Matrix-like style
            hex_points = []
            for i in range(6):
                angle = i * 60
                x = indicator_center_x + math.cos(math.radians(angle)) * self._size * 0.8
                y = indicator_center_y + math.sin(math.radians(angle)) * self._size * 0.8
                hex_points.append((x, y))
                
            # Draw hexagon
            path = QPainterPath()
            path.moveTo(hex_points[0][0], hex_points[0][1])
            for x, y in hex_points[1:]:
                path.lineTo(x, y)
            path.closeSubpath()
            painter.drawPath(path)
            
            # Add digital hash marks
            painter.setPen(QPen(QColor(0, 0, 0, 100), 1))
            for i in range(0, 6, 2):
                painter.drawLine(
                    int(indicator_center_x), int(indicator_center_y),
                    int(hex_points[i][0]), int(hex_points[i][1])
                )
        else:
            # For small indicators, use circle
            painter.drawEllipse(
                indicator_center_x - self._size * 0.8,
                indicator_center_y - self._size * 0.8,
                self._size * 1.6,
                self._size * 1.6
            )
        
        # Draw indicator border
        painter.setPen(QPen(QColor(indicator_color).darker(120), 1))
        painter.setBrush(Qt.NoBrush)
        painter.drawEllipse(
            indicator_center_x - self._size,
            indicator_center_y - self._size,
            self._size * 2,
            self._size * 2
        )
        
        # Draw highlight reflection
        if self._state:
            highlight = QPainterPath()
            highlight.addEllipse(
                indicator_center_x - self._size * 0.4,
                indicator_center_y - self._size * 0.4,
                self._size * 0.5,
                self._size * 0.5
            )
            
            highlight_color = QColor(255, 255, 255, 120)
            painter.setPen(Qt.NoPen)
            painter.setBrush(highlight_color)
            painter.drawPath(highlight)
            
        # Draw label if present
        if self._label:
            label_font = QFont("Courier New", 10)
            label_font.setBold(True)
            painter.setFont(label_font)
            
            # Draw digital noise scan line behind text if active
            if self._state and self._pulse:
                scan_text_y = label_rect.top() + (self._scan_offset * label_rect.height()) / 100
                
                scan_text_color = QColor(indicator_color)
                scan_text_color.setAlphaF(0.2)
                
                painter.setPen(Qt.NoPen)
                painter.setBrush(scan_text_color)
                painter.drawRect(QRectF(
                    label_rect.left(),
                    scan_text_y - 1,
                    label_rect.width(),
                    2
                ))
            
            # Draw label text with shadow for Matrix effect
            shadow_color = QColor(0, 0, 0, 160)
            painter.setPen(shadow_color)
            painter.drawText(label_rect.adjusted(2, 2, 2, 2), Qt.AlignLeft | Qt.AlignVCenter, self._label)
            
            # Draw actual text
            painter.setPen(indicator_color)
            painter.drawText(label_rect, Qt.AlignLeft | Qt.AlignVCenter, self._label)
        
        painter.end()


if __name__ == "__main__":
    # Simple test for the status indicators
    import sys
    from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, QWidget
    
    app = QApplication(sys.argv)
    
    window = QMainWindow()
    window.setWindowTitle("Status Indicators Test")
    window.setGeometry(100, 100, 800, 600)
    window.setStyleSheet("background-color: #000000;")
    
    central_widget = QWidget()
    window.setCentralWidget(central_widget)
    
    layout = QVBoxLayout(central_widget)
    
    # Add status indicators in a row
    status_row = QHBoxLayout()
    
    # Regular indicator
    indicator1 = StatusIndicator(color="#00ff00", label="SYSTEM ACTIVE")
    status_row.addWidget(indicator1)
    
    # Pulsing indicator
    indicator2 = StatusIndicator(color="#ffaa00", pulse=True, label="WARNING")
    status_row.addWidget(indicator2)
    
    # Off indicator
    indicator3 = StatusIndicator(color="#ff0000", label="OFFLINE")
    indicator3.state = False
    status_row.addWidget(indicator3)
    
    layout.addLayout(status_row)
    
    # Add another row of different indicators
    status_row2 = QHBoxLayout()
    
    # Large indicator
    indicator4 = StatusIndicator(color="#00aaff", size=20, label="NETWORK")
    status_row2.addWidget(indicator4)
    
    # Critical indicator
    indicator5 = StatusIndicator(color="#ff0000", pulse=True, label="CRITICAL ALERT")
    status_row2.addWidget(indicator5)
    
    layout.addLayout(status_row2)
    
    window.show()
    
    sys.exit(app.exec_())