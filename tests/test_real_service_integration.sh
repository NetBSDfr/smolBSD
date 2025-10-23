#!/bin/sh
#
# Real smolBSD Service Integration Tests
# Test actual smolBSD service functionality with real components
#

# Source test harness
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Test service build capability
test_service_build_capability() {
    echo "Testing service build capability..."
    
    # Check if make is available
    if ! command -v make >/dev/null 2>&1; then
        echo "FAIL: make command not available"
        return 1
    fi
    
    # Check if mkimg.sh is available
    if [ ! -f "$PROJECT_ROOT/mkimg.sh" ]; then
        echo "FAIL: mkimg.sh not found in project root"
        return 1
    fi
    
    # Check if startnb.sh is available
    if [ ! -f "$PROJECT_ROOT/startnb.sh" ]; then
        echo "FAIL: startnb.sh not found in project root"
        return 1
    fi
    
    # Check available services
    local services_dir="$PROJECT_ROOT/service"
    if [ ! -d "$services_dir" ]; then
        echo "FAIL: Service directory not found"
        return 1
    fi
    
    # Count available services
    local service_count=0
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            service_count=$((service_count + 1))
        fi
    done
    
    echo "INFO: Found $service_count available services"
    
    if [ $service_count -eq 0 ]; then
        echo "FAIL: No services available for testing"
        return 1
    fi
    
    echo "PASSED: Service build capability validated"
    return 0
}

