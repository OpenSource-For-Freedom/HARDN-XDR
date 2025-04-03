#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Matrix-style terminal console widget for HARDN Security Interface
"""

from PyQt5.QtCore import Qt, QTimer, QRect, pyqtSlot, pyqtSignal
from PyQt5.QtGui import QPainter, QColor, QFont, QPen, QTextCursor, QFontMetrics, QTextOption, QTextCharFormat
from PyQt5.QtWidgets import QWidget, QPlainTextEdit, QVBoxLayout


class TerminalConsole(QPlainTextEdit):
    """A Matrix-style terminal console for command input and output"""
    
    command_entered = pyqtSignal(str)
    
    def __init__(self, parent=None, color="#00ff00", prompt="> "):
        """Initialize the terminal console widget
        
        Args:
            parent: Parent widget
            color: Text color as hex string
            prompt: Command prompt prefix
        """
        super().__init__(parent)
        
        # Properties
        self._color = QColor(color)
        self._prompt = prompt
        self._command_history = []
        self._history_index = 0
        self._current_command = ""
        self._cursor_blink = True
        self._locked = False  # If True, input is disabled
        
        # Setup appearance
        self.setup_terminal_appearance()
        
        # Setup cursor
        self._cursor_timer = QTimer(self)
        self._cursor_timer.timeout.connect(self._blink_cursor)
        self._cursor_timer.start(500)  # Blink every 500ms
        
        # Initialize with prompt
        self.clear()
        self.insert_prompt()
        
    def setup_terminal_appearance(self):
        """Configure appearance to match Matrix style"""
        # Set font
        font = QFont("Courier New", 11)
        font.setStyleHint(QFont.Monospace)
        self.setFont(font)
        
        # Set colors
        self.setStyleSheet(f"""
            QPlainTextEdit {{
                background-color: #000000;
                color: {self._color.name()};
                border: 1px solid {self._color.name()};
                selection-background-color: #00aa00;
                selection-color: #000000;
                padding: 5px;
            }}
        """)
        
        # No scrollbar, fixed line wrapping
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setLineWrapMode(QPlainTextEdit.WidgetWidth)
        
        # Make read-only to handle input manually
        self.setReadOnly(False)
    
    def insert_prompt(self):
        """Insert command prompt"""
        self.textCursor().insertText(self._prompt)
        
    def keyPressEvent(self, event):
        """Handle key press events"""
        if self._locked:
            return
            
        key = event.key()
        
        # Enter key - execute command
        if key == Qt.Key_Return or key == Qt.Key_Enter:
            self._handle_enter()
            return
            
        # Up/Down keys - navigate command history
        if key == Qt.Key_Up:
            self._handle_up()
            return
        if key == Qt.Key_Down:
            self._handle_down()
            return
            
        # Backspace key - delete previous character
        if key == Qt.Key_Backspace:
            self._handle_backspace()
            return
            
        # Home key - move to start of line after prompt
        if key == Qt.Key_Home:
            self._handle_home()
            return
            
        # Left key - don't move before prompt
        if key == Qt.Key_Left or key == Qt.Key_Backspace:
            cursor = self.textCursor()
            prompt_position = self.document().lastBlock().position() + len(self._prompt)
            if cursor.position() <= prompt_position:
                return
                
        # Only accept regular text input or navigation
        if event.text() and ord(event.text()[0]) >= 32:
            super().keyPressEvent(event)
        elif key in (Qt.Key_Left, Qt.Key_Right, Qt.Key_End):
            super().keyPressEvent(event)
        
    def _handle_enter(self):
        """Process command on Enter key"""
        cursor = self.textCursor()
        cursor.movePosition(QTextCursor.End)
        self.setTextCursor(cursor)
        
        # Get command text
        cmd_start_pos = self.document().lastBlock().position() + len(self._prompt)
        cursor.setPosition(cmd_start_pos, QTextCursor.MoveAnchor)
        cursor.movePosition(QTextCursor.End, QTextCursor.KeepAnchor)
        command = cursor.selectedText()
        
        # Add newline
        self.appendPlainText("")
        
        if command:
            # Add to history if not empty
            self._command_history.append(command)
            self._history_index = len(self._command_history)
            
            # Emit signal with command
            self.command_entered.emit(command)
        
        # Add new prompt
        self.insert_prompt()
        
    def _handle_up(self):
        """Navigate command history with Up key"""
        if not self._command_history:
            return
            
        # Save current command if at the end of history
        if self._history_index == len(self._command_history):
            cursor = self.textCursor()
            prompt_position = self.document().lastBlock().position() + len(self._prompt)
            cursor.setPosition(prompt_position, QTextCursor.MoveAnchor)
            cursor.movePosition(QTextCursor.End, QTextCursor.KeepAnchor)
            self._current_command = cursor.selectedText()
            
        # Move up in history
        self._history_index = max(0, self._history_index - 1)
        
        # Replace current line with command from history
        cursor = self.textCursor()
        cursor.setPosition(self.document().lastBlock().position() + len(self._prompt), 
                          QTextCursor.MoveAnchor)
        cursor.movePosition(QTextCursor.End, QTextCursor.KeepAnchor)
        cursor.removeSelectedText()
        cursor.insertText(self._command_history[self._history_index])
        
    def _handle_down(self):
        """Navigate command history with Down key"""
        if not self._command_history:
            return
            
        # Move down in history or restore current command
        if self._history_index < len(self._command_history) - 1:
            self._history_index += 1
            # Replace with next command
            cursor = self.textCursor()
            cursor.setPosition(self.document().lastBlock().position() + len(self._prompt), 
                              QTextCursor.MoveAnchor)
            cursor.movePosition(QTextCursor.End, QTextCursor.KeepAnchor)
            cursor.removeSelectedText()
            cursor.insertText(self._command_history[self._history_index])
        elif self._history_index == len(self._command_history) - 1:
            self._history_index += 1
            # Restore current command
            cursor = self.textCursor()
            cursor.setPosition(self.document().lastBlock().position() + len(self._prompt), 
                              QTextCursor.MoveAnchor)
            cursor.movePosition(QTextCursor.End, QTextCursor.KeepAnchor)
            cursor.removeSelectedText()
            cursor.insertText(self._current_command)
            
    def _handle_backspace(self):
        """Handle backspace to prevent deleting prompt"""
        cursor = self.textCursor()
        prompt_position = self.document().lastBlock().position() + len(self._prompt)
        if cursor.position() > prompt_position:
            cursor.deletePreviousChar()
            
    def _handle_home(self):
        """Handle Home key to move after prompt"""
        cursor = self.textCursor()
        cursor.setPosition(self.document().lastBlock().position() + len(self._prompt))
        self.setTextCursor(cursor)
        
    def _blink_cursor(self):
        """Blink cursor animation"""
        self._cursor_blink = not self._cursor_blink
        if self._cursor_blink:
            self.setCursorWidth(8)  # Thick cursor when visible
        else:
            self.setCursorWidth(0)  # Hide cursor
            
    def write_output(self, text, error=False):
        """Write text to the terminal as output
        
        Args:
            text: Text to write
            error: If True, text is an error message (in red)
        """
        # Save cursor position
        cursor = self.textCursor()
        cursor_pos = cursor.position()
        cursor.movePosition(QTextCursor.End)
        self.setTextCursor(cursor)
        
        # Insert a newline if not at the start of a line
        if not cursor.atBlockStart():
            self.appendPlainText("")
            
        # Set text color
        if error:
            format = QTextCharFormat()
            format.setForeground(QColor("#ff0000"))  # Red for errors
            self.textCursor().setCharFormat(format)  # Red for errors
        else:
            format = QTextCharFormat()
            format.setForeground(self._color)
            self.textCursor().setCharFormat(format)  # Normal color
            
        # Insert text and reset color
        for line in text.split('\n'):
            if line:
                self.appendPlainText(line)
            else:
                self.appendPlainText("")
                
        # Add new prompt
        self.insert_prompt()
        
        # Reset to normal color
        format = QTextCharFormat()
        format.setForeground(self._color)
        self.textCursor().setCharFormat(format)
        
    def lock_input(self, locked=True):
        """Disable or enable user input
        
        Args:
            locked: If True, input is disabled
        """
        self._locked = locked
        
    def set_prompt(self, prompt):
        """Change the command prompt
        
        Args:
            prompt: New prompt string
        """
        self._prompt = prompt
        

class MatrixTerminal(QWidget):
    """A Matrix-styled terminal widget with fancy border"""
    
    command_entered = pyqtSignal(str)
    
    def __init__(self, parent=None, color="#00ff00", prompt="> "):
        """Initialize the Matrix terminal widget
        
        Args:
            parent: Parent widget
            color: Terminal color as hex string
            prompt: Command prompt prefix
        """
        super().__init__(parent)
        
        # Properties
        self._color = QColor(color)
        self._border_animation = 0
        self._header_text = "HARDN SECURE TERMINAL"
        
        # Terminal console
        self._terminal = TerminalConsole(self, color, prompt)
        self._terminal.command_entered.connect(self.command_entered)
        
        # Layout
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 30, 10, 10)  # Extra margin at top for header
        layout.addWidget(self._terminal)
        self.setLayout(layout)
        
        # Animation timer
        self._animation_timer = QTimer(self)
        self._animation_timer.timeout.connect(self._update_animation)
        self._animation_timer.start(50)
        
        # Minimum size
        self.setMinimumSize(300, 200)
        
    def paintEvent(self, event):
        """Paint the terminal border and header"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Get drawing area
        rect = self.rect()
        
        # Draw background
        bg_color = QColor(0, 0, 0)
        painter.fillRect(rect, bg_color)
        
        # Draw animated border
        pen = QPen(self._color)
        pen.setWidth(2)
        painter.setPen(pen)
        
        # Top border (with header)
        header_rect = QRect(rect.left(), rect.top(), rect.width(), 25)
        painter.drawLine(rect.left(), header_rect.bottom(), rect.right(), header_rect.bottom())
        
        # Left border
        painter.drawLine(rect.left(), header_rect.bottom(), rect.left(), rect.bottom())
        
        # Right border
        painter.drawLine(rect.right(), header_rect.bottom(), rect.right(), rect.bottom())
        
        # Bottom border with animation
        anim_length = 30  # Length of animated segment
        border_pos = (self._border_animation * 2) % (rect.width() * 2)
        
        if border_pos < rect.width():
            # Moving left to right
            start_x = rect.left() + border_pos - anim_length
            end_x = rect.left() + border_pos
            
            # Draw static segments
            if start_x > rect.left():
                painter.drawLine(rect.left(), rect.bottom(), start_x, rect.bottom())
            if end_x < rect.right():
                painter.drawLine(end_x, rect.bottom(), rect.right(), rect.bottom())
                
            # Draw animated segment with glow
            if end_x > rect.left() and start_x < rect.right():
                glow_pen = QPen(self._color)
                glow_pen.setWidth(3)
                painter.setPen(glow_pen)
                actual_start = max(rect.left(), start_x)
                actual_end = min(rect.right(), end_x)
                painter.drawLine(actual_start, rect.bottom(), actual_end, rect.bottom())
                
        else:
            # Moving right to left
            border_pos = border_pos - rect.width()
            start_x = rect.right() - border_pos
            end_x = rect.right() - border_pos + anim_length
            
            # Draw static segments
            if start_x > rect.left():
                painter.drawLine(rect.left(), rect.bottom(), start_x, rect.bottom())
            if end_x < rect.right():
                painter.drawLine(end_x, rect.bottom(), rect.right(), rect.bottom())
                
            # Draw animated segment with glow
            if end_x > rect.left() and start_x < rect.right():
                glow_pen = QPen(self._color)
                glow_pen.setWidth(3)
                painter.setPen(glow_pen)
                actual_start = max(rect.left(), start_x)
                actual_end = min(rect.right(), end_x)
                painter.drawLine(actual_start, rect.bottom(), actual_end, rect.bottom())
        
        # Draw header text
        painter.setPen(self._color)
        font = QFont("Courier New", 10)
        font.setBold(True)
        painter.setFont(font)
        painter.drawText(header_rect, Qt.AlignCenter, self._header_text)
        
        painter.end()
        
    def _update_animation(self):
        """Update animation state"""
        self._border_animation = (self._border_animation + 1) % (self.width() * 2)
        self.update()
        
    def write_output(self, text, error=False):
        """Write output to the terminal
        
        Args:
            text: Text to write
            error: If True, text is formatted as an error
        """
        self._terminal.write_output(text, error)
        
    def set_header(self, text):
        """Set the terminal header text
        
        Args:
            text: New header text
        """
        self._header_text = text
        self.update()
        
    def set_color(self, color):
        """Set the terminal color
        
        Args:
            color: New color as hex string or QColor
        """
        if isinstance(color, str):
            self._color = QColor(color)
        else:
            self._color = color
        self._terminal.setStyleSheet(f"""
            QPlainTextEdit {{
                background-color: #000000;
                color: {self._color.name()};
                border: none;
                selection-background-color: #00aa00;
                selection-color: #000000;
                padding: 5px;
            }}
        """)
        self.update()
        
    def get_terminal(self):
        """Get the underlying terminal widget
        
        Returns:
            The TerminalConsole widget
        """
        return self._terminal


if __name__ == "__main__":
    # Simple test for the Matrix Terminal
    import sys
    from PyQt5.QtWidgets import QApplication, QMainWindow
    
    app = QApplication(sys.argv)
    
    window = QMainWindow()
    window.setWindowTitle("Matrix Terminal Test")
    window.setGeometry(100, 100, 800, 600)
    window.setStyleSheet("background-color: #000000;")
    
    terminal = MatrixTerminal()
    window.setCentralWidget(terminal)
    
    def handle_command(cmd):
        if cmd.lower() == "exit":
            app.quit()
        elif cmd.lower() == "help":
            terminal.write_output("Available commands: help, echo, exit")
        elif cmd.lower().startswith("echo "):
            terminal.write_output(cmd[5:])
        else:
            terminal.write_output(f"Unknown command: {cmd}", error=True)
    
    terminal.command_entered.connect(handle_command)
    terminal.write_output("Matrix Terminal v1.0\nType 'help' for available commands.")
    
    window.show()
    
    sys.exit(app.exec_())
