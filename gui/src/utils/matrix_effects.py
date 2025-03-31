#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Matrix digital rain effects for HARDN Security Interface
"""

import random
import sys
from PyQt5.QtCore import Qt, QTimer, QRect, pyqtSlot, QEvent
from PyQt5.QtGui import QPainter, QColor, QFont, QPixmap
from PyQt5.QtWidgets import QWidget


class MatrixRain(QWidget):
    """Matrix digital rain effect widget"""
    
    def __init__(self, parent=None, density=10, speed=80, char_size=14):
        """Initialize the Matrix rain effect
        
        Args:
            parent: Parent widget
            density: Character density (1-100)
            speed: Animation speed (ms)
            char_size: Character size in pixels
        """
        super().__init__(parent)
        
        # Matrix rain settings
        self.density = min(max(density, 1), 100)  # Clamped between 1-100
        self.speed = speed  # milliseconds
        self.char_size = char_size
        
        # Matrix style
        self.text_color = QColor("#00ff00")  # Matrix green
        self.highlight_color = QColor("#ffffff")  # Bright white for heads
        self.fade_colors = [
            QColor(0, 255, 0, 255),  # Full opacity
            QColor(0, 240, 0, 230),
            QColor(0, 225, 0, 210),
            QColor(0, 210, 0, 190),
            QColor(0, 195, 0, 170),
            QColor(0, 180, 0, 150),
            QColor(0, 165, 0, 130),
            QColor(0, 150, 0, 110),
            QColor(0, 135, 0, 90),
            QColor(0, 120, 0, 70),
            QColor(0, 105, 0, 50),
            QColor(0, 90, 0, 30),
            QColor(0, 75, 0, 10),
        ]
        
        # Matrix characters (combination of Latin, Katakana, and symbols)
        self.matrix_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        self.matrix_chars += "!@#$%^&*()_+-=[]{}|;':,.<>?/~`"
        self.matrix_chars += "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ"
        
        # Data structures for rain drops
        self.columns = []  # List of column data
        self.drops = []    # List of active drop positions
        
        # Initialize timer for animation
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_matrix)
        
        # Set widget properties
        self.setMinimumSize(100, 100)
        self.setFocusPolicy(Qt.NoFocus)
        
        # Initialize matrix data
        self.reset_matrix()

    def reset_matrix(self):
        """Reset and initialize the matrix data"""
        # Calculate columns based on widget width
        num_columns = max(1, self.width() // self.char_size)
        
        # Reset data structures
        self.columns = [{"position": 0, "speed": 0, "active": False} for _ in range(num_columns)]
        self.drops = []
        
        # Activate random columns based on density
        active_columns = int((num_columns * self.density) / 100)
        for i in random.sample(range(num_columns), active_columns):
            self.columns[i]["active"] = True
            self.columns[i]["position"] = random.randint(-20, -1)  # Start above screen
            self.columns[i]["speed"] = random.randint(1, 3)        # Random drop speed
        
        # Start timer
        self.timer.start(self.speed)

    def resizeEvent(self, event):
        """Handle resize event to adjust matrix dimensions"""
        super().resizeEvent(event)
        self.reset_matrix()

    @pyqtSlot()
    def update_matrix(self):
        """Update matrix animation state"""
        # Move drops down
        for i, col in enumerate(self.columns):
            if col["active"]:
                col["position"] += col["speed"]
                
                # Check if dropped off screen
                if col["position"] > (self.height() // self.char_size) + 20:
                    col["active"] = False
        
        # Create new drops if needed
        active_count = sum(1 for col in self.columns if col["active"])
        target_active = int((len(self.columns) * self.density) / 100)
        
        if active_count < target_active:
            inactive_indices = [i for i, col in enumerate(self.columns) if not col["active"]]
            if inactive_indices:
                # Activate a random column
                new_col_idx = random.choice(inactive_indices)
                self.columns[new_col_idx]["active"] = True
                self.columns[new_col_idx]["position"] = random.randint(-20, -1)
                self.columns[new_col_idx]["speed"] = random.randint(1, 3)
        
        # Request repaint
        self.update()

    def paintEvent(self, event):
        """Paint the Matrix rain effect"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Set font
        font = QFont("Courier New", self.char_size)
        font.setBold(False)
        painter.setFont(font)
        
        # Clear background
        painter.fillRect(self.rect(), Qt.black)
        
        # Draw the matrix rain
        for i, col in enumerate(self.columns):
            if not col["active"]:
                continue
                
            # Calculate x position
            x = i * self.char_size
            
            # Draw the trail
            trail_length = random.randint(5, 15)  # Random trail length
            
            for j in range(trail_length):
                y_pos = col["position"] - j
                y = y_pos * self.char_size
                
                # Skip if off screen
                if y < -self.char_size or y > self.height():
                    continue
                
                # Choose a character
                char = random.choice(self.matrix_chars)
                
                # Set color based on position in trail
                if j == 0:
                    # Head of the trail is white/bright
                    painter.setPen(self.highlight_color)
                else:
                    # Get fade color based on position
                    fade_idx = min(j, len(self.fade_colors) - 1)
                    painter.setPen(self.fade_colors[fade_idx])
                
                # Draw the character
                painter.drawText(QRect(x, y, self.char_size, self.char_size), 
                                 Qt.AlignCenter, char)
                
                # Sometimes randomly change characters (subtle glitching effect)
                if random.random() < 0.02:
                    char = random.choice(self.matrix_chars)
        
        painter.end()

    def set_density(self, density):
        """Set the density of matrix rain (1-100)"""
        self.density = min(max(density, 1), 100)
        self.reset_matrix()
        
    def set_speed(self, speed):
        """Set animation speed in milliseconds"""
        self.speed = speed
        if self.timer.isActive():
            self.timer.stop()
            self.timer.start(self.speed)
            
    def set_char_size(self, size):
        """Set character size in pixels"""
        self.char_size = size
        self.reset_matrix()
    
    def stop(self):
        """Stop the animation"""
        if self.timer.isActive():
            self.timer.stop()
    
    def start(self):
        """Start the animation"""
        if not self.timer.isActive():
            self.timer.start(self.speed)


