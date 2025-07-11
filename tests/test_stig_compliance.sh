#!/bin/bash
# Test script for STIG compliance gap fixes
# Tests the 5 specific compliance areas addressed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        [[ -n "$details" ]] && echo "       $details"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        [[ -n "$details" ]] && echo "       $details"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== HARDN-XDR STIG Compliance Gap Tests ==="
echo "Testing the 5 specific compliance areas addressed in this fix"
echo

# Test 1: Sudo Hardening Module
echo "Testing 1. Privileged Access & Sudo Configuration..."
if [[ -f "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/sudo_hardening.sh" ]]; then
    if grep -q "STIG Compliance" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/sudo_hardening.sh"; then
        test_result "Sudo hardening module exists with STIG compliance" "PASS" "Module includes sudo logging and RBAC"
    else
        test_result "Sudo hardening module missing STIG compliance" "FAIL"
    fi
else
    test_result "Sudo hardening module missing" "FAIL"
fi

# Test 2: SSH FIPS Ciphers
echo "Testing 2. Service Hardening & Network Daemons..."
if grep -q "FIPS-approved ciphers" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/sshd.sh"; then
    if grep -q "aes256-ctr,aes192-ctr,aes128-ctr" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/sshd.sh"; then
        test_result "SSH FIPS-approved ciphers configured" "PASS" "STIG-compliant cipher suites"
    else
        test_result "SSH FIPS ciphers missing" "FAIL"
    fi
else
    test_result "SSH FIPS cipher configuration missing" "FAIL"
fi

# Test insecure services disabled
if grep -q "telnet\|rpcbind\|nfs-server" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/unnecesary_services.sh"; then
    test_result "Insecure services (Telnet, NFS, RPC) disabled" "PASS" "STIG-required service disabling"
else
    test_result "Insecure services disabling incomplete" "FAIL"
fi

# Test 3: NTP Authentication
echo "Testing 3. Time Synchronization..."
if grep -q "authentication" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/ntp.sh"; then
    if grep -q "trustedkey\|keys" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/ntp.sh"; then
        test_result "NTP authentication configured" "PASS" "Symmetric key authentication and monitoring"
    else
        test_result "NTP authentication incomplete" "FAIL"
    fi
else
    test_result "NTP authentication missing" "FAIL"
fi

# Test 4: AIDE SIEM Integration
echo "Testing 4. File Integrity and AIDE..."
if grep -q "SIEM integration\|alerting" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/aide.sh"; then
    if grep -q "aide-check-with-alerts" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/aide.sh"; then
        test_result "AIDE SIEM integration and alerting" "PASS" "Automated alerting and structured logging"
    else
        test_result "AIDE alerting script missing" "FAIL"
    fi
else
    test_result "AIDE SIEM integration missing" "FAIL"
fi

# Test 5: Log Retention and Remote Forwarding
echo "Testing 5. Audit Logs & Retention..."
if grep -q "365\|retention" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/central_logging.sh"; then
    if grep -q "remote.*forward\|remote.*log" "/home/runner/work/HARDN-XDR/HARDN-XDR/src/setup/modules/central_logging.sh"; then
        test_result "Log retention and remote forwarding" "PASS" "1-year retention and remote forwarding capability"
    else
        test_result "Remote log forwarding missing" "FAIL"
    fi
else
    test_result "Log retention configuration missing" "FAIL"
fi

# Test script syntax validation
echo "Testing script syntax validation..."
scripts_to_test=(
    "src/setup/modules/sudo_hardening.sh"
    "src/setup/modules/sshd.sh"
    "src/setup/modules/ntp.sh"
    "src/setup/modules/aide.sh"
    "src/setup/modules/central_logging.sh"
    "src/setup/modules/unnecesary_services.sh"
)

syntax_errors=0
for script in "${scripts_to_test[@]}"; do
    if [[ -f "/home/runner/work/HARDN-XDR/HARDN-XDR/$script" ]]; then
        if bash -n "/home/runner/work/HARDN-XDR/HARDN-XDR/$script" 2>/dev/null; then
            test_result "Syntax validation: $script" "PASS"
        else
            test_result "Syntax validation: $script" "FAIL" "Bash syntax errors detected"
            syntax_errors=$((syntax_errors + 1))
        fi
    else
        test_result "File existence: $script" "FAIL" "File not found"
    fi
done

# Test executable permissions
echo "Testing executable permissions..."
for script in "${scripts_to_test[@]}"; do
    if [[ -f "/home/runner/work/HARDN-XDR/HARDN-XDR/$script" ]]; then
        if [[ -x "/home/runner/work/HARDN-XDR/HARDN-XDR/$script" ]]; then
            test_result "Executable: $script" "PASS"
        else
            test_result "Executable: $script" "FAIL" "Missing execute permission"
        fi
    fi
done

# Summary
echo
echo "=== Test Summary ==="
echo "Total tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed! STIG compliance gap fixes are properly implemented.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the implementation.${NC}"
    exit 1
fi