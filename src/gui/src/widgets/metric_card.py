#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Matrix-styled metric card widget for HARDN Security Interface
"""

from PyQt5.QtCore import Qt, QTimer, QRectF, pyqtSlot
from PyQt5.QtGui import QPainter, QColor, QPen, QFont, QBrush, QLinearGradient
from PyQt5.QtWidgets import QWidget


class MetricCard(QWidget):
    """A card widget displaying a metric with label and value, Matrix-styled"""
    
    def __init__(self, parent=None, title="", value="", icon="", color="#00ff00"):
        """Initialize the metric card widget
        
        Args:
            parent: Parent widget
            title: Card title
            value: Value to display
            icon: Icon character (unicode)
            color: Card color
        """
        super().__init__(parent)
        
        # Properties
        self._title = title
        self._value = value
        self._icon = icon
        self._color = QColor(color)
        self._subtitle = ""
        
        # Animation properties
        self._pulse = False
        self._pulse_opacity = 1.0
        self._pulse_growing = False
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update_pulse)
        
        # Border animation properties
        self._border_animation = 0
        self._border_timer = QTimer(self)
        self._border_timer.timeout.connect(self._update_border)
        self._border_timer.start(30)  # 30ms for smooth animation
        
        # Set minimum size
        self.setMinimumSize(150, 80)
        
    def _update_border(self):
        """Update border animation"""
        self._border_animation = (self._border_animation + 1) % 100
        
        # Only update widget if value is changing or if critical/warning
        if self._pulse or self._is_critical_value():
            self.update()
    
    def _is_critical_value(self):
        """Check if the current value indicates a critical state"""
        # Simple heuristic: if the value contains any warning keywords
        warning_keywords = ["critical", "alert", "warning", "high", "error"]
        value_lower = self._value.lower()
        
        for keyword in warning_keywords:
            if keyword in value_lower:
                return True
                
        # Check for high percentage values (>80%)
        if "%" in value_lower:
            try:
                percent_value = int(value_lower.split("%")[0])
                if percent_value > 80:
                    return True
            except ValueError:
                pass
                
        return False
        
    @property
    def title(self):
        """Get card title"""
        return self._title
        
    @title.setter
    def title(self, title):
        """Set card title"""
        self._title = title
        self.update()
        
    @property
    def value(self):
        """Get displayed value"""
        return self._value
        
    @value.setter
    def value(self, value):
        """Set displayed value"""
        old_value = self._value
        self._value = value
        
        # Start pulsing if value changed
        if old_value != value:
            self._start_pulse()
            
        self.update()
    
    @property
    def subtitle(self):
        """Get card subtitle"""
        return self._subtitle
        
    @subtitle.setter
    def subtitle(self, subtitle):
        """Set card subtitle"""
        self._subtitle = subtitle
        self.update()
        
    @property
    def icon(self):
        """Get displayed icon"""
        return self._icon
        
    @icon.setter
    def icon(self, icon):
        """Set displayed icon"""
        self._icon = icon
        self.update()
        
    @property
    def color(self):
        """Get card color"""
        return self._color
        
    @color.setter
    def color(self, color):
        """Set card color"""
        if isinstance(color, str):
            self._color = QColor(color)
        else:
            self._color = color
        self.update()
        
    def _start_pulse(self):
        """Start pulse animation"""
        self._pulse = True
        self._pulse_opacity = 0.3
        self._pulse_growing = True
        
        if not self._timer.isActive():
            self._timer.start(30)
            
    @pyqtSlot()
    def _update_pulse(self):
        """Update pulse animation state"""
        if not self._pulse:
            return
            
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
                # Stop pulsing after one cycle
                self._pulse = False
                self._timer.stop()
                
        self.update()
        
    def paintEvent(self, event):
        """Paint the metric card with Matrix style"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Get drawing area
        rect = self.rect()
        
        # Draw card background with digital gradient
        painter.setPen(Qt.NoPen)
        
        # Use pulse opacity for background if pulsing
        if self._pulse or self._is_critical_value():
            # Create pulsing gradient for warning states
            gradient = QLinearGradient(rect.topLeft(), rect.bottomRight())
            
            # Get intensity based on pulse or animation for critical values
            intensity = self._pulse_opacity
            if self._is_critical_value() and not self._pulse:
                # Use border animation for continuous pulsing
                intensity = 0.3 + (self._border_animation / 100) * 0.5
            
            base_color = QColor(self._color)
            dark_color = QColor(0, 0, 0)
            
            gradient.setColorAt(0, dark_color)
            gradient.setColorAt(0.4, QColor(
                int(base_color.red() * 0.1),
                int(base_color.green() * 0.1),
                int(base_color.blue() * 0.1)
            ))
            gradient.setColorAt(0.6, QColor(
                int(base_color.red() * intensity * 0.3),
                int(base_color.green() * intensity * 0.3),
                int(base_color.blue() * intensity * 0.3)
            ))
            gradient.setColorAt(1, dark_color)
            
            painter.setBrush(gradient)
        else:
            # Normal state - subtle gradient
            gradient = QLinearGradient(rect.topLeft(), rect.bottomRight())
            gradient.setColorAt(0, QColor(0, 0, 0))
            gradient.setColorAt(0.5, QColor(10, 10, 10))
            gradient.setColorAt(1, QColor(0, 0, 0))
            painter.setBrush(gradient)
            
        painter.drawRect(rect)
        
        # Draw digital scanline effect
        scan_position = (self._border_animation * rect.height()) / 100
        scan_height = 5
        scan_rect = QRectF(rect.left(), scan_position, rect.width(), scan_height)
        
        scan_color = QColor(self._color)
        scan_color.setAlpha(40)  # Semi-transparent
        painter.setBrush(scan_color)
        painter.drawRect(scan_rect)
        
        # Draw card border with glow for critical values
        if self._is_critical_value():
            # Animated pulsing glow for critical values
            glow_intensity = 0.5 + (self._border_animation / 100) * 0.5
            
            # Draw multiple borders with decreasing opacity for glow effect
            for i in range(3):
                border_width = 3 - i
                border_color = QColor(self._color)
                border_color.setAlphaF(glow_intensity * (1.0 - i * 0.2))
                
                pen = QPen(border_color, border_width)
                painter.setPen(pen)
                painter.drawRect(rect.adjusted(i, i, -i, -i))
        else:
            # Regular border with top glow
            pen = QPen(self._color, 1)
            painter.setPen(pen)
            painter.drawRect(rect)
            
            # Highlight top border (Matrix style)
            pen.setWidth(2)
            painter.setPen(pen)
            painter.drawLine(rect.left() + 1, rect.top(), rect.right() - 1, rect.top())
        
        # Digital circuit pattern along top border
        if not self._is_critical_value():
            circuit_pen = QPen(self._color, 1)
            painter.setPen(circuit_pen)
            
            circuit_y = rect.top() + 2
            section_width = rect.width() / 8
            
            # Draw a circuit-like pattern
            for i in range(8):
                x1 = rect.left() + i * section_width
                x2 = x1 + section_width
                
                if i % 2 == 0:
                    # Horizontal line
                    painter.drawLine(int(x1), circuit_y, int(x2), circuit_y)
                else:
                    # Circuit pattern
                    mid_x = (x1 + x2) / 2
                    painter.drawLine(int(x1), circuit_y, int(mid_x - 5), circuit_y)
                    painter.drawLine(int(mid_x + 5), circuit_y, int(x2), circuit_y)
                    painter.drawLine(int(mid_x - 5), circuit_y, int(mid_x - 5), circuit_y + 4)
                    painter.drawLine(int(mid_x + 5), circuit_y, int(mid_x + 5), circuit_y + 4)
                    painter.drawLine(int(mid_x - 5), circuit_y + 4, int(mid_x + 5), circuit_y + 4)
        
        # Draw title
        painter.setPen(self._color)
        font = QFont("Courier New", 10)
        font.setBold(True)
        painter.setFont(font)
        
        title_rect = QRectF(rect.left() + 10, rect.top() + 8, rect.width() - 20, 20)
        painter.drawText(title_rect, Qt.AlignLeft | Qt.AlignVCenter, self._title)
        
        # Determine content layout based on whether we have icon and subtitle
        if self._icon:
            # With icon - divide space
            value_rect = QRectF(rect.left() + 10, rect.top() + 30, 
                              rect.width() - rect.width() / 3 - 10, rect.height() - 40)
            
            # Draw icon with glow effect for critical values
            icon_rect = QRectF(rect.right() - rect.width() / 3, rect.top() + 30,
                             rect.width() / 3 - 10, rect.height() - 40)
            
            if self._is_critical_value():
                # Draw glow behind icon
                glow_color = QColor(self._color)
                glow_color.setAlphaF(0.2)
                painter.setPen(Qt.NoPen)
                painter.setBrush(glow_color)
                painter.drawEllipse(icon_rect.adjusted(5, 5, -5, -5))
            
            font = QFont("Courier New", 24)
            painter.setFont(font)
            painter.setPen(self._color)
            painter.drawText(icon_rect, Qt.AlignCenter, self._icon)
            
        else:
            # No icon - use full width
            value_rect = QRectF(rect.left() + 10, rect.top() + 30, 
                              rect.width() - 20, rect.height() - 40)
        
        # Draw value with pulsed color
        if self._pulse:
            value_color = QColor(self._color)
            value_color.setAlphaF(self._pulse_opacity)
        else:
            value_color = self._color
            
        painter.setPen(value_color)
        font = QFont("Courier New", 18)
        font.setBold(True)
        painter.setFont(font)
                               
        # Adjust value rect if we have a subtitle
        if self._subtitle:
            painter.drawText(value_rect.adjusted(0, 0, 0, -15), 
                           Qt.AlignLeft | Qt.AlignVCenter, self._value)
            
            # Draw subtitle
            subtitle_rect = QRectF(value_rect.left(), value_rect.bottom() - 18,
                                 value_rect.width(), 18)
            
            font = QFont("Courier New", 9)
            painter.setFont(font)
            painter.setPen(QColor(self._color).darker(130))
            painter.drawText(subtitle_rect, Qt.AlignLeft | Qt.AlignVCenter, self._subtitle)
        else:
            painter.drawText(value_rect, Qt.AlignLeft | Qt.AlignVCenter, self._value)
        
        painter.end()


