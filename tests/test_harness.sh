#!/bin/sh
# 
# smolBSD Test Harness - following BSD testing standards
# This harness provides a framework for testing smolBSD components with proper isolation
#

# Set strict mode
set -eu

# Determine project root
test_harness_init() {
    # Ensure we're in the right directory structure
    if [ -z "${PROJECT_ROOT:-}" ]; then
        # Calculate from the location of this script
        PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
        export PROJECT_ROOT
    fi
    
    # Set up test-specific environment
    TEST_TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'smolbsd-test.XXXXXX')
    if [ ! -d "$TEST_TMPDIR" ]; then
        echo "ERROR: Failed to create temporary directory" >&2
        exit 1
    fi
    
    # Create subdirectories in a portable way
    mkdir -p "$TEST_TMPDIR/bin" "$TEST_TMPDIR/lib" "$TEST_TMPDIR/share" "$TEST_TMPDIR/tmp" \
             "$TEST_TMPDIR/etc" "$TEST_TMPDIR/service" "$TEST_TMPDIR/rescue"
    
    # Setup cleanup trap
    trap cleanup_test_env EXIT INT TERM QUIT
    
    # Create a safe environment for testing
    export TMPDIR="$TEST_TMPDIR/tmp"
    export PATH="$TEST_TMPDIR/bin:$PATH"
}

# Cleanup function
cleanup_test_env() {
    if [ -n "${TEST_TMPDIR:-}" ] && [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

# Basic assertion function following BSD conventions
assert() {
    if ! "$@"; then
        echo "FAIL: $*"
        return 1
    fi
    echo "PASS: $*"
    return 0
}

# Assert that a command returns successfully
assert_success() {
    if "$@"; then
        echo "PASS: $*"
        return 0
    else
        echo "FAIL: $*"
        return 1
    fi
}

# Assert that a command returns failure
assert_failure() {
    if "$@"; then
        echo "FAIL: Expected command to fail: $*"
        return 1
    else
        echo "PASS: Command failed as expected: $*"
        return 0
    fi
}

# Check if files exist
assert_file_exists() {
    if [ -e "$1" ]; then
        echo "PASS: File exists: $1"
        return 0
    else
        echo "FAIL: File does not exist: $1"
        return 1
    fi
}

# Check if files do not exist
assert_file_not_exists() {
    if [ ! -e "$1" ]; then
        echo "PASS: File does not exist: $1"
        return 0
    else
        echo "FAIL: File unexpectedly exists: $1"
        return 1
    fi
}

# Assert string equality
assert_equal() {
    if [ "$1" = "$2" ]; then
        echo "PASS: '$1' = '$2'"
        return 0
    else
        echo "FAIL: '$1' != '$2'"
        return 1
    fi
}

# Run a single test
run_test() {
    local test_name="$1"
    shift
    local test_function="$1"
    shift
    
    echo "Running $test_name..."
    
    if "$test_function" "$@"; then
        echo "OK: $test_name"
        return 0
    else
        echo "FAIL: $test_name"
        return 1
    fi
}

# Initialize the harness
test_harness_init

# Export variables for use by individual test files
export TEST_TMPDIR PROJECT_ROOT

echo "Test harness initialized in $TEST_TMPDIR"