class TerminalConsole(QWidget):
    """Matrix-style terminal console widget"""
    
    def __init__(self, parent=None):
        """Initialize the terminal console widget"""
        super().__init__(parent)
        
        # Console settings
        self.cursor_blink = True
        self.blink_timer = QTimer(self)
        self.blink_timer.timeout.connect(self.toggle_cursor)
        self.blink_timer.start(500)  # Blink every 500ms
        
        # Console content
        self.lines = []
        self.current_line = ""
        self.cursor_pos = 0
        self.max_lines = 100  # Maximum number of lines to store
        
        # Typing animation
        self.typing_queue = []
        self.typing_timer = QTimer(self)
        self.typing_timer.timeout.connect(self.type_character)
        self.typing_speed = 30  # ms per character
        
        # Set widget properties
        self.setMinimumSize(100, 100)
        self.setFocusPolicy(Qt.StrongFocus)

    def toggle_cursor(self):
        """Toggle cursor visibility for blinking effect"""
        self.cursor_blink = not self.cursor_blink
        self.update()

    def add_text(self, text, animate=False):
        """Add text to the console
        
        Args:
            text: Text to add
            animate: Whether to animate typing
        """
        if animate:
            # Queue text for animated typing
            self.typing_queue.append(text)
            if not self.typing_timer.isActive():
                self.typing_timer.start(self.typing_speed)
        else:
            # Add text immediately
            lines = text.split('\n')
            self.current_line += lines[0]
            self.cursor_pos = len(self.current_line)
            
            # Handle multiple lines
            if len(lines) > 1:
                self.lines.append(self.current_line)
                for i in range(1, len(lines) - 1):
                    self.lines.append(lines[i])
                self.current_line = lines[-1]
                self.cursor_pos = len(self.current_line)
            
            # Limit number of lines
            if len(self.lines) > self.max_lines:
                self.lines = self.lines[-self.max_lines:]
            
            self.update()

    def type_character(self):
        """Type a single character for animation"""
        if not self.typing_queue:
            self.typing_timer.stop()
            return
            
        # Get current text being animated
        text = self.typing_queue[0]
        
        if not text:
            # Move to next text in queue
            self.typing_queue.pop(0)
            if self.typing_queue:
                self.typing_timer.start(self.typing_speed)
            return
            
        # Type the next character
        char = text[0]
        self.typing_queue[0] = text[1:]
        
        if char == '\n':
            # Handle newline
            self.lines.append(self.current_line)
            self.current_line = ""
            self.cursor_pos = 0
        else:
            # Add character
            self.current_line += char
            self.cursor_pos += 1
            
        # Limit number of lines
        if len(self.lines) > self.max_lines:
            self.lines = self.lines[-self.max_lines:]
            
        self.update()

    def clear(self):
        """Clear the console"""
        self.lines = []
        self.current_line = ""
        self.cursor_pos = 0
        self.typing_queue = []
        self.update()

    def paintEvent(self, event):
        """Paint the terminal console"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Set font
        font = QFont("Courier New", 10)
        font.setBold(False)
        painter.setFont(font)
        
        # Get font metrics
        fm = painter.fontMetrics()
        line_height = fm.height()
        
        # Clear background
        painter.fillRect(self.rect(), Qt.black)
        
        # Draw border
        painter.setPen(QColor("#007700"))
        painter.drawRect(0, 0, self.width() - 1, self.height() - 1)
        
        # Draw text
        painter.setPen(QColor("#00ff00"))
        
        # Calculate visible lines to avoid drawing too many
        visible_lines = self.height() // line_height
        start_idx = max(0, len(self.lines) - visible_lines + 1)
        
        # Draw stored lines
        y = self.height() - line_height * (visible_lines)
        for i in range(start_idx, len(self.lines)):
            painter.drawText(5, y, self.lines[i])
            y += line_height
            
        # Draw current line
        painter.drawText(5, self.height() - line_height, self.current_line)
        
        # Draw cursor if blinking is on
        if self.cursor_blink:
            cursor_x = 5 + fm.horizontalAdvance(self.current_line[:self.cursor_pos])
            painter.fillRect(cursor_x, self.height() - line_height, 2, line_height, QColor("#00ff00"))
        
        painter.end()

    def keyPressEvent(self, event):
        """Handle key press events for input"""
        key = event.key()
        
        if key == Qt.Key_Return or key == Qt.Key_Enter:
            # Enter key - process command
            self.lines.append(self.current_line)
            self.current_line = ""
            self.cursor_pos = 0
        elif key == Qt.Key_Backspace:
            # Backspace key
            if self.cursor_pos > 0:
                self.current_line = (self.current_line[:self.cursor_pos-1] + 
                                    self.current_line[self.cursor_pos:])
                self.cursor_pos -= 1
        elif key == Qt.Key_Left:
            # Left arrow
            self.cursor_pos = max(0, self.cursor_pos - 1)
        elif key == Qt.Key_Right:
            # Right arrow
            self.cursor_pos = min(len(self.current_line), self.cursor_pos + 1)
        elif key == Qt.Key_Home:
            # Home key
            self.cursor_pos = 0
        elif key == Qt.Key_End:
            # End key
            self.cursor_pos = len(self.current_line)
        elif key == Qt.Key_Delete:
            # Delete key
            if self.cursor_pos < len(self.current_line):
                self.current_line = (self.current_line[:self.cursor_pos] + 
                                    self.current_line[self.cursor_pos+1:])
        elif event.text():
            # Regular text input
            self.current_line = (self.current_line[:self.cursor_pos] + 
                                event.text() + 
                                self.current_line[self.cursor_pos:])
            self.cursor_pos += len(event.text())
        
        # Ensure we're not storing too many lines
        if len(self.lines) > self.max_lines:
            self.lines = self.lines[-self.max_lines:]
            
        self.update()
        
        # Reset cursor blink
        self.cursor_blink = True
        
        # Inform parent widget that we're handling this
        event.accept()

if __name__ == "__main__":
    # Simple test for the Matrix rain effect
    from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout
    
    app = QApplication(sys.argv)
    
    window = QMainWindow()
    window.setWindowTitle("Matrix Effects Test")
    window.setGeometry(100, 100, 800, 600)
    
    central_widget = QWidget()
    window.setCentralWidget(central_widget)
    
    layout = QVBoxLayout(central_widget)
    
    # Add Matrix rain effect
    matrix_rain = MatrixRain(density=30, speed=60)
    layout.addWidget(matrix_rain, 2)
    
    # Add terminal console
    terminal = TerminalConsole()
    layout.addWidget(terminal, 1)
    
    # Add some text to the terminal
    terminal.add_text("HARDN MATRIX SECURITY INTERFACE v1.0.0\n")
    terminal.add_text("Initializing security protocols...\n", animate=True)
    terminal.add_text("System ready. Enter command: ", animate=True)
    
    window.show()
    
    sys.exit(app.exec_())