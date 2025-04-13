# HARDN Security Interface - Architecture Overview

## Introduction

The HARDN Security Interface GUI is built using PyQt5 and follows a modular architecture designed for maintainability and extensibility. This document provides a high-level overview of the GUI architecture.

## Architecture Diagram

```
+------------------+
|     Main App     |
+------------------+
        |
        v
+------------------+
|   Main Window    |
+------------------+
        |
        v
+------------------+     +------------------+
|   Login View     |     |  Dashboard View  |
+------------------+     +------------------+
        |                       |
        v                       v
+------------------+     +------------------+
|  Matrix Rain     |     |  Threat Gauge    |
+------------------+     +------------------+
        |                       |
        v                       v
+------------------+     +------------------+
|  Network View    |     |  Threat View     |
+------------------+     +------------------+
        |                       |
        v                       v
+------------------+     +------------------+
|  Settings View   |     |  Terminal Console|
+------------------+     +------------------+
```

## Package Structure

The GUI code is organized into the following packages:

```
gui/
├── __init__.py
├── app.py                  # Application entry point
├── main.py                 # Main launcher script
└── src/
    ├── __init__.py
    ├── main_window.py      # Main window implementation
    ├── controllers/        # Controller classes (future)
    ├── models/             # Data models (future)
    ├── resources/          # Icons, images, etc.
    ├── ui/                 # UI-related utilities
    ├── utils/              # Utility functions
    ├── views/              # View classes
    │   ├── __init__.py
    │   ├── dashboard_view.py
    │   ├── login_view.py
    │   ├── logs_view.py
    │   ├── network_view.py
    │   ├── settings_view.py
    │   └── threat_view.py
    └── widgets/            # Reusable widget components
        ├── __init__.py
        ├── matrix_rain.py
        ├── metric_card.py
        ├── status_indicator.py
        ├── terminal_console.py
        └── threat_gauge.py
```

## Key Components

### Main Window

The `MainWindow` class serves as the container for the entire application. It manages:

- The login view and main application views
- The sidebar navigation
- The status bar
- The terminal console

### Views

Views represent different screens in the application:

- **LoginView**: Authentication screen with Matrix rain animation
- **DashboardView**: Main dashboard with system metrics and status
- **NetworkView**: Network monitoring and security information
- **ThreatView**: Threat analysis and incident management
- **SettingsView**: Application configuration
- **LogsView**: System logs and audit information

### Widgets

Reusable UI components:

- **MatrixRain**: Digital rain animation effect
- **ThreatGauge**: Circular gauge for threat level visualization
- **TerminalConsole**: Command-line interface with Matrix styling
- **MetricCard**: Card component for displaying metrics
- **StatusIndicator**: Status indicator with animations

## Application Flow

1. The application starts with the `main.py` script, which calls the `main()` function in `app.py`
2. The `main()` function creates a QApplication instance and the MainWindow
3. The MainWindow initially shows the LoginView
4. Upon successful login, the MainWindow switches to the main application view
5. The user can navigate between different views using the sidebar
6. The terminal console can be toggled at any time

## Design Patterns

The GUI implementation follows several design patterns:

- **MVC (Model-View-Controller)**: The architecture is structured to support MVC, though the current implementation focuses on the View layer
- **Signal-Slot**: PyQt's signal-slot mechanism is used for communication between components
- **Factory Method**: Used for creating different views and widgets
- **Observer**: Used for updating the UI when data changes (to be implemented)

## Future Architecture Considerations

As the GUI moves from the visual design phase to integration:

1. **Controllers**: Will be implemented to handle business logic and user interactions
2. **Models**: Will be added to represent data structures and business entities
3. **Services**: Will be created to handle communication with backend services
4. **Event System**: Will be enhanced to support more complex event handling
5. **Configuration**: Will be expanded to support more customization options 