import unittest
import sys
import os
import unittest
import sys
import os
import subprocess
import hardn_dark

# Add
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

class TestHardnDark(unittest.TestCase):
    def test_example(self):
        # Call hardn_dark.py from the Src folder
        result = subprocess.run([sys.executable, "Src/hardn_dark.py"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        # Check if hardn_dark module is imported correctly
        self.assertTrue(hasattr(hardn_dark, 'some_function'), "hardn_dark module not imported correctly")

    def test_functionality(self):
        # Test 
        expected_value = "expected result"  # Def
        result = hardn_dark.some_function()
        self.assertEqual(result, expected_value, "Function did not return expected value")
        # Check for import 
        self.assertTrue(hasattr(hardn_dark, 'some_function'), "hardn_dark module not imported correctly")
        # Check if 
        self.assertTrue(hasattr(hardn_dark, 'some_function'), "hardn_dark module not imported correctly")
    

if __name__ == '__main__':
    unittest.main()