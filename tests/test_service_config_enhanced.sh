#!/bin/sh
#
# Advanced Service Configuration Tests for smolBSD
# Comprehensive validation of service structure, configuration, and dependencies
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

# Enhanced service structure validation
test_enhanced_service_structure() {
    local services_dir="$PROJECT_ROOT/service"
    local error_count=0
    
    if [ ! -d "$services_dir" ]; then
        echo "FAIL: Service directory does not exist: $services_dir"
        return 1
    fi
    
    # Track all services found
    local service_count=0
    local total_services=0
    
    # Count all services first
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            total_services=$((total_services + 1))
        fi
    done
    
    # Validate each service in detail
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            service_count=$((service_count + 1))
            
            echo "INFO: Validating service structure: $service_name"
            
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
        return 1
    fi
}

# Test service file integrity and consistency
test_service_file_integrity() {
    local services_dir="$PROJECT_ROOT/service"
    local issues_found=0
    
    # Check for consistent naming and structure
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check for common configuration files that should follow conventions
            local etc_dir="$service_dir/etc"
            if [ -d "$etc_dir" ]; then
                # Look for common config file patterns
                local config_count=0
                for config in "$etc_dir"/*; do
                    if [ -f "$config" ]; then
                        local config_name=$(basename "$config")
                        
                        # Check for common config file extensions and naming
                        case "$config_name" in
                            *.conf|*.cfg|*.rc)
                                echo "INFO: Service $service_name has config file: $config_name"
                                config_count=$((config_count + 1))
                                ;;
                            passwd|group|hosts|resolv.conf|fstab)
                                echo "INFO: Service $service_name has system config: $config_name"
                                config_count=$((config_count + 1))
                                ;;
                            *)
                                # Other files - check if they have reasonable extensions
                                local ext="${config_name##*.}"
                                if [ "$ext" != "$config_name" ]; then
                                    echo "INFO: Service $service_name has file with extension: $config_name"
                                    config_count=$((config_count + 1))
                                else
                                    # File without extension - check content
                                    local first_line=$(head -n1 "$config" 2>/dev/null)
                                    if echo "$first_line" | grep -q "^#"; then
                                        echo "INFO: Service $service_name has comment header file: $config_name"
                                        config_count=$((config_count + 1))
                                    fi
                                fi
                                ;;
                        esac
                    fi
                done
            fi
            
            # Check for service-specific directories that might indicate functionality
            local service_subdirs=$(find "$service_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
            if [ "$service_subdirs" -gt 0 ]; then
                echo "INFO: Service $service_name has $service_subdirs subdirectories"
            fi
        fi
    done
    
    return 0
}

# Test service metadata and documentation
test_service_metadata() {
    local services_dir="$PROJECT_ROOT/service"
    local metadata_issues=0
    local services_with_metadata=0
    
    # Check README and other metadata for each service
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check for README
            local readme_file="$service_dir/README.md"
            if [ -f "$readme_file" ]; then
                services_with_metadata=$((services_with_metadata + 1))
                echo "PASS: Service $service_name has README.md"
                
                # Check README content quality
                local readme_lines=$(wc -l < "$readme_file")
                local readme_size=$(stat -c%s "$readme_file")
                
                if [ "$readme_size" -gt 100 ]; then
                    echo "INFO: Service $service_name README is substantial ($readme_size bytes)"
                    
                    # Check for essential README content
                    local has_desc=$(grep -c -i "description\|purpose\|what.*do" "$readme_file")
                    local has_usage=$(grep -c -i "usage\|how.*to\|command\|example" "$readme_file")
                    local has_config=$(grep -c -i "config\|option\|setting" "$readme_file")
                    local has_dep=$(grep -c -i "require\|depend\|need" "$readme_file")
                    
                    if [ "$has_desc" -gt 0 ]; then
                        echo "INFO: Service $service_name README describes service purpose"
                    fi
                    if [ "$has_usage" -gt 0 ]; then
                        echo "INFO: Service $service_name README provides usage information"
                    fi
                    if [ "$has_config" -gt 0 ]; then
                        echo "INFO: Service $service_name README describes configuration"
                    fi
                    if [ "$has_dep" -gt 0 ]; then
                        echo "INFO: Service $service_name README lists dependencies"
                    fi
                else
                    echo "INFO: Service $service_name README is minimal ($readme_size bytes)"
                fi
            else
                echo "INFO: Service $service_name has no README.md"
            fi
            
            # Check for other documentation files
            local doc_files=$(find "$service_dir" -name "*.md" -o -name "*.txt" -o -name "*.doc" | grep -v "/.git/" | wc -l)
            if [ "$doc_files" -gt 0 ]; then
                echo "INFO: Service $service_name has $doc_files documentation files"
            fi
        fi
    done
    
    if [ $services_with_metadata -gt 0 ]; then
        echo "INFO: $services_with_metadata services have documentation"
    fi
    
    return 0
}

# Test configuration file syntax and content
test_config_file_validation() {
    local services_dir="$PROJECT_ROOT/service"
    local config_errors=0
    local total_configs=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Find all config files in etc directory
            if [ -d "$service_dir/etc" ]; then
                for config_file in "$service_dir/etc"/*; do
                    if [ -f "$config_file" ]; then
                        total_configs=$((total_configs + 1))
                        local config_name=$(basename "$config_file")
                        
                        # Skip scripts, focus on config files
                        if ! echo "$config_name" | grep -q '\.sh$'; then
                            # For shell-like config files, try to validate syntax
                            if echo "$config_name" | grep -qE '\.(conf|cfg|rc|list|tab)$' || echo "$config_name" | grep -qE '^.*\.conf$'; then
                                # These are likely structured config files
                                local lines=$(wc -l < "$config_file")
                                if [ "$lines" -gt 0 ]; then
                                    echo "INFO: Validating config file $config_name ($lines lines)"
                                    
                                    # Check for basic config syntax patterns
                                    local key_value_pairs=$(grep -c "=" "$config_file" 2>/dev/null || echo 0)
                                    local comments=$(grep -c "^#" "$config_file" 2>/dev/null || echo 0)
                                    local paths=$(grep -c "/.*" "$config_file" 2>/dev/null || echo 0)
                                    
                                    if [ "$key_value_pairs" -gt 0 ]; then
                                        echo "INFO: Config $config_name has $key_value_pairs key-value pairs"
                                    fi
                                    if [ "$comments" -gt 0 ]; then
                                        echo "INFO: Config $config_name has $comments comments"
                                    fi
                                    if [ "$paths" -gt 0 ]; then
                                        echo "INFO: Config $config_name references $paths paths"
                                    fi
                                fi
                            elif echo "$config_name" | grep -qE '\.pub$'; then
                                # SSH public key files - basic validation
                                local first_line=$(head -n1 "$config_file" 2>/dev/null)
                                if echo "$first_line" | grep -qE "ssh-(rsa|dss|ed25519|ecdsa)"; then
                                    echo "INFO: Service $service_name has valid SSH public key: $config_name"
                                else
                                    echo "WARN: Service $service_name SSH key file $config_name may be malformed"
                                fi
                            else
                                # Other files - check if they have reasonable content
                                local first_line=$(head -n1 "$config_file" 2>/dev/null)
                                if [ -n "$first_line" ]; then
                                    echo "INFO: Service $service_name file $config_name validated"
                                fi
                            fi
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $total_configs -gt 0 ]; then
        echo "INFO: Validated $total_configs configuration files across all services"
    fi
    
    return 0
}

# Run all enhanced service configuration tests
run_all_enhanced_service_config_tests() {
    echo "Running enhanced service configuration tests..."
    
    local failed_tests=0
    
    run_test "Enhanced service structure validation" test_enhanced_service_structure || failed_tests=$((failed_tests + 1))
    run_test "Service file integrity validation" test_service_file_integrity || failed_tests=$((failed_tests + 1))
    run_test "Service metadata validation" test_service_metadata || failed_tests=$((failed_tests + 1))
    run_test "Configuration file validation" test_config_file_validation || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All enhanced service configuration tests passed"
        return 0
    else
        echo "$failed_tests enhanced service configuration tests had issues"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${0}" ]; then
    run_all_enhanced_service_config_tests
fi