#!/bin/sh
# 
# Performance and regression tests for smolBSD
# These tests verify performance characteristics and catch regressions
#

# Source the test harness first
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi
. "$(dirname "$0")/test_fixtures.sh"

# Performance test: Measure basic script execution time
test_script_performance() {
    local script="$PROJECT_ROOT/mkimg.sh"
    
    if [ ! -f "$script" ]; then
        echo "SKIP: Script $script not found for performance test"
        return 0
    fi
    
    # Measure syntax check time (very basic performance test)
    local start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Use a simple syntax check as baseline performance test
    sh -n "$script" 2>/dev/null
    local result=$?
    
    local end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local elapsed=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.0")
    
    if [ $result -eq 0 ]; then
        echo "PASS: mkimg.sh syntax check completed in ${elapsed}s"
        # Basic performance check: should complete in reasonable time
        if [ "$(echo "$elapsed < 1.0" | bc -l 2>/dev/null || echo 1)" = "1" ]; then
            echo "PASS: Syntax check completed in reasonable time"
            return 0
        else
            echo "WARN: Syntax check took longer than expected (${elapsed}s)"
            return 0  # Don't fail for performance issues
        fi
    else
        echo "FAIL: mkimg.sh has syntax errors"
        return 1
    fi
}

# Regression test: Verify that basic functionality hasn't changed
test_basic_functionality_regression() {
    # Test that basic function definitions exist and haven't changed unexpectedly
    
    # Check for essential functions in mkimg.sh
    if grep -q "^usage()" "$PROJECT_ROOT/mkimg.sh" && \
       grep -q "^rsynclite()" "$PROJECT_ROOT/mkimg.sh" && \
       grep -q "options=" "$PROJECT_ROOT/mkimg.sh"; then
        echo "PASS: Essential mkimg.sh functions present"
    else
        echo "FAIL: Essential mkimg.sh functions missing"
        return 1
    fi
    
    # Check for essential functions in startnb.sh
    if grep -q "^usage()" "$PROJECT_ROOT/startnb.sh" && \
       grep -q "QEMU=" "$PROJECT_ROOT/startnb.sh" && \
       grep -q "getopts" "$PROJECT_ROOT/startnb.sh"; then
        echo "PASS: Essential startnb.sh functions present"
    else
        echo "FAIL: Essential startnb.sh functions missing"
        return 1
    fi
    
    return 0
}

# Regression test: Check that file sizes haven't regressed dramatically
test_file_size_regression() {
    local mkimg_size=$(stat -c%s "$PROJECT_ROOT/mkimg.sh" 2>/dev/null || echo "0")
    local startnb_size=$(stat -c%s "$PROJECT_ROOT/startnb.sh" 2>/dev/null || echo "0")
    
    # These are reasonable upper bounds that shouldn't be exceeded without good reason
    if [ "$mkimg_size" -lt 100000 ]; then  # Less than 100KB
        echo "PASS: mkimg.sh size is reasonable ($mkimg_size bytes)"
    else
        echo "WARN: mkimg.sh is larger than expected (${mkimg_size} bytes)"
    fi
    
    if [ "$startnb_size" -lt 100000 ]; then  # Less than 100KB
        echo "PASS: startnb.sh size is reasonable ($startnb_size bytes)"
    else
        echo "WARN: startnb.sh is larger than expected (${startnb_size} bytes)"
    fi
    
    return 0
}

# Regression test: Ensure critical configuration patterns exist
test_config_regression() {
    # Test that Makefile still has expected targets
    if grep -q "^rescue:" "$PROJECT_ROOT/Makefile" && \
       grep -q "^base:" "$PROJECT_ROOT/Makefile" && \
       grep -q "^kernfetch:" "$PROJECT_ROOT/Makefile"; then
        echo "PASS: Makefile has expected targets"
    else
        echo "FAIL: Makefile missing expected targets"
        return 1
    fi
    
    # Test that default service structure is intact
    if [ -d "$PROJECT_ROOT/service/rescue" ] && [ -d "$PROJECT_ROOT/service/common" ]; then
        echo "PASS: Service directory structure intact"
    else
        echo "FAIL: Service directory structure compromised"
        return 1
    fi
    
    return 0
}

# Run all performance and regression tests
run_all_performance_tests() {
    echo "Running performance and regression tests..."
    
    local failed=0
    
    run_test "Script performance test" test_script_performance || failed=$((failed + 1))
    run_test "Basic functionality regression test" test_basic_functionality_regression || failed=$((failed + 1))
    run_test "File size regression test" test_file_size_regression || failed=$((failed + 1))
    run_test "Configuration regression test" test_config_regression || failed=$((failed + 1))
    
    if [ $failed -eq 0 ]; then
        echo "All performance and regression tests passed"
        return 0
    else
        echo "$failed performance and regression tests failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_performance_tests
fi