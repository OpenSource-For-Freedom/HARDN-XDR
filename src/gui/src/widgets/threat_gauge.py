#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Threat gauge widget for HARDN Security Interface
"""

import math
from PyQt5.QtCore import Qt, QTimer, QRectF, pyqtProperty, pyqtSlot
from PyQt5.QtGui import QPainter, QColor, QPen, QFont, QBrush, QRadialGradient
from PyQt5.QtWidgets import QWidget


class ThreatGauge(QWidget):
    """Threat level gauge widget with Matrix-inspired visuals"""
    
    def __init__(self, parent=None):
        """Initialize the threat gauge widget
        
        Args:
            parent: Parent widget
        """
        super().__init__(parent)
        
        # Properties
        self._threat_level = 0  # 0-100
        self._warning_level = 70
        self._critical_level = 90
        self._label = "THREAT LEVEL"
        
        # Animation
        self._animated = False
        self._animation_value = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update_animation)
        
        # Glow effect
        self._glow_intensity = 0.0
        self._glow_increasing = True
        self._glow_timer = QTimer(self)
        self._glow_timer.timeout.connect(self._update_glow)
        self._glow_timer.start(50)
        
        # Set minimum size
        self.setMinimumSize(200, 200)
        
    @pyqtProperty(int)
    def threat_level(self):
        """Get current threat level (0-100)"""
        return self._threat_level
        
    @threat_level.setter
    def threat_level(self, level):
        """Set current threat level (0-100)"""
        old_level = self._threat_level
        self._threat_level = max(0, min(100, level))
        
        # Start animation if value changed significantly
        if abs(old_level - self._threat_level) > 5:
            self._animated = True
            self._animation_value = old_level
            if not self._timer.isActive():
                self._timer.start(16)  # ~60 FPS
        
        self.update()
        
    @pyqtProperty(int)
    def warning_level(self):
        """Get warning threshold level"""
        return self._warning_level
        
    @warning_level.setter
    def warning_level(self, level):
        """Set warning threshold level"""
        self._warning_level = max(0, min(100, level))
        self.update()
        
    @pyqtProperty(int)
    def critical_level(self):
        """Get critical threshold level"""
        return self._critical_level
        
    @critical_level.setter
    def critical_level(self, level):
        """Set critical threshold level"""
        self._critical_level = max(0, min(100, level))
        self.update()
        
    @pyqtProperty(str)
    def label(self):
        """Get gauge label"""
        return self._label
        
    @label.setter
    def label(self, label):
        """Set gauge label"""
        self._label = label
        self.update()
    
    @pyqtSlot()
    def _update_animation(self):
        """Update animation state"""
        if not self._animated:
            self._timer.stop()
            return
            
        # Calculate animation step
        step = (self._threat_level - self._animation_value) / 10.0
        
        # Use small constant step for slow changes
        if abs(step) < 0.5:
            step = 0.5 if step > 0 else -0.5
            
        self._animation_value += step
        
        # Check if animation is complete
        if abs(self._animation_value - self._threat_level) < 0.5:
            self._animation_value = self._threat_level
            self._animated = False
            self._timer.stop()
            
        self.update()
    
    @pyqtSlot()
    def _update_glow(self):
        """Update glow animation"""
        step = 0.05
        
        if self._glow_increasing:
            self._glow_intensity += step
            if self._glow_intensity >= 1.0:
                self._glow_intensity = 1.0
                self._glow_increasing = False
        else:
            self._glow_intensity -= step
            if self._glow_intensity <= 0.2:
                self._glow_intensity = 0.2
                self._glow_increasing = True
                
        # Update more frequently when threat level is high
        if self._threat_level >= self._warning_level:
            self.update()
                
    def paintEvent(self, event):
        """Paint the threat gauge"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Get drawing area
        rect = self.rect()
        
        # Calculate gauge metrics
        center_x = rect.width() / 2
        center_y = rect.height() / 2
        
        # Use 80% of the minimum dimension for radius
        radius = min(center_x, center_y) * 0.8
        
        # Calculate start and sweep angles
        start_angle = 135  # Degrees
        sweep_angle = 270  # Degrees

        # Calculate inner radius for gradient
        inner_radius = radius * 0.7
        
        # Calculate display value (using animation value if active)
        display_value = self._animation_value if self._animated else self._threat_level
        display_angle = start_angle + (sweep_angle * display_value / 100.0)
        
        # Draw background arc
        painter.setPen(QPen(QColor("#111111"), 10, Qt.SolidLine, Qt.RoundCap))
        painter.drawArc(QRectF(center_x - radius, center_y - radius, radius * 2, radius * 2),
                        int(start_angle * 16), 
                        int(sweep_angle * 16))
        
        # Determine color based on threat level
        if display_value >= self._critical_level:
            base_color = QColor("#ff0000")  # Red for critical
        elif display_value >= self._warning_level:
            base_color = QColor("#ffaa00")  # Orange for warning
        else:
            base_color = QColor("#00ff00")  # Green for normal
        
        # Add glow effect for warning/critical levels
        if display_value >= self._warning_level:
            # Create glow pen with variable intensity
            glow_pen = QPen(base_color, 10, Qt.SolidLine, Qt.RoundCap)
            
            # Draw glowing background with digital noise effect
            for i in range(3):
                glow_color = QColor(base_color)
                alpha = int(80 * self._glow_intensity) - (i * 20)
                if alpha > 0:
                    glow_color.setAlpha(alpha)
                    glow_pen.setColor(glow_color)
                    glow_pen.setWidth(14 + i*2)
                    painter.setPen(glow_pen)
                    painter.drawArc(QRectF(center_x - radius, center_y - radius, radius * 2, radius * 2),
                                   int(start_angle * 16), 
                                   int((display_angle - start_angle) * 16))
                
                # Add digital noise elements
                if display_value >= self._critical_level and i == 0:
                    noise_pen = QPen(base_color, 2)
                    painter.setPen(noise_pen)
                    
                    # Draw digital noise around the arc
                    num_noise = int(display_value / 10)
                    for j in range(num_noise):
                        noise_angle = start_angle + (sweep_angle * j / num_noise)
                        noise_x = center_x + radius * math.cos(math.radians(noise_angle - 90))
                        noise_y = center_y + radius * math.sin(math.radians(noise_angle - 90))
                        
                        # Draw random digital elements
                        if j % 3 == 0:
                            painter.drawLine(int(noise_x - 5), int(noise_y), int(noise_x + 5), int(noise_y))
                        elif j % 3 == 1:
                            painter.drawRect(int(noise_x - 3), int(noise_y - 3), 6, 6)
                        else:
                            painter.drawEllipse(int(noise_x - 2), int(noise_y - 2), 4, 4)
            
        # Draw threat level arc
        painter.setPen(QPen(base_color, 10, Qt.SolidLine, Qt.RoundCap))
        painter.drawArc(QRectF(center_x - radius, center_y - radius, radius * 2, radius * 2),
                        int(start_angle * 16), 
                        int((display_angle - start_angle) * 16))
        
        # Draw warning/critical threshold markers
        marker_pen = QPen(QColor("#ffaa00"), 2, Qt.SolidLine)
        painter.setPen(marker_pen)
        warning_angle = start_angle + (sweep_angle * self._warning_level / 100.0)
        x1 = center_x + (radius - 10) * math.cos(math.radians(warning_angle - 90))
        y1 = center_y + (radius - 10) * math.sin(math.radians(warning_angle - 90))
        x2 = center_x + (radius + 10) * math.cos(math.radians(warning_angle - 90))
        y2 = center_y + (radius + 10) * math.sin(math.radians(warning_angle - 90))
        painter.drawLine(int(x1), int(y1), int(x2), int(y2))
        
        marker_pen.setColor(QColor("#ff0000"))
        painter.setPen(marker_pen)
        critical_angle = start_angle + (sweep_angle * self._critical_level / 100.0)
        x1 = center_x + (radius - 10) * math.cos(math.radians(critical_angle - 90))
        y1 = center_y + (radius - 10) * math.sin(math.radians(critical_angle - 90))
        x2 = center_x + (radius + 10) * math.cos(math.radians(critical_angle - 90))
        y2 = center_y + (radius + 10) * math.sin(math.radians(critical_angle - 90))
        painter.drawLine(int(x1), int(y1), int(x2), int(y2))
        
        # Draw digital scale
        scale_pen = QPen(QColor("#333333"), 1, Qt.SolidLine)
        painter.setPen(scale_pen)
        
        for i in range(0, 101, 10):
            scale_angle = start_angle + (sweep_angle * i / 100.0)
            # Length of scale marker
            scale_length = 5 if i % 20 == 0 else 3
            
            x1 = center_x + (radius - scale_length) * math.cos(math.radians(scale_angle - 90))
            y1 = center_y + (radius - scale_length) * math.sin(math.radians(scale_angle - 90))
            x2 = center_x + radius * math.cos(math.radians(scale_angle - 90))
            y2 = center_y + radius * math.sin(math.radians(scale_angle - 90))
            
            painter.drawLine(int(x1), int(y1), int(x2), int(y2))
            
            # Draw scale numbers for major ticks
            if i % 20 == 0:
                text_radius = radius - 20
                text_x = center_x + text_radius * math.cos(math.radians(scale_angle - 90))
                text_y = center_y + text_radius * math.sin(math.radians(scale_angle - 90))
                
                text_rect = QRectF(text_x - 15, text_y - 10, 30, 20)
                painter.setPen(QColor("#00ff00"))
                painter.drawText(text_rect, Qt.AlignCenter, str(i))
                painter.setPen(scale_pen)
        
        # Draw background for central text display
        center_radius = radius * 0.5
        painter.setPen(Qt.NoPen)
        center_bg = QRadialGradient(center_x, center_y, center_radius)
        center_bg.setColorAt(0, QColor(0, 0, 0, 200))
        center_bg.setColorAt(0.8, QColor(0, 0, 0, 150))
        center_bg.setColorAt(1, QColor(0, 0, 0, 0))
        painter.setBrush(QBrush(center_bg))
        painter.drawEllipse(QRectF(center_x - center_radius, center_y - center_radius, 
                                 center_radius * 2, center_radius * 2))
        
        # Draw label
        painter.setPen(QColor("#00ff00"))
        font = QFont("Courier New", 10)
        font.setBold(True)
        painter.setFont(font)
        label_rect = QRectF(center_x - center_radius, center_y - center_radius, 
                          center_radius * 2, center_radius * 0.7)
        painter.drawText(label_rect, Qt.AlignCenter, self._label)
            
        # Draw value text
        painter.setPen(base_color)
        font = QFont("Courier New", 16)
        font.setBold(True)
        painter.setFont(font)
        
        # Convert value to text with appropriate label
        if display_value >= self._critical_level:
            value_text = "CRITICAL"
        elif display_value >= self._warning_level:
            value_text = "WARNING"
        else:
            value_text = "NORMAL"
            
        # Also show numeric value
        value_text += f"\n{int(display_value)}%"
        
        value_rect = QRectF(center_x - center_radius, center_y - center_radius / 4, 
                           center_radius * 2, center_radius * 1.5)
        painter.drawText(value_rect, Qt.AlignCenter, value_text)
        
        painter.end()

    def set_threat_level(self, level):
        """Set current threat level (0-100)"""
        self.threat_level = level  # Use property setter


if __name__ == "__main__":
    # Simple test for the threat gauge
    import sys
    from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QSlider
    
    app = QApplication(sys.argv)
    
    window = QMainWindow()
    window.setWindowTitle("Threat Gauge Test")
    window.setGeometry(100, 100, 600, 400)
    window.setStyleSheet("background-color: #000000;")
    
    central_widget = QWidget()
    window.setCentralWidget(central_widget)
    
    layout = QVBoxLayout(central_widget)
    
    # Add threat gauge
    threat_gauge = ThreatGauge()
    threat_gauge.threat_level = 75
    layout.addWidget(threat_gauge)
    
    # Add slider to control threat level
    slider = QSlider(Qt.Horizontal)
    slider.setMinimum(0)
    slider.setMaximum(100)
    slider.setValue(75)
    slider.setStyleSheet("QSlider::groove:horizontal { background: #333333; height: 10px; }"
                         "QSlider::handle:horizontal { background: #00ff00; width: 18px; }")
    slider.valueChanged.connect(lambda value: threat_gauge.set_threat_level(value))
    layout.addWidget(slider)
    
    window.show()
    
    sys.exit(app.exec_())
