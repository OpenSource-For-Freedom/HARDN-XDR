# HARDN Security Interface - Component Reference

This document provides detailed information about the key components of the HARDN Security Interface GUI.

## Views

### LoginView

**File**: `src/gui/src/views/login_view.py`

**Description**: The login screen with Matrix-style authentication.

**Key Features**:
- Matrix rain animation background
- Centered login panel with glowing border
- Username and password fields
- Remember credentials checkbox
- Authentication status messages
- Login success signal

**Usage**:
```python
from gui.src.views.login_view import LoginView

login_view = LoginView()
login_view.login_successful.connect(self._handle_login_success)
```

### DashboardView

**File**: `src/gui/src/views/dashboard_view.py`

**Description**: The main dashboard showing system metrics and status.

**Key Features**:
- System status indicators
- Threat level gauge
- Metric cards for key statistics
- Recent activity feed
- Quick action buttons

**Usage**:
```python
from gui.src.views.dashboard_view import DashboardView

dashboard_view = DashboardView()
```

### NetworkView

**File**: `src/gui/src/views/network_view.py`

**Description**: Network security monitoring view.

**Key Features**:
- Active connections table
- Traffic analysis visualization
- Network status indicators
- Firewall status
- VPN connection status

**Usage**:
```python
from gui.src.views.network_view import NetworkView

network_view = NetworkView()
```

### ThreatView

**File**: `src/gui/src/views/threat_view.py`

**Description**: Threat analysis and incident management.

**Key Features**:
- Threat level gauge
- Detected threats table
- Threat response actions
- Threat details panel
- Threat history

**Usage**:
```python
from gui.src.views.threat_view import ThreatView

threat_view = ThreatView()
```

### SettingsView

**File**: `src/gui/src/views/settings_view.py`

**Description**: Application configuration settings.

**Key Features**:
- Tabbed settings interface
- Security settings
- Network settings
- UI customization
- Notification settings

**Usage**:
```python
from gui.src.views.settings_view import SettingsView

settings_view = SettingsView()
```

### LogsView

**File**: `src/gui/src/views/logs_view.py`

**Description**: System logs and audit information.

**Key Features**:
- Log filtering options
- Log level indicators
- Search functionality
- Export options
- Real-time log updates

**Usage**:
```python
from gui.src.views.logs_view import LogsView

logs_view = LogsView()
```

## Widgets

### MatrixRain

**File**: `src/gui/src/widgets/matrix_rain.py`

**Description**: Matrix-style digital rain animation effect.

**Key Features**:
- Customizable density and speed
- Color customization
- Performance optimized
- Pause/resume functionality

**Usage**:
```python
from gui.src.widgets.matrix_rain import MatrixRain

matrix_rain = MatrixRain(density=3, speed=60, color="#00ff00")
```

**Properties**:
- `density`: Character density (higher = more characters)
- `speed`: Animation speed (lower = faster)
- `color`: Rain color as hex string

### ThreatGauge

**File**: `src/gui/src/widgets/threat_gauge.py`

**Description**: Circular gauge for threat level visualization.

**Key Features**:
- Animated value changes
- Warning and critical level indicators
- Glowing effect
- Customizable colors and labels

**Usage**:
```python
from gui.src.widgets.threat_gauge import ThreatGauge

threat_gauge = ThreatGauge()
threat_gauge.threat_level = 75  # Set threat level (0-100)
```

**Properties**:
- `threat_level`: Current threat level (0-100)
- `warning_level`: Level at which warning state begins
- `critical_level`: Level at which critical state begins
- `label`: Text label for the gauge

### TerminalConsole

**File**: `src/gui/src/widgets/terminal_console.py`

**Description**: Matrix-style terminal console for command input and output.

**Key Features**:
- Command history navigation
- Custom prompt
- Color-coded output
- Error highlighting
- Input locking

**Usage**:
```python
from gui.src.widgets.terminal_console import TerminalConsole

terminal = TerminalConsole(color="#00ff00", prompt="> ")
terminal.command_entered.connect(self._handle_command)
```

**Methods**:
- `write_output(text, error=False)`: Write text to the console
- `lock_input(locked=True)`: Lock/unlock input
- `set_prompt(prompt)`: Change the command prompt

### MetricCard

**File**: `src/gui/src/widgets/metric_card.py`

**Description**: Card component for displaying metrics with Matrix styling.

**Key Features**:
- Title and value display
- Trend indicator
- Status indicator
- Customizable colors
- Animated value changes

**Usage**:
```python
from gui.src.widgets.metric_card import MetricCard

metric_card = MetricCard(title="CPU Usage", value="45%", trend="up")
```

### StatusIndicator

**File**: `src/gui/src/widgets/status_indicator.py`

**Description**: Status indicator with Matrix-inspired animations.

**Key Features**:
- Multiple status states
- Pulsing animation
- Customizable colors
- Text label
- Icon support

**Usage**:
```python
from gui.src.widgets.status_indicator import StatusIndicator

status = StatusIndicator(label="System Status", status="secure")
```

## Main Window

**File**: `src/gui/src/main_window.py`

**Description**: Main application window that contains all views and manages navigation.

**Key Features**:
- Sidebar navigation
- Status bar
- Terminal console toggle
- Login/logout handling
- View switching

**Usage**:
```python
from gui.src.main_window import MainWindow

window = MainWindow()
window.show()
```

**Methods**:
- `_switch_view(index)`: Switch to a different view
- `_toggle_terminal()`: Toggle the terminal console
- `_handle_login_success()`: Handle successful login
- `_handle_logout()`: Handle logout
- `_update_status_bar()`: Update status bar information 