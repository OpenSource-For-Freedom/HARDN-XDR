# HARDN Security Interface - Development Guide

## Overview

This guide provides information for developers working on the HARDN Security Interface GUI. It covers setup, development workflow, coding standards, and best practices.

## Development Environment Setup

### Prerequisites

- Python 3.8 or higher
- PyQt5
- Git
- A code editor with Python support (VS Code recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/OpenSource-For-Freedom/HARDN.git
   cd hardn
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### Running the Application

To run the application in development mode:

```bash
cd ~/HARDN/src
python -m gui.main
```

## Project Structure

The GUI code is organized as follows:

```
gui/
├── app.py                  # Main application entry point
├── main.py                 # Launcher script
├── docs/                   # Documentation
└── src/                    # Source code
    ├── main_window.py      # Main window implementation
    ├── controllers/        # Controllers (to be implemented)
    ├── models/             # Models (to be implemented)
    ├── views/              # View implementations
    │   ├── login_view.py
    │   ├── dashboard_view.py
    │   ├── network_view.py
    │   ├── threat_view.py
    │   ├── settings_view.py
    │   └── logs_view.py
    ├── widgets/            # Reusable UI components
    │   ├── matrix_rain.py
    │   ├── threat_gauge.py
    │   ├── terminal_console.py
    │   ├── metric_card.py
    │   └── status_indicator.py
    ├── utils/              # Utility functions
    ├── ui/                 # UI resources
    └── resources/          # Application resources
```

## Development Workflow

### 1. Branching Strategy

- `Primary`: Production-ready code
- `Dev-t`: Development branch
- Feature branches: `tbd`
- Bug fix branches: `tbd`

### 2. Development Process

1. Create a feature branch from `Dev-t`
2. Implement the feature
3. Write tests
4. Submit a pull request
5. Code review
6. Merge to `Dev-t`
7. Periodically merge `Dev-t` to `Primary` for releases

### 3. Code Review Process

- All code changes must be reviewed by at least two other developers
- Code must pass all tests
- Code must adhere to coding standards
- Documentation must be updated

## Coding Standards

### Python Style Guide

Follow PEP 8 for Python code style:

- Use 4 spaces for indentation
- Maximum line length of 100 characters
- Use descriptive variable and function names
- Add docstrings to all classes and functions

### PyQt Coding Standards

- Use Qt's signal/slot mechanism for communication
- Keep UI code separate from business logic
- Use Qt's parent-child relationship for memory management
- Follow Qt's naming conventions

### Example

```python
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel
from PyQt5.QtCore import pyqtSignal

class CustomWidget(QWidget):
    """A custom widget with Matrix styling.
    
    This widget displays a title and content with Matrix-inspired styling.
    
    Attributes:
        title (str): The widget title
        content (str): The widget content
    """
    
    # Define signals
    clicked = pyqtSignal()
    
    def __init__(self, title="", content="", parent=None):
        """Initialize the widget.
        
        Args:
            title (str, optional): The widget title. Defaults to "".
            content (str, optional): The widget content. Defaults to "".
            parent (QWidget, optional): The parent widget. Defaults to None.
        """
        super().__init__(parent)
        
        self.title = title
        self.content = content
        
        self._setup_ui()
    
    def _setup_ui(self):
        """Set up the user interface."""
        layout = QVBoxLayout()
        
        # Create title label
        self.title_label = QLabel(self.title)
        self.title_label.setObjectName("titleLabel")
        layout.addWidget(self.title_label)
        
        # Create content label
        self.content_label = QLabel(self.content)
        self.content_label.setObjectName("contentLabel")
        layout.addWidget(self.content_label)
        
        self.setLayout(layout)
```

## Testing

### Unit Testing

Use pytest for unit testing:

```python
# test_custom_widget.py
import pytest
from PyQt5.QtWidgets import QApplication
from gui.src.widgets.custom_widget import CustomWidget

@pytest.fixture
def app():
    return QApplication([])

@pytest.fixture
def widget(app):
    return CustomWidget(title="Test Title", content="Test Content")

def test_widget_initialization(widget):
    assert widget.title == "Test Title"
    assert widget.content == "Test Content"

def test_widget_clicked_signal(widget, app):
    clicked = False
    
    def on_clicked():
        nonlocal clicked
        clicked = True
    
    widget.clicked.connect(on_clicked)
    widget.clicked.emit()
    
    assert clicked
```

### UI Testing

For UI testing, use Qt's test framework:

```python
# test_main_window.py
from PyQt5.QtWidgets import QApplication
from PyQt5.QtTest import QTest
from PyQt5.QtCore import Qt
from gui.src.main_window import MainWindow

def test_login(qtbot):
    app = QApplication([])
    window = MainWindow()
    
    # Find login widgets
    username_input = window.findChild(QLineEdit, "usernameInput")
    password_input = window.findChild(QLineEdit, "passwordInput")
    login_button = window.findChild(QPushButton, "loginButton")
    
    # Enter credentials
    QTest.keyClicks(username_input, "admin")
    QTest.keyClicks(password_input, "password")
    
    # Click login button
    QTest.mouseClick(login_button, Qt.LeftButton)
    
    # Check result
    assert window.is_logged_in()
```

## Debugging

### Logging

Use Python's logging module for debugging:

```python
import logging

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='hardn_gui.log'
)

# In your code
logger = logging.getLogger(__name__)

def some_function():
    logger.debug("Entering some_function")
    # ...
    logger.info("Operation completed successfully")
    # ...
    logger.error("An error occurred", exc_info=True)
```

### Qt Debugging

For Qt-specific debugging:

```python
# Enable Qt debug output
import os
os.environ["QT_LOGGING_RULES"] = "*.debug=true;qt.qpa.*=false"

# In your code
from PyQt5.QtCore import qDebug
qDebug("Debug message")
```

## Performance Optimization

### 1. Minimize UI Updates

- Use `setUpdatesEnabled(False)` for batch updates
- Update only what has changed
- Use `QTimer` for periodic updates

### 2. Efficient Data Handling

- Use Qt's model/view architecture
- Implement data caching
- Use pagination for large datasets

### 3. Memory Management

- Use Qt's parent-child relationship
- Avoid circular references
- Use weak references where appropriate

## Deployment

### Building the Application

Use PyInstaller to create a standalone executable:

```bash
pyinstaller --onefile --windowed --icon=resources/icon.ico gui/main.py
```

### Packaging

For distribution, create a package:

```bash
python setup.py sdist bdist_wheel
```

## Troubleshooting

### Common Issues

1. **Application crashes on startup**
   - Check for missing dependencies
   - Verify resource paths
   - Check for syntax errors

2. **UI is unresponsive**
   - Check for long-running operations in the main thread
   - Verify signal/slot connections
   - Check for infinite loops

3. **Memory leaks**
   - Use Qt's parent-child relationship
   - Check for circular references
   - Use Qt's memory debugging tools

## Resources

- [PyQt5 Documentation](https://www.riverbankcomputing.com/static/Docs/PyQt5/)
- [Qt Documentation](https://doc.qt.io/)
- [Python Style Guide (PEP 8)](https://www.python.org/dev/peps/pep-0008/)
- [pytest Documentation](https://docs.pytest.org/) 