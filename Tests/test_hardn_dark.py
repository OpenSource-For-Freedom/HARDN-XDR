import unittest
import sys
import os
import subprocess

# Add path to parent directory to allow imports from Src
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import after setting up the path
from Src import hardn_dark

class TestHardnDark(unittest.TestCase):
    def test_example(self):
        # Call hardn_dark.py from the Src folder
        result = subprocess.run([sys.executable, "Src/hardn_dark.py"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        # Check if hardn_dark module is imported correctly
        self.assertTrue(hasattr(hardn_dark, 'check_compatibility'), "hardn_dark module not imported correctly")

    def test_functionality(self):
        # Test a function that actually exists in hardn_dark.py
        # For example, testing check_compatibility which returns True for Debian-based systems
        self.assertTrue(hasattr(hardn_dark, 'check_compatibility'), "check_compatibility function not found")
        
        # We can't directly call check_compatibility in tests as it may exit the program
        # Instead, we can test other functions or mock the subprocess calls
        
        # Example: Test that run_command function exists
        self.assertTrue(hasattr(hardn_dark, 'run_command'), "run_command function not found")
        
        # Example: Test that log function exists
        self.assertTrue(hasattr(hardn_dark, 'log'), "log function not found")

if __name__ == '__main__':
    unittest.main()