if __name__ == "__main__":
    # Simple test for the metric cards
    import sys
    from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QHBoxLayout
    
    app = QApplication(sys.argv)
    
    window = QMainWindow()
    window.setWindowTitle("Matrix Metric Cards Test")
    window.setGeometry(100, 100, 800, 600)
    window.setStyleSheet("background-color: #000000;")
    
    central_widget = QWidget()
    window.setCentralWidget(central_widget)
    
    layout = QVBoxLayout(central_widget)
    
    # Add metric cards in a row
    cards_row1 = QHBoxLayout()
    
    # CPU card
    cpu_card = MetricCard(title="CPU USAGE", value="32%", icon="📈", color="#00ff00")
    cpu_card.subtitle = "8 cores @ 3.5 GHz"
    cards_row1.addWidget(cpu_card)
    
    # Memory card
    memory_card = MetricCard(title="MEMORY", value="1.2 GB", icon="🧠", color="#00aaff")
    memory_card.subtitle = "8.0 GB total"
    cards_row1.addWidget(memory_card)
    
    layout.addLayout(cards_row1)
    
    # Add more cards in another row
    cards_row2 = QHBoxLayout()
    
    # Network card
    network_card = MetricCard(title="NETWORK", value="2.3 MB/s", icon="📡", color="#ffaa00")
    network_card.subtitle = "192.168.1.105"
    cards_row2.addWidget(network_card)
    
    # Threats card
    threats_card = MetricCard(title="THREATS", value="CRITICAL", icon="⚠️", color="#ff0000")
    threats_card.subtitle = "7 incidents detected"
    cards_row2.addWidget(threats_card)
    
    layout.addLayout(cards_row2)
    
    window.show()
    
    sys.exit(app.exec_())