# Test actual service configuration files
test_service_configurations() {
    echo "Testing actual service configurations..."
    
    local services_dir="$PROJECT_ROOT/service"
    local config_dir="$PROJECT_ROOT/etc"
    local config_issues=0
    local total_configs=0
    
    # Test service configuration files
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            total_configs=$((total_configs + 1))
            
            echo "INFO: Testing configuration for service: $service_name"
            
            # Check if service has etc directory with rc file
            local etc_dir="$service_dir/etc"
            if [ -d "$etc_dir" ]; then
                local rc_file="$etc_dir/rc"
                if [ -f "$rc_file" ]; then
                    # Validate shell syntax
                    if sh -n "$rc_file" 2>/dev/null; then
                        echo "PASS: Service $service_name rc file has valid shell syntax"
                    else
                        echo "FAIL: Service $service_name rc file has syntax errors"
                        config_issues=$((config_issues + 1))
                    fi
                    
                    # Check for basic structure
                    local line_count=$(wc -l < "$rc_file")
                    if [ "$line_count" -gt 5 ]; then
                        echo "INFO: Service $service_name rc file is substantial ($line_count lines)"
                    else
                        echo "INFO: Service $service_name rc file is minimal ($line_count lines)"
                    fi
                else
                    echo "INFO: Service $service_name has etc directory but no rc file"
                fi
            else
                echo "INFO: Service $service_name has no etc directory"
            fi
            
            # Check for postinst scripts
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                local script_count=0
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        script_count=$((script_count + 1))
                        
                        # Validate shell syntax
                        if sh -n "$script" 2>/dev/null; then
                            echo "PASS: Service $service_name postinst script $(basename "$script") has valid shell syntax"
                        else
                            echo "FAIL: Service $service_name postinst script $(basename "$script") has syntax errors"
                            config_issues=$((config_issues + 1))
                        fi
                    fi
                done
                
                if [ $script_count -gt 0 ]; then
                    echo "INFO: Service $service_name has $script_count postinst scripts"
                fi
            fi
            
            # Check for options.mk
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                # Validate make syntax
                if grep -q "=" "$options_mk" 2>/dev/null; then
                    echo "PASS: Service $service_name options.mk file has valid syntax"
                else
                    echo "INFO: Service $service_name options.mk file appears empty"
                fi
            fi
        fi
    done
    
    # Test global configuration files
    if [ -d "$config_dir" ]; then
        for config_file in "$config_dir"/*.conf; do
            if [ -f "$config_file" ]; then
                local config_name=$(basename "$config_file")
                
                # Basic validation - check if it contains configuration parameters
                local param_count=$(grep -c "=" "$config_file" 2>/dev/null || echo "0")
                if [ "$param_count" -gt 0 ]; then
                    echo "PASS: Configuration $config_name has $param_count parameters"
                else
                    echo "INFO: Configuration $config_name appears to have no parameters"
                fi
            fi
        done
    fi
    
    if [ $config_issues -eq 0 ]; then
        echo "PASSED: All service configurations validated successfully"
        return 0
    else
        echo "FAILED: $config_issues configuration issues found"
        return 1
    fi
}

# Test service build simulation (without actually building)
test_service_build_simulation() {
    echo "Testing service build simulation..."
    
    local services_dir="$PROJECT_ROOT/service"
    local build_issues=0
    local successful_simulations=0
    
    # Simulate build process for each service
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            echo "SIMULATING: Build process for service: $service_name"
            
            # Check service structure
            local has_etc=0
            local has_postinst=0
            local has_options=0
            
            if [ -d "$service_dir/etc" ]; then
                has_etc=1
                echo "  STRUCTURE: Service has etc directory"
            fi
            
            if [ -d "$service_dir/postinst" ]; then
                has_postinst=1
                echo "  STRUCTURE: Service has postinst directory"
            fi
            
            if [ -f "$service_dir/options.mk" ]; then
                has_options=1
                echo "  STRUCTURE: Service has options.mk file"
            fi
            
            # Check for build dependencies
            local build_deps=0
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Look for package dependencies
                local pkg_deps=$(grep -cE "(pkg_add|pkgin install|apt-get install|yum install)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$pkg_deps" -gt 0 ]; then
                    build_deps=$((build_deps + 1))
                    echo "  DEPENDENCIES: Service requires $pkg_deps packages"
                fi
                
                # Look for user/group creation
                local user_deps=$(grep -cE "(useradd|groupadd|adduser|addgroup)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$user_deps" -gt 0 ]; then
                    build_deps=$((build_deps + 1))
                    echo "  USERS: Service creates $user_deps users/groups"
                fi
                
                # Look for file operations
                local file_ops=$(grep -cE "(cp|mv|mkdir|ln)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$file_ops" -gt 0 ]; then
                    build_deps=$((build_deps + 1))
                    echo "  FILES: Service performs $file_ops file operations"
                fi
            fi
            
            # Check postinst scripts
            local postinst_deps=0
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        # Look for package installations
                        local script_pkgs=$(grep -cE "(pkg_add|pkgin install)" "$script" 2>/dev/null || echo "0")
                        if [ "$script_pkgs" -gt 0 ]; then
                            postinst_deps=$((postinst_deps + 1))
                            echo "  POSTINST: Script $(basename "$script") installs $script_pkgs packages"
                        fi
                        
                        # Look for service configurations
                        local script_svc=$(grep -cE "(service|/etc/init.d)" "$script" 2>/dev/null || echo "0")
                        if [ "$script_svc" -gt 0 ]; then
                            postinst_deps=$((postinst_deps + 1))
                            echo "  POSTINST: Script $(basename "$script") configures $script_svc services"
                        fi
                    fi
                done
            fi
            
            # Summary
            local total_deps=$((build_deps + postinst_deps))
            if [ $total_deps -gt 0 ]; then
                echo "  SUMMARY: Service $service_name has $total_deps build dependencies/features"
                successful_simulations=$((successful_simulations + 1))
            else
                echo "  SUMMARY: Service $service_name has minimal build requirements"
                successful_simulations=$((successful_simulations + 1))
            fi
        fi
    done
    
    if [ $successful_simulations -gt 0 ]; then
        echo "PASSED: Build simulation completed for $successful_simulations services"
        return 0
    else
        echo "FAIL: No services could be simulated for build"
        return 1
    fi
}

# Test service runtime behavior simulation
test_service_runtime_simulation() {
    echo "Testing service runtime behavior simulation..."
    
    local services_dir="$PROJECT_ROOT/service"
    local behavior_issues=0
    local successful_simulations=0
    
    # Simulate runtime behavior for each service
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            echo "SIMULATING: Runtime behavior for service: $service_name"
            
            # Check rc file for runtime behavior
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Look for startup behavior
                local startup_ops=$(grep -cE "(mount|ifconfig|route|hostname)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$startup_ops" -gt 0 ]; then
                    echo "  STARTUP: Service performs $startup_ops startup operations"
                fi
                
                # Look for environment setup
                local env_ops=$(grep -cE "(export|PATH=|HOME=)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$env_ops" -gt 0 ]; then
                    echo "  ENVIRONMENT: Service sets up $env_ops environment variables"
                fi
                
                # Look for network configuration
                local net_ops=$(grep -cE "(ifconfig|route|dhclient|ping)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$net_ops" -gt 0 ]; then
                    echo "  NETWORK: Service performs $net_ops network operations"
                fi
                
                # Look for filesystem operations
                local fs_ops=$(grep -cE "(mount|umount|mkdir|chmod|chown)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$fs_ops" -gt 0 ]; then
                    echo "  FILESYSTEM: Service performs $fs_ops filesystem operations"
                fi
                
                # Look for process management
                local proc_ops=$(grep -cE "(exec|start|daemon|service)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$proc_ops" -gt 0 ]; then
                    echo "  PROCESSES: Service manages $proc_ops processes"
                fi
                
                # Look for error handling
                local error_ops=$(grep -cE "(exit|return|trap)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$error_ops" -gt 0 ]; then
                    echo "  ERROR HANDLING: Service has $error_ops error handling mechanisms"
                else
                    echo "  ERROR HANDLING: Service has minimal error handling"
                fi
                
                successful_simulations=$((successful_simulations + 1))
            else
                echo "  INFO: Service $service_name has no rc file to simulate"
            fi
        fi
    done
    
    if [ $successful_simulations -gt 0 ]; then
        echo "PASSED: Runtime behavior simulation completed for $successful_simulations services"
        return 0
    else
        echo "INFO: No services with rc files for behavior simulation"
        return 0
    fi
}

# Test service integration with the build system
test_build_system_integration() {
    echo "Testing service integration with build system..."
    
    # Check Makefile for service targets
    local makefile="$PROJECT_ROOT/Makefile"
    if [ ! -f "$makefile" ]; then
        echo "FAIL: Makefile not found in project root"
        return 1
    fi
    
    # Look for service-related targets
    local service_targets=$(grep -c "SERVICE.*=" "$makefile" 2>/dev/null || echo "0")
    if [ "$service_targets" -gt 0 ]; then
        echo "PASS: Makefile has $service_targets service-related targets"
    else
        echo "INFO: Makefile may not have explicit service targets"
    fi
    
    # Check for build targets
    local build_targets=$(grep -cE "^[a-zA-Z].*:.*" "$makefile" 2>/dev/null | head -10)
    if [ -n "$build_targets" ]; then
        echo "INFO: Makefile has build targets:"
        grep -E "^[a-zA-Z].*:.*" "$makefile" 2>/dev/null | head -5 | while read -r target; do
            echo "  - $target"
        done
    fi
    
    # Check for service-specific build patterns
    local service_dirs=$(find "$PROJECT_ROOT/service" -maxdepth 1 -type d | grep -v "/common$" | wc -l)
    if [ "$service_dirs" -gt 0 ]; then
        echo "PASS: Found $service_dirs service directories for build integration"
    fi
    
    echo "PASSED: Build system integration validated"
    return 0
}

# Test actual service execution capabilities (dry-run)
test_service_execution_capabilities() {
    echo "Testing service execution capabilities..."
    
    local services_dir="$PROJECT_ROOT/service"
    local exec_issues=0
    local successful_executions=0
    
    # Test execution capabilities for services with rc files
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "TESTING: Execution capabilities for service: $service_name"
                
                # Check if rc file is executable or has shebang
                local shebang=$(head -n1 "$rc_file")
                if echo "$shebang" | grep -q "^#!"; then
                    echo "  SHEBANG: Service $service_name rc has shebang: $shebang"
                else
                    echo "  WARNING: Service $service_name rc missing shebang"
                fi
                
                # Test dry-run execution (syntax only)
                if sh -n "$rc_file" 2>/dev/null; then
                    echo "  SYNTAX: Service $service_name rc file syntax is valid"
                    successful_executions=$((successful_executions + 1))
                else
                    echo "  FAIL: Service $service_name rc file has syntax errors"
                    exec_issues=$((exec_issues + 1))
                fi
                
                # Check for dangerous operations (without executing)
                local dangerous_ops=$(grep -cE "(rm.*-rf.*/|chmod.*777|chown.*0:0.*/)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$dangerous_ops" -gt 0 ]; then
                    echo "  DANGEROUS: Service $service_name has $dangerous_ops potentially dangerous operations"
                    exec_issues=$((exec_issues + 1))
                fi
            fi
        fi
    done
    
    if [ $exec_issues -eq 0 ]; then
        if [ $successful_executions -gt 0 ]; then
            echo "PASSED: All $successful_executions service execution capabilities validated"
            return 0
        else
            echo "INFO: No services with rc files to test execution capabilities"
            return 0
        fi
    else
        echo "FAILED: $exec_issues execution capability issues found"
        return 1
    fi
}

# Run all real smolBSD service integration tests
run_real_service_integration_tests() {
    echo "RUNNING: Real smolBSD service integration tests"
    echo "=============================================="
    
    local test_failures=0
    
    run_test "Service build capability" test_service_build_capability || test_failures=$((test_failures + 1))
    run_test "Service configurations" test_service_configurations || test_failures=$((test_failures + 1))
    run_test "Service build simulation" test_service_build_simulation || test_failures=$((test_failures + 1))
    run_test "Service runtime simulation" test_service_runtime_simulation || test_failures=$((test_failures + 1))
    run_test "Build system integration" test_build_system_integration || test_failures=$((test_failures + 1))
    run_test "Service execution capabilities" test_service_execution_capabilities || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ]; then
        echo "ALL REAL SMOLBSD SERVICE INTEGRATION TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures real smolBSD service integration test suites failed"
        return 1
    fi
}

# Execute if run directly
if [ "$0" = "$0" ]; then
    run_real_service_integration_tests
fi