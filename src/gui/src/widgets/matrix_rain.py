#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Matrix-style digital rain animation widget for HARDN Security Interface
"""

import random
from PyQt5.QtCore import Qt, QTimer, QRect
from PyQt5.QtGui import QPainter, QColor, QFont, QPen, QFontMetrics
from PyQt5.QtWidgets import QWidget


class MatrixRain(QWidget):
    """Widget implementing the iconic Matrix digital rain effect"""
    
    def __init__(self, parent=None, density=5, speed=80, color="#00ff00"):
        """Initialize the Matrix rain widget
        
        Args:
            parent: Parent widget
            density: Character density (higher = more characters)
            speed: Animation speed (lower = faster)
            color: Rain color as hex string
        """
        super().__init__(parent)
        
        # Properties
        self._color = QColor(color)
        self._density = density
        self._speed = speed
        self._columns = []
        self._chars = []
        self._active = True
        
        # Load Matrix-like characters (mix of Latin, Japanese katakana, and symbols)
        self._matrix_chars = [chr(i) for i in range(33, 127)]  # ASCII chars
        self._matrix_chars += [chr(i) for i in range(0xFF66, 0xFF9F)]  # Katakana
        self._matrix_chars += [chr(i) for i in range(12448, 12543)]  # More Japanese

        # Animation timer
        self._timer = QTimer(self)
        self._timer.timeout.connect(self.update_matrix)
        self._timer.start(speed)
        
        # Set minimum size
        self.setMinimumSize(100, 100)
        
    def paintEvent(self, event):
        """Paint the Matrix rain effect"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Set background to black
        painter.fillRect(self.rect(), QColor(0, 0, 0))
        
        # Configure font
        font = QFont("Courier New", 14)
        painter.setFont(font)
        fm = QFontMetrics(font)
        
        # Character dimensions
        char_width = fm.averageCharWidth()
        char_height = fm.height()
        
        # Calculate number of columns based on widget width
        num_cols = self.width() // char_width
        
        # Initialize columns if not done yet or if size changed
        if len(self._columns) != num_cols:
            self._columns = [{'pos': random.randint(-100, 0), 
                            'speed': random.randint(1, 5), 
                            'length': random.randint(5, 30)} 
                            for _ in range(num_cols)]
            
        # Draw each column
        for i, col in enumerate(self._columns):
            x = i * char_width
            
            # Draw each character in the column with varying opacity
            for j in range(col['length']):
                y_pos = (col['pos'] - j * char_height) % (self.height() + 100) - 50
                
                # Skip if outside visible area
                if y_pos < -50 or y_pos > self.height():
                    continue
                
                # Calculate opacity - first character is brightest
                opacity = 255 if j == 0 else max(30, 255 - (j * 255 // col['length']))
                
                # Get random char or generate new one
                char_idx = i * 100 + j
                if char_idx >= len(self._chars):
                    self._chars.append(random.choice(self._matrix_chars))
                # Occasionally change characters in the stream
                elif random.random() < 0.02:
                    self._chars[char_idx] = random.choice(self._matrix_chars)
                    
                # Set color with varying opacity
                color = QColor(self._color)
                color.setAlpha(opacity)
                painter.setPen(color)
                
                # Draw the character
                if char_idx < len(self._chars):
                    painter.drawText(QRect(x, int(y_pos), char_width, char_height), 
                                    Qt.AlignCenter, self._chars[char_idx])
                else:
                        # If index is out of range, add a new character and ensure char_idx is valid
                    while char_idx >= len(self._chars):
                        self._chars.append(random.choice(self._matrix_chars))
                    painter.drawText(QRect(x, int(y_pos), char_width, char_height),
                                    Qt.AlignCenter, self._chars[char_idx])

        painter.end()
        
    def update_matrix(self):
        """Update the matrix animation state"""
        if not self._active:
            return
            
        # Update each column position
        for col in self._columns:
            col['pos'] += col['speed']
            
            # Randomize speed occasionally
            if random.random() < 0.01:
                col['speed'] = random.randint(1, 5)
                
        self.update()
        
    def set_active(self, active):
        """Enable or disable the animation"""
        self._active = active
        if active and not self._timer.isActive():
            self._timer.start(self._speed)
        elif not active and self._timer.isActive():
            self._timer.stop()
            
    def set_color(self, color):
        """Set the rain color"""
        if isinstance(color, str):
            self._color = QColor(color)
        else:
            self._color = color
        self.update()
        
    def set_density(self, density):
        """Set the character density"""
        self._density = max(1, density)
        self.update()
        
    def set_speed(self, speed):
        """Set the animation speed"""
        self._speed = max(50, speed)
        if self._timer.isActive():
            self._timer.setInterval(self._speed)


if __name__ == "__main__":
    # Simple test for the Matrix rain effect
    import sys
    from PyQt5.QtWidgets import QApplication, QMainWindow
    
    app = QApplication(sys.argv)
    
    window = QMainWindow()
    window.setWindowTitle("Matrix Rain Test")
    window.setGeometry(100, 100, 800, 600)
    
    rain = MatrixRain()
    window.setCentralWidget(rain)
    
    window.show()
    
    sys.exit(app.exec_())