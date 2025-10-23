#!/bin/sh
# Unit tests for mkimg.sh script

# Source the test framework utilities
if [ -z "$PROJECT_ROOT" ]; then
    echo "PROJECT_ROOT not set, setting it to project root"
    PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
    export PROJECT_ROOT
fi

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'smolbsd-test')
if [ ! -d "$TEST_DIR" ]; then
    echo "Failed to create temporary directory" >&2
    exit 1
fi

TEST_MNT_DIR="$TEST_DIR/mnt"
mkdir -p "$TEST_MNT_DIR"

# Clean up on exit and signals
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT INT TERM QUIT

# Test basic script functionality
test_mkimg_syntax() {
    echo "Testing mkimg.sh syntax..."
    sh -n "$PROJECT_ROOT/mkimg.sh" || return 1
    echo "✓ mkimg.sh syntax is valid"
    return 0
}

test_mkimg_help() {
    echo "Testing mkimg.sh help output..."
    # The mkimg.sh script returns exit code 1 for help, which is expected
    output=$("$PROJECT_ROOT/mkimg.sh" -h 2>&1) || true  # Don't fail on non-zero exit code
    if echo "$output" | grep -q "Usage:"; then
        echo "✓ mkimg.sh help output is correct"
        return 0
    else
        echo "❌ Usage: text not found in output"
        echo "Output: $output"
        return 1
    fi
}

# Test that mkimg.sh has expected functions
test_script_functions() {
    echo "Testing that mkimg.sh has expected functions..."
    
    # Check if the rsynclite function exists in the script
    if grep -q "^rsynclite()" "$PROJECT_ROOT/mkimg.sh"; then
        echo "✓ mkimg.sh contains rsynclite function"
    else
        echo "❌ mkimg.sh missing rsynclite function"
        return 1
    fi
    
    # Check if the usage function exists
    if grep -q "^usage()" "$PROJECT_ROOT/mkimg.sh"; then
        echo "✓ mkimg.sh contains usage function"
    else
        echo "❌ mkimg.sh missing usage function"
        return 1
    fi
    
    echo "✓ mkimg.sh function definitions are present"
    return 0
}

# Main test function
run_mkimg_tests() {
    echo "Running mkimg.sh unit tests..."
    
    if test_mkimg_syntax && test_mkimg_help && test_script_functions; then
        echo "✓ All mkimg.sh unit tests passed"
        return 0
    else
        echo "❌ Some mkimg.sh unit tests failed"
        return 1
    fi
}

# Run the tests
run_mkimg_tests