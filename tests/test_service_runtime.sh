#!/bin/sh
#
# Service runtime tests for smolBSD
# Tests service behavior during execution simulation
#

# Source the test harness first (if not already sourced)
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Define run_test function if not available (fallback for direct execution)
if ! command -v run_test >/dev/null 2>&1; then
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
fi

# Test service runtime environment preparation
test_runtime_environment() {
    # Create a test environment to simulate service runtime
    local runtime_test_dir="$TEST_TMPDIR/runtime_test"
    mkdir -p "$runtime_test_dir"/{etc,bin,sbin,usr/bin,usr/sbin,tmp,dev,proc,sys}
    
    # Copy common service components to test environment
    local common_src="$PROJECT_ROOT/service/common"
    if [ -d "$common_src" ]; then
        mkdir -p "$runtime_test_dir/etc/include"
        cp -f "$common_src/basicrc" "$runtime_test_dir/etc/include/basicrc" 2>/dev/null || true
        cp -f "$common_src/shutdown" "$runtime_test_dir/etc/include/shutdown" 2>/dev/null || true
    fi
    
    # Verify the runtime environment was created properly
    if [ -f "$runtime_test_dir/etc/include/basicrc" ]; then
        echo "PASS: Runtime environment basicrc available"
    else
        echo "WARN: Runtime environment basicrc not available for testing"
    fi
    
    if [ -d "$runtime_test_dir/etc" ]; then
        echo "PASS: Runtime environment etc directory exists"
    else
        echo "FAIL: Runtime environment etc directory missing"
        return 1
    fi
    
    return 0
}

# Test that service rc scripts can be parsed without errors
test_service_rc_execution() {
    local services_dir="$PROJECT_ROOT/service"
    local failed_rc=0
    
    # Test that each service's rc file can be sourced in a minimal environment
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Create a minimal environment and try to parse the rc script
                local test_env_dir="$TEST_TMPDIR/rc_test_env_$service_name"
                mkdir -p "$test_env_dir"/{etc,bin,sbin,tmp}
                
                # Copy the rc file to test environment
                cp "$rc_file" "$test_env_dir/rc_test" 2>/dev/null || continue
                
                # Try to read the content and check for obvious errors
                if grep -q "^\s*cd\s*/root" "$test_env_dir/rc_test" 2>/dev/null || \
                   grep -q "^\s*rm\s*-rf\s*/" "$test_env_dir/rc_test" 2>/dev/null || \
                   grep -q "^\s*chmod\s*0000\s*/" "$test_env_dir/rc_test" 2>/dev/null; then
                    echo "FAIL: Service $service_name rc contains potentially dangerous commands"
                    failed_rc=$((failed_rc + 1))
                else
                    echo "PASS: Service $service_name rc does not contain obviously dangerous commands"
                fi
                
                # Check for proper environment variable usage
                if grep -q "HOME=" "$rc_file" || grep -q "PATH=" "$rc_file"; then
                    echo "PASS: Service $service_name rc sets environment variables"
                else
                    echo "INFO: Service $service_name rc may not set environment variables"
                fi
            fi
        fi
    done
    
    if [ $failed_rc -eq 0 ]; then
        echo "PASS: All service rc files passed basic safety checks"
        return 0
    else
        echo "FAIL: $failed_rc service rc files had potential issues"
        return 1
    fi
}

# Test service postinst script safety
test_postinst_safety() {
    local services_dir="$PROJECT_ROOT/service"
    local unsafe_scripts=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        # Check for potentially unsafe operations in postinst scripts
                        # These run during image building and should not have dangerous operations
                        if grep -q "rm\s*-rf\s*/" "$script" || \
                           grep -q "rm\s*-rf\s*\$.*ROOT" "$script" || \
                           grep -q ">/dev/null.*rm\s*-rf" "$script"; then
                            echo "FAIL: Postinst script $script for service $service_name contains dangerous operations"
                            unsafe_scripts=$((unsafe_scripts + 1))
                        elif grep -q "chown\s*-R.*0:0\s*/\." "$script" || grep -q "chmod\s*-R.*777\s*/\." "$script"; then
                            echo "WARN: Postinst script $script for service $service_name has broad permission changes"
                        else
                            echo "PASS: Postinst script $script for service $service_name appears safe"
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $unsafe_scripts -eq 0 ]; then
        echo "PASS: No unsafe postinst operations found"
        return 0
    else
        echo "FAIL: $unsafe_scripts unsafe postinst operations found"
        return 1
    fi
}

# Test service dependency checking
test_service_dependencies() {
    local services_dir="$PROJECT_ROOT/service"
    local missing_deps=0
    
    # Check if specific services have expected dependencies in their rc files
    for service_name in sshd bozohttpd; do
        local service_dir="$services_dir/$service_name"
        
        if [ -d "$service_dir" ]; then
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # SSHD service should typically involve ssh commands
                if [ "$service_name" = "sshd" ]; then
                    if grep -q "sshd\|ssh" "$rc_file"; then
                        echo "PASS: SSHD service contains SSH-related commands"
                    else
                        echo "WARN: SSHD service may be missing SSH-related commands"
                    fi
                fi
                
                # Bozohttpd service should involve web server commands
                if [ "$service_name" = "bozohttpd" ]; then
                    if grep -q "bozohttpd\|http" "$rc_file"; then
                        echo "PASS: BozoHTTPD service contains web server commands"
                    else
                        echo "WARN: BozoHTTPD service may be missing web server commands"
                    fi
                fi
            fi
        fi
    done
    
    return 0  # Don't fail for missing dependencies, just report
}

# Test service startup simulation (without actually starting services)
test_service_startup_simulation() {
    # This test simulates the service startup process without actually running it
    local runtime_test_dir="$TEST_TMPDIR/runtime_simulation"
    mkdir -p "$runtime_test_dir"
    
    # Create temporary rc files that simulate what would happen during startup
    # For this test, just validate that essential service components are available
    
    local services_dir="$PROJECT_ROOT/service"
    local tested_services=0
    
    for service_name in rescue sshd bozohttpd; do
        local service_dir="$services_dir/$service_name"
        
        if [ -d "$service_dir" ]; then
            # Simulate mounting and basic startup checks
            if [ -f "$service_dir/etc/rc" ]; then
                # Extract and validate common operations in rc files
                if grep -q "mount.*-a" "$service_dir/etc/rc"; then
                    echo "PASS: Service $service_name rc performs filesystem mount"
                fi
                
                if grep -q "ifconfig\|route" "$service_dir/etc/rc"; then
                    echo "PASS: Service $service_name rc configures network"
                fi
                
                tested_services=$((tested_services + 1))
            fi
        fi
    done
    
    if [ $tested_services -gt 0 ]; then
        echo "PASS: Simulated startup for $tested_services services"
        return 0
    else
        echo "FAIL: No services available for startup simulation"
        return 1
    fi
}

# Run all service runtime tests
run_all_service_runtime_tests() {
    echo "Running service runtime tests..."
    
    local failed_tests=0
    
    run_test "Runtime environment preparation test" test_runtime_environment || failed_tests=$((failed_tests + 1))
    run_test "Service rc execution safety test" test_service_rc_execution || failed_tests=$((failed_tests + 1))
    run_test "Postinst script safety test" test_postinst_safety || failed_tests=$((failed_tests + 1))
    run_test "Service dependency validation test" test_service_dependencies || failed_tests=$((failed_tests + 1))
    run_test "Service startup simulation test" test_service_startup_simulation || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All service runtime tests passed"
        return 0
    else
        echo "$failed_tests service runtime tests failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_service_runtime_tests
fi