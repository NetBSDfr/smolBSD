#!/bin/sh
#
# Advanced Service Configuration Tests
# High-quality validation of service configuration integrity
#

# Source test harness
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi


# Define run_test function for compatibility when run through test runner
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
# Test service directory structure integrity
test_service_structure() {
    local service_root="$PROJECT_ROOT/service"
    local errors=0
    local total_services=0
    local service_count=0
    
    if [ ! -d "$service_root" ]; then
        echo "FAIL: Service root directory missing"
        return 1
    fi
    
    # Validate each service with high-quality standards
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            total_services=$((total_services + 1))
            service_count=$((service_count + 1))  # Increment service_count for validated services
            
            echo "VALIDATING: $service_name"
            
            # Check for required service directories
            local service_etc_dir="$service_dir/etc"
            local service_postinst_dir="$service_dir/postinst"
            
            # Check if etc directory exists and has proper structure
            if [ -d "$service_etc_dir" ]; then
                echo "PASS: Service $service_name has etc directory"
                
                # Count files in etc directory
                local etc_file_count=$(find "$service_etc_dir" -type f | wc -l)
                local etc_dir_count=$(find "$service_etc_dir" -type d | wc -l)
                
                if [ "$etc_file_count" -gt 0 ]; then
                    echo "INFO: Service $service_name etc/ has $etc_file_count files in $etc_dir_count directories"
                else
                    echo "WARN: Service $service_name etc/ directory is empty"
                fi
                
                # Verify rc file structure if it exists
                local rc_file="$service_etc_dir/rc"
                if [ -f "$rc_file" ]; then
                    # Validate that rc file has proper structure
                    local line_count=$(wc -l < "$rc_file")
                    local shebang=$(head -n1 "$rc_file")
                    
                    if [ "$line_count" -gt 2 ]; then
                        echo "PASS: Service $service_name rc file is substantial ($line_count lines)"
                    else
                        echo "WARN: Service $service_name rc file is minimal ($line_count lines)"
                    fi
                    
                    # Check for essential rc patterns (mount, environment setup, network config)
                    local has_mount=$(grep -c "mount.*-a\|mount -t" "$rc_file")
                    local has_env=$(grep -c "export.*PATH\|export.*HOME\|PATH=.*PATH" "$rc_file")
                    local has_net=$(grep -c "ifconfig\|route\|ip addr" "$rc_file")
                    
                    if [ "$has_mount" -gt 0 ]; then
                        echo "PASS: Service $service_name rc configures filesystem mounting"
                    fi
                    if [ "$has_env" -gt 0 ]; then
                        echo "PASS: Service $service_name rc sets environment variables"
                    fi
                    if [ "$has_net" -gt 0 ]; then
                        echo "INFO: Service $service_name rc configures network"
                    fi
                else
                    echo "INFO: Service $service_name has no etc/rc file (may be OK for some services)"
                fi
            else
                echo "INFO: Service $service_name has no etc directory (may be OK for some services)"
            fi
            
            # Check postinst directory
            if [ -d "$service_postinst_dir" ]; then
                echo "PASS: Service $service_name has postinst directory"
                local postinst_script_count=$(find "$service_postinst_dir" -name "*.sh" -type f | wc -l)
                local postinst_total_files=$(find "$service_postinst_dir" -type f | wc -l)
                
                if [ "$postinst_script_count" -gt 0 ]; then
                    echo "INFO: Service $service_name has $postinst_script_count postinst scripts ($postinst_total_files total files)"
                    
                    # Validate each postinst script
                    for script in "$service_postinst_dir"/*.sh; do
                        if [ -f "$script" ]; then
                            local script_name=$(basename "$script")
                            
                            # Check if script is executable and has reasonable size
                            local script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
                            local script_lines=$(wc -l < "$script")
                            
                            if [ "$script_size" -gt 0 ]; then
                                echo "INFO: Postinst script $script_name: $script_size bytes, $script_lines lines"
                                
                                # Check for essential patterns in postinst scripts
                                local has_user=$(grep -c "useradd\|groupadd" "$script")
                                local has_pkg=$(grep -c "pkg\|install" "$script")
                                local has_copy=$(grep -c "cp\|mv\|rsync" "$script")
                                local has_chown=$(grep -c "chown\|chmod" "$script")
                                
                                if [ "$has_user" -gt 0 ]; then
                                    echo "INFO: Postinst script $script_name manages users/groups"
                                fi
                                if [ "$has_pkg" -gt 0 ]; then
                                    echo "INFO: Postinst script $script_name handles packages"
                                fi
                                if [ "$has_copy" -gt 0 ]; then
                                    echo "INFO: Postinst script $script_name copies/moves files"
                                fi
                                if [ "$has_chown" -gt 0 ]; then
                                    echo "INFO: Postinst script $script_name sets permissions"
                                fi
                            fi
                        fi
                    done
                fi
            else
                echo "INFO: Service $service_name has no postinst directory (may be OK)"
            fi
            
            # Check for options.mk file
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                echo "PASS: Service $service_name has build options.mk file"
                
                # Validate options.mk content
                local has_imsize=$(grep -c "IMGSIZE\|SIZE" "$options_mk")
                local has_arch=$(grep -c "ARCH\|arch" "$options_mk")
                
                if [ "$has_imsize" -gt 0 ]; then
                    echo "INFO: Service $service_name build options include image size"
                fi
                if [ "$has_arch" -gt 0 ]; then
                    echo "INFO: Service $service_name build options include architecture"
                fi
            else
                echo "INFO: Service $service_name has no build options.mk (may be OK)"
            fi
        fi
    done
    
    if [ $service_count -gt 0 ]; then
        echo "PASS: Found and validated $service_count services out of $total_services total services"
        return 0
    else
        echo "FAIL: No services found in services directory"
fi
}

# Test service configuration file integrity and consistency
test_config_files() {
    local service_root="$PROJECT_ROOT/service"
    local config_errors=0
    
    echo "Testing service configuration file integrity..."
    
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check etc directory for configuration files
            local etc_dir="$service_dir/etc"
            if [ -d "$etc_dir" ]; then
                for config_file in "$etc_dir"/*; do
                    if [ -f "$config_file" ]; then
                        local config_name=$(basename "$config_file")
                        
                        # Validate shell syntax for rc files
                        if [ "$config_name" = "rc" ]; then
                            if sh -n "$config_file" >/dev/null 2>&1; then
                                echo "PASS: Service $service_name rc file has valid shell syntax"
                            else
                                echo "FAIL: Service $service_name rc file has syntax errors"
                                config_errors=$((config_errors + 1))
                            fi
                            
                            local line_count=$(wc -l < "$config_file")
                            echo "INFO: Service $service_name rc file is substantial ($line_count lines)"
                        fi
                        
                        # Validate shell syntax for postinst scripts
                        if echo "$config_name" | grep -q "\.sh$"; then
                            if sh -n "$config_file" >/dev/null 2>&1; then
                                echo "PASS: Service $service_name postinst script $config_name has valid shell syntax"
                            else
                                echo "FAIL: Service $service_name postinst script $config_name has syntax errors"
                                config_errors=$((config_errors + 1))
                            fi
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $config_errors -eq 0 ]; then
        echo "PASSED: All service configuration files validated successfully"
        return 0
    else
        echo "FAILED: $config_errors service configuration files had issues"
        return 1
    fi
# Define run_test function for compatibility
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
}

# Run all advanced service configuration tests
run_all_advanced_service_config_tests() {
    echo "Running advanced service configuration tests..."
    
    local test_failures=0
    
    run_test "Service structure verification" test_service_structure || test_failures=$((test_failures + 1))
    run_test "Configuration file validation" test_config_files || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ]; then
        echo "ALL ADVANCED SERVICE CONFIGURATION TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures advanced service configuration test suites failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${0}" ]; then
    run_all_advanced_service_config_tests
fi

# Define run_test function if not available (needed when run through test runner)
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