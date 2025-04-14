import os
import subprocess
import pytest
from src.gui.main import launch_gui  # from src/gui/main.py

@pytest.fixture
def setup_environment():
    """Fixture to validate the environment before running tests."""
    if os.geteuid() != 0:
        pytest.skip("This test must be run as root. Skipping...")
    print("Environment validated successfully.")

@pytest.fixture
def make_files_executable():
    """Fixture to set executable permissions for required files."""
    files_to_chmod = [
        "setup/setup.sh",
        "setup/packages.sh",
        "src/kernel.rs",
    ]

    # Add all files in src/gui to the list
    gui_dir = "src/gui"
    for root, _, files in os.walk(gui_dir):
        for file in files:
            files_to_chmod.append(os.path.join(root, file))

    for file in files_to_chmod:
        print(f"Setting executable permissions for {file}...")
        subprocess.check_call(["chmod", "+x", file])
    print("All required files are now executable.")

def test_launch_gui(setup_environment):
    """Test to ensure the GUI launches without errors."""
    try:
        launch_gui()
        print("GUI launched successfully.")
    except Exception as e:
        pytest.fail(f"Failed to launch GUI: {e}")

def test_run_setup_scripts(make_files_executable):
    """Test to ensure setup scripts run successfully."""
    scripts = ["setup/setup.sh", "setup/packages.sh"]
    for script in scripts:
        try:
            print(f"Running {script}...")
            subprocess.check_call(["/bin/bash", script])
            print(f"{script} executed successfully.")
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Error running {script}: {e}")

def test_run_kernel():
    """Test to ensure kernel.rs runs successfully."""
    try:
        print("Running kernel hardening (kernel.rs)...")
        subprocess.check_call(["cargo", "run", "--bin", "kernel"], cwd="src")
        print("Kernel hardening completed successfully.")
    except subprocess.CalledProcessError as e:
        pytest.fail(f"Error running kernel.rs: {e}")