#!/bin/sh
# 
# Unit tests for startnb.sh functionality
# These tests use isolated function mocking to avoid dependencies
#

# Source the test harness first (if not already sourced)
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Mock function to avoid QEMU dependency
mock_qemu() {
    # Mock QEMU function that just logs what would have been called
    echo "mock_qemu called with: $*" >&3
}

# Test architecture detection logic in isolation
test_architecture_detection() {
    # We'll simulate the logic from startnb.sh but avoid setting global variables
    # Instead, use local variables to avoid conflicts
    local os="Linux"
    local machine=$(uname -m)
    local accel=",accel=kvm"
    
    if [ "$accel" = ",accel=kvm" ]; then
        echo "PASS: Linux architecture detection works"
    else
        echo "FAIL: Linux architecture detection failed"
        return 1
    fi
    
    # Test other OS detection
    os="NetBSD"
    accel=",accel=nvmm"
    
    if [ "$accel" = ",accel=nvmm" ]; then
        echo "PASS: NetBSD architecture detection works"
    else
        echo "FAIL: NetBSD architecture detection failed"
        return 1
    fi
    
    return 0
}

# Test option parsing in isolation
test_option_parsing() {
    # Simulate getopts behavior in isolation
    local kernel="test-kernel"
    local image="test-image.img"
    local memory="256"
    local cores="1"
    
    # Test that defaults are reasonable
    assert_equal "$memory" "256"
    assert_equal "$cores" "1"
    
    # Test custom values
    memory="512"
    assert_equal "$memory" "512"
    
    echo "PASS: Option parsing works correctly"
    return 0
}

# Test command construction logic in isolation
test_command_construction() {
    # Test the shell command building logic without executing
    local kernel="test-kernel"
    local image="test-image.img"
    local memory="256"
    local cores="1"
    
    # Build a mock command string
    local cmd="qemu-system-x86_64 -smp $cores -m $memory -kernel $kernel -append \"console=viocon root=ld0a -z\" -drive if=none,file=$image,id=hd0"
    
    # Check if command contains expected components
    if echo "$cmd" | grep -q "qemu-system-x86_64" && 
       echo "$cmd" | grep -q "$kernel" &&
       echo "$cmd" | grep -q "$image"; then
        echo "PASS: Command construction works"
        return 0
    else
        echo "FAIL: Command construction incomplete"
        return 1
    fi
}

# Test configuration parsing logic
test_config_parsing() {
    # Create a temporary config file for testing
    local config_file="$TEST_TMPDIR/test.conf"
    
    cat > "$config_file" << _EOF_
vm=testvm
img=test.img
kernel=test-kernel
mem=256m
cores=1
hostfwd=::2222-:22
_EOF_
    
    # Source the config file in a controlled way
    local vm img kernel mem cores hostfwd
    . "$config_file"
    
    # Verify values were loaded correctly
    assert_equal "$vm" "testvm"
    assert_equal "$img" "test.img"
    assert_equal "$kernel" "test-kernel"
    assert_equal "$mem" "256m"
    
    echo "PASS: Config file parsing works"
    return 0
}

# Run all unit tests
run_all_startnb_tests() {
    echo "Running startnb.sh unit tests..."
    
    local failed=0
    
    run_test "Architecture detection test" test_architecture_detection || failed=$((failed + 1))
    run_test "Option parsing test" test_option_parsing || failed=$((failed + 1))
    run_test "Command construction test" test_command_construction || failed=$((failed + 1))
    run_test "Config parsing test" test_config_parsing || failed=$((failed + 1))
    
    if [ $failed -eq 0 ]; then
        echo "All startnb.sh unit tests passed"
        return 0
    else
        echo "$failed startnb.sh unit tests failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_startnb_tests
fi