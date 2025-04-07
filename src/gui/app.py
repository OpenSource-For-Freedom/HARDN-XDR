#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HARDN Security Interface - Main application entry point
"""

import sys
import os
from PyQt5.QtWidgets import QApplication
from PyQt5.QtGui import QIcon

from gui.src.main_window import MainWindow


def main():
    """Main application entry point"""
    # Create Qt application
    app = QApplication(sys.argv)
    
    # Set application name and organization
    app.setApplicationName("HARDN Security Interface")
    app.setOrganizationName("HARDN")
    
    # Load application icon
    icon_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "src", "resources", "icons", "hardn_icon.png"
    )
    
    if os.path.exists(icon_path):
        app.setWindowIcon(QIcon(icon_path))
    
    # Create and show the main window
    window = MainWindow()
    window.show()
    
    # Start the application event loop
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
