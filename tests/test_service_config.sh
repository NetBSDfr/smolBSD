#!/bin/sh
#
# Service configuration tests for smolBSD
# Validates service structure, configuration files, and service-specific logic
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

# Test that service directory structure is correct
test_service_structure() {
    local services_dir="$PROJECT_ROOT/service"
    
    if [ ! -d "$services_dir" ]; then
        echo "FAIL: Service directory does not exist: $services_dir"
        return 1
    fi
    
    # Check for required service components
    if [ ! -d "$services_dir/common" ]; then
        echo "FAIL: Common service directory missing"
        return 1
    fi
    
    # Get list of service directories (excluding common)
    local service_count=0
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            service_count=$((service_count + 1))
            
            local service_name=$(basename "$service_dir")
            
            # Each service should have an etc directory with rc file
            if [ -d "$service_dir/etc" ]; then
                if [ -f "$service_dir/etc/rc" ]; then
                    echo "PASS: Service $service_name has etc/rc file"
                else
                    echo "WARN: Service $service_name missing etc/rc file (may be OK for some services)"
                fi
            else
                echo "WARN: Service $service_name missing etc directory (may be OK for some services)"
            fi
            
            # Check for postinst directory
            if [ -d "$service_dir/postinst" ]; then
                echo "PASS: Service $service_name has postinst directory"
                # Check for .sh files in postinst
                local postinst_script_count=0
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        postinst_script_count=$((postinst_script_count + 1))
                        if [ -x "$script" ]; then
                            echo "PASS: Postinst script $script is executable"
                        else
                            # Some .sh files might be templates or non-executable config files
                            echo "INFO: Postinst script $script is not executable (may be OK for templates)"
                        fi
                    fi
                done
                if [ $postinst_script_count -eq 0 ]; then
                    echo "WARN: Service $service_name postinst directory is empty"
                fi
            fi
        fi
    done
    
    if [ $service_count -gt 0 ]; then
        echo "PASS: Found $service_count services in service directory"
        return 0
    else
        echo "FAIL: No services found in service directory"
        return 1
    fi
}

# Test structure of common service components
test_common_service() {
    local common_dir="$PROJECT_ROOT/service/common"
    
    if [ ! -d "$common_dir" ]; then
        echo "FAIL: Common service directory does not exist"
        return 1
    fi
    
    # Check for essential common files
    local essential_files="basicrc shutdown"
    local missing_files=""
    
    for file in $essential_files; do
        if [ -f "$common_dir/$file" ]; then
            echo "PASS: Common service has $file"
        else
            missing_files="$missing_files $file"
        fi
    done
    
    if [ -n "$missing_files" ]; then
        echo "FAIL: Common service missing essential files:$missing_files"
        return 1
    fi
    
    # Check if basicrc is executable
    if [ -x "$common_dir/basicrc" ]; then
        echo "PASS: Common basicrc is executable"
    else
        echo "FAIL: Common basicrc is not executable"
        return 1
    fi
    
    return 0
}

# Test individual service configurations
test_individual_service_configs() {
    local services_dir="$PROJECT_ROOT/service"
    local failed_services=0
    
    # Test specific known services
    for service_name in rescue sshd bozohttpd; do
        local service_dir="$services_dir/$service_name"
        
        if [ -d "$service_dir" ]; then
            echo "Testing service: $service_name"
            
            # Check for etc/rc file syntax
            if [ -f "$service_dir/etc/rc" ]; then
                if sh -n "$service_dir/etc/rc" 2>/dev/null; then
                    echo "PASS: Service $service_name etc/rc syntax is valid"
                else
                    echo "FAIL: Service $service_name etc/rc has syntax errors"
                    failed_services=$((failed_services + 1))
                fi
            fi
            
            # Check for postinst scripts syntax
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        if sh -n "$script" 2>/dev/null; then
                            echo "PASS: Service $service_name postinst script $script syntax is valid"
                        else
                            echo "FAIL: Service $service_name postinst script $script has syntax errors"
                            failed_services=$((failed_services + 1))
                        fi
                    fi
                done
            fi
        else
            echo "INFO: Service $service_name not found, skipping"
        fi
    done
    
    if [ $failed_services -eq 0 ]; then
        echo "PASS: All service configurations are syntactically correct"
        return 0
    else
        echo "FAIL: $failed_services service configurations have syntax errors"
        return 1
    fi
}

# Test service-specific validation rules
test_service_rules() {
    local services_dir="$PROJECT_ROOT/service"
    
    # Check for proper shebangs in service scripts
    local script_count=0
    for rc_file in "$services_dir"/*/*/rc; do
        if [ -f "$rc_file" ]; then
            script_count=$((script_count + 1))
            local first_line=$(head -n1 "$rc_file" 2>/dev/null)
            if echo "$first_line" | grep -q "^#!.*sh"; then
                echo "PASS: Service rc file $rc_file has proper shebang: $first_line"
            else
                echo "WARN: Service rc file $rc_file missing proper shebang (may be OK)"
            fi
        fi
    done
    
    # Check postinst scripts too
    for postinst_script in "$services_dir"/*/postinst/*.sh; do
        if [ -f "$postinst_script" ]; then
            script_count=$((script_count + 1))
            local first_line=$(head -n1 "$postinst_script" 2>/dev/null)
            if echo "$first_line" | grep -q "^#!.*sh"; then
                echo "PASS: Postinst script $postinst_script has proper shebang: $first_line"
            else
                echo "WARN: Postinst script $postinst_script missing proper shebang (may be OK)"
            fi
        fi
    done
    
    if [ $script_count -gt 0 ]; then
        echo "INFO: Checked shebangs for $script_count service scripts"
    fi
    
    return 0
}

# Run all service configuration tests
run_all_service_config_tests() {
    echo "Running service configuration tests..."
    
    local failed_tests=0
    
    run_test "Service directory structure test" test_service_structure || failed_tests=$((failed_tests + 1))
    run_test "Common service components test" test_common_service || failed_tests=$((failed_tests + 1))
    run_test "Individual service configurations test" test_individual_service_configs || failed_tests=$((failed_tests + 1))
    run_test "Service rules validation test" test_service_rules || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All service configuration tests passed"
        return 0
    else
        echo "$failed_tests service configuration tests failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_service_config_tests
fi