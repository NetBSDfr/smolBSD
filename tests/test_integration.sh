#!/bin/sh
# Integration tests for smolBSD image building functionality

# Source the test framework utilities
if [ -z "$PROJECT_ROOT" ]; then
    echo "PROJECT_ROOT not set, setting it to parent directory"
    PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
    export PROJECT_ROOT
fi

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'smolbsd-integration-test')
if [ ! -d "$TEST_DIR" ]; then
    echo "Failed to create temporary directory" >&2
    exit 1
fi

# Clean up on exit and signals
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT INT TERM QUIT

# Test that required tools are available
test_dependencies() {
    echo "Testing required dependencies..."
    
    local missing_deps=0
    local optional_deps_msg=""
    
    # Check essential build tools
    for cmd in make tar curl dd; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ $cmd not found"
            ((missing_deps++))
        else
            echo "✓ $cmd is available"
        fi
    done
    
    # Check for QEMU (optional for basic tests but required for full functionality)
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "✓ qemu-system-x86_64 is available"
    else
        optional_deps_msg="$optional_deps_msg qemu-system-x86_64 (for VM execution)"
    fi
    
    if command -v qemu-system-aarch64 >/dev/null 2>&1; then
        echo "✓ qemu-system-aarch64 is available"
    else
        optional_deps_msg="$optional_deps_msg qemu-system-aarch64 (for ARM VM execution)"
    fi
    
    if [ -n "$optional_deps_msg" ]; then
        echo "ℹ️  Optional dependencies not found:$optional_deps_msg"
        echo "   To install on Ubuntu: sudo apt install qemu-system-x86 qemu-system-arm qemu-utils"
    fi
    
    if [ $missing_deps -eq 0 ]; then
        echo "✓ All required dependencies are available"
        return 0
    else
        echo "❌ $missing_deps required dependencies missing"
        echo "   Required packages for Ubuntu: make tar curl"
        return 1
    fi
}

# Test Makefile targets
test_makefile_targets() {
    echo "Testing Makefile targets..."
    
    if [ ! -f "$PROJECT_ROOT/Makefile" ]; then
        echo "❌ Makefile not found"
        return 1
    fi
    
    # Extract known targets from Makefile
    if grep -q "rescue:" "$PROJECT_ROOT/Makefile" && \
       grep -q "base:" "$PROJECT_ROOT/Makefile" && \
       grep -q "kernfetch:" "$PROJECT_ROOT/Makefile"; then
        echo "✓ Known Makefile targets exist"
        return 0
    else
        echo "❌ Known Makefile targets not found"
        return 1
    fi
}

# Test service directory structure
test_service_structure() {
    echo "Testing service directory structure..."
    
    if [ ! -d "$PROJECT_ROOT/service" ]; then
        echo "❌ service directory not found"
        return 1
    fi
    
    # Check for required service directories
    if [ ! -d "$PROJECT_ROOT/service/rescue" ] || [ ! -d "$PROJECT_ROOT/service/common" ]; then
        echo "❌ Required service directories not found"
        return 1
    fi
    
    # Check for rescue service configuration
    if [ ! -f "$PROJECT_ROOT/service/rescue/etc/rc" ] && [ ! -d "$PROJECT_ROOT/service/rescue/etc" ]; then
        echo "⚠️  rescue service configuration not found (this might be OK)"
    else
        echo "✓ Service directory structure looks correct"
    fi
    
    return 0
}

# Test that basic rescue image can be configured
test_rescue_image_config() {
    echo "Testing rescue image configuration..."
    
    # Check if rescue service directory exists
    if [ -d "$PROJECT_ROOT/service/rescue" ]; then
        echo "✓ rescue service directory exists"
    else
        echo "❌ rescue service directory does not exist"
        return 1
    fi
    
    # Check for common elements
    if [ -d "$PROJECT_ROOT/service/common" ]; then
        echo "✓ common service directory exists"
    else
        echo "❌ common service directory does not exist"
        return 1
    fi
    
    return 0
}

# Main test function
run_integration_tests() {
    echo "Running smolBSD integration tests..."
    
    local failed_tests=0
    
    if ! test_dependencies; then
        ((failed_tests++))
    fi
    
    if ! test_makefile_targets; then
        ((failed_tests++))
    fi
    
    if ! test_service_structure; then
        ((failed_tests++))
    fi
    
    if ! test_rescue_image_config; then
        ((failed_tests++))
    fi
    
    if [ $failed_tests -eq 0 ]; then
        echo "✓ All integration tests passed"
        return 0
    else
        echo "❌ $failed_tests integration tests failed"
        return 1
    fi
}

# Run the tests
run_integration_tests