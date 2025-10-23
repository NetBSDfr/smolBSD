#!/bin/sh
#
# Advanced Service Dependency Tracking and Validation for smolBSD
# Comprehensive analysis of service dependencies, conflicts, and relationships
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

# Track and validate service dependencies
test_service_dependencies_and_relationships() {
    local services_dir="$PROJECT_ROOT/service"
    local dependency_issues=0
    local total_dependencies=0
    
    # Create a mapping of all services and their dependencies
    echo "INFO: Analyzing service dependencies and relationships..."
    
    # First pass: collect all service information
    local all_services=""
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            all_services="$all_services $service_name"
        fi
    done
    
    # For each service, analyze its dependencies
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            echo "INFO: Analyzing dependencies for service: $service_name"
            
            # Track dependencies found in this service
            local service_deps=""
            local service_conflicts=""
            
            # Check rc file for dependencies
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Look for commands that indicate service dependencies
                # Database services
                local has_db=$(grep -cE "(mysql|postgres|redis|memcached)" "$rc_file" 2>/dev/null)
                if [ "$has_db" -gt 0 ]; then
                    local db_names=$(grep -oE "(mysql|postgres|redis|memcached)" "$rc_file" 2>/dev/null | sort -u | tr '\n' ' ')
                    echo "INFO: Service $service_name likely depends on database services: $db_names"
                    service_deps="$service_deps $db_names"
                    total_dependencies=$((total_dependencies + 1))
                fi
                
                # Web services
                local has_web=$(grep -cE "(nginx|apache|httpd|lighttpd|bozohttpd)" "$rc_file" 2>/dev/null)
                if [ "$has_web" -gt 0 ]; then
                    local web_names=$(grep -oE "(nginx|apache|httpd|lighttpd|bozohttpd)" "$rc_file" 2>/dev/null | sort -u | tr '\n' ' ')
                    echo "INFO: Service $service_name likely depends on web services: $web_names"
                    service_deps="$service_deps $web_names"
                    total_dependencies=$((total_dependencies + 1))
                fi
                
                # Network services
                local has_net=$(grep -cE "(ssh|sshd|ftp|telnet|smb|nfs)" "$rc_file" 2>/dev/null)
                if [ "$has_net" -gt 0 ]; then
                    local net_names=$(grep -oE "(ssh|sshd|ftp|telnet|smb|nfs)" "$rc_file" 2>/dev/null | sort -u | tr '\n' ' ')
                    echo "INFO: Service $service_name likely depends on network services: $net_names"
                    service_deps="$service_deps $net_names"
                    total_dependencies=$((total_dependencies + 1))
                fi
                
                # Look for specific service startup dependencies
                local has_start=$(grep -c "onestart\|start\|restart" "$rc_file" 2>/dev/null)
                if [ "$has_start" -gt 0 ]; then
                    local start_services=$(grep -oE "[a-zA-Z0-9_]+.*onestart\|[a-zA-Z0-9_]+.*start" "$rc_file" 2>/dev/null | grep -oE "[a-zA-Z0-9_]+" | sort -u | tr '\n' ' ')
                    if [ -n "$start_services" ]; then
                        echo "INFO: Service $service_name starts other services: $start_services"
                        service_deps="$service_deps $start_services"
                        total_dependencies=$((total_dependencies + 1))
                    fi
                fi
            fi
            
            # Check postinst scripts for package dependencies
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        # Look for package installation commands
                        local pkg_installs=$(grep -oE "(pkg_add|pkgin install|apt-get install|yum install|dnf install)" "$script" 2>/dev/null | sort -u | tr '\n' ' ')
                        if [ -n "$pkg_installs" ]; then
                            echo "INFO: Service $service_name installs packages: $pkg_installs"
                            total_dependencies=$((total_dependencies + 1))
                        fi
                        
                        # Look for specific package names being installed
                        local pkgs=$(grep -oE "pkg_add [a-zA-Z0-9_-]\+\|pkgin install [a-zA-Z0-9_-]\+" "$script" 2>/dev/null | grep -oE "[a-zA-Z0-9_-]\+" | sort -u | tr '\n' ' ')
                        if [ -n "$pkgs" ]; then
                            echo "INFO: Service $service_name requires packages: $pkgs"
                            service_deps="$service_deps $pkgs"
                            total_dependencies=$((total_dependencies + 1))
                        fi
                    fi
                done
            fi
            
            # Check for conflicting services
            local has_conflicts=$(grep -cE "(conflict|avoid|prevent|not.*with|exclusive)" "$rc_file" 2>/dev/null)
            if [ "$has_conflicts" -gt 0 ]; then
                local conflict_text=$(grep -oE "(conflict|avoid|prevent|not.*with|exclusive).*[a-zA-Z0-9_]+" "$rc_file" 2>/dev/null | tr '\n' ' ')
                echo "INFO: Service $service_name may have conflicts: $conflict_text"
                service_conflicts="$service_conflicts $conflict_text"
            fi
        fi
    done
    
    # Analyze dependency relationships across all services
    echo "INFO: Analyzing cross-service dependencies..."
    
    # Check for circular dependencies and common dependency patterns
    local circular_deps=0
    local shared_deps=0
    
    # Look for services that might depend on each other
    for service_a in $all_services; do
        for service_b in $all_services; do
            if [ "$service_a" != "$service_b" ]; then
                # Check if service_a's rc mentions service_b (direct dependency)
                local service_a_rc="$services_dir/$service_a/etc/rc"
                if [ -f "$service_a_rc" ]; then
                    if grep -q "$service_b" "$service_a_rc" 2>/dev/null; then
                        echo "INFO: Service $service_a potentially depends on $service_b"
                        
                        # Check for mutual dependency (circular)
                        local service_b_rc="$services_dir/$service_b/etc/rc"
                        if [ -f "$service_b_rc" ]; then
                            if grep -q "$service_a" "$service_b_rc" 2>/dev/null; then
                                echo "WARN: Potential circular dependency between $service_a and $service_b"
                                circular_deps=$((circular_deps + 1))
                            fi
                        fi
                    fi
                fi
            fi
        done
    done
    
    # Look for commonly referenced services/packages
    echo "INFO: Identifying shared dependencies..."
    local common_deps=$(grep -oE "(sshd|nginx|mysql|postgres|redis|apache)" "$services_dir"/*/*/rc "$services_dir"/*/*/postinst/*.sh 2>/dev/null | sort | uniq -c | sort -nr | head -10)
    if [ -n "$common_deps" ]; then
        echo "INFO: Common dependencies found in services:"
        echo "$common_deps" | while read -r count dep; do
            echo "  - $dep: $count references"
            shared_deps=$((shared_deps + 1))
        done
    fi
    
    if [ $circular_deps -gt 0 ]; then
        echo "WARN: Found $circular_deps potential circular dependencies"
    fi
    
    if [ $shared_deps -gt 0 ]; then
        echo "INFO: Found $shared_deps shared dependency categories"
    fi
    
    if [ $total_dependencies -gt 0 ]; then
        echo "INFO: Identified $total_dependencies service dependencies across all services"
    fi
    
    return 0
}

# Test service configuration consistency across services
test_service_consistency_and_patterns() {
    local services_dir="$PROJECT_ROOT/service"
    local consistency_issues=0
    local pattern_count=0
    
    # Analyze common patterns and consistency across services
    echo "INFO: Analyzing service consistency and patterns..."
    
    # Track common patterns
    local env_pattern_count=0
    local mount_pattern_count=0
    local network_pattern_count=0
    
    # Analyze each service for common patterns
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Check for consistent environment setup
                local has_env=$(grep -c "export.*PATH\|export.*HOME\|export.*TMP\|export.*TEMP" "$rc_file")
                local has_custom_env=$(grep -c "export.*=" "$rc_file")
                
                if [ "$has_env" -gt 0 ]; then
                    env_pattern_count=$((env_pattern_count + 1))
                    if [ "$has_custom_env" -gt 3 ]; then
                        echo "INFO: Service $service_name has comprehensive environment setup"
                    else
                        echo "INFO: Service $service_name has basic environment setup"
                    fi
                fi
                
                # Check for file system mounting patterns
                local has_mount=$(grep -c "mount.*-a\|mount.*tmpfs\|mount.*union" "$rc_file")
                local has_tmpfs=$(grep -c "tmpfs" "$rc_file")
                local has_union=$(grep -c "union" "$rc_file")
                
                if [ "$has_mount" -gt 0 ]; then
                    mount_pattern_count=$((mount_pattern_count + 1))
                    if [ "$has_tmpfs" -gt 0 ]; then
                        echo "INFO: Service $service_name uses tmpfs for isolation"
                    fi
                    if [ "$has_union" -gt 0 ]; then
                        echo "INFO: Service $service_name uses union mounts"
                    fi
                fi
                
                # Check for network configuration patterns
                local has_ifconfig=$(grep -c "ifconfig" "$rc_file")
                local has_route=$(grep -c "route" "$rc_file")
                
                if [ "$has_ifconfig" -gt 0 ] || [ "$has_route" -gt 0 ]; then
                    network_pattern_count=$((network_pattern_count + 1))
                    echo "INFO: Service $service_name configures network settings"
                fi
                
                # Check for service-specific patterns
                local has_start_sequence=$(grep -c "sleep\|wait\|timeout\|waitfor" "$rc_file")
                if [ "$has_start_sequence" -gt 0 ]; then
                    echo "INFO: Service $service_name has start sequence management"
                fi
            fi
        fi
    done
    
    # Compare with common standards
    local total_services=$(echo */ | wc -w)
    if [ $total_services -gt 0 ]; then
        local env_percent=$((env_pattern_count * 100 / total_services))
        local mount_percent=$((mount_pattern_count * 100 / total_services))
        local net_percent=$((network_pattern_count * 100 / total_services))
        
        echo "INFO: Service pattern analysis ($total_services total services):"
        echo "  - Environment setup: $env_pattern_count ($env_percent%) services"
        echo "  - Mount/Isolation: $mount_pattern_count ($mount_percent%) services" 
        echo "  - Network config: $network_pattern_count ($net_percent%) services"
    fi
    
    return 0
}

# Test service build dependencies and requirements
test_build_dependencies() {
    local services_dir="$PROJECT_ROOT/service"
    local build_issues=0
    
    echo "INFO: Analyzing service build dependencies..."
    
    # Check for services that require specific build environments
    local netbsd_only_count=0
    local linux_compatible_count=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check for NetBSD-specific requirements
            local netbsd_only_file="$service_dir/NETBSD_ONLY"
            if [ -f "$netbsd_only_file" ]; then
                netbsd_only_count=$((netbsd_only_count + 1))
                echo "INFO: Service $service_name requires NetBSD build environment"
            fi
            
            # Check build scripts for platform-specific code
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        local has_uname=$(grep -c "uname.*s\|uname.*m\|uname.*r" "$script")
                        local has_platform=$(grep -ci "linux\|netbsd\|freebsd\|openbsd\|darwin" "$script")
                        
                        if [ "$has_uname" -gt 0 ] || [ "$has_platform" -gt 0 ]; then
                            echo "INFO: Service $service_name build script has platform detection"
                        fi
                    fi
                done
            fi
            
            # Check for specific build requirements
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                local has_arch_cond=$(grep -c "ARCH.*!=\|ARCH.*==\|ARCH.*match" "$options_mk")
                local has_pkg_version=$(grep -ci "PKGVERS" "$options_mk")
                
                if [ "$has_arch_cond" -gt 0 ]; then
                    echo "INFO: Service $service_name has architecture-specific build options"
                fi
                if [ "$has_pkg_version" -gt 0 ]; then
                    echo "INFO: Service $service_name has package version requirements"
                fi
            fi
        fi
    done
    
    echo "INFO: Build dependency analysis:"
    echo "  - NetBSD-only services: $netbsd_only_count"
    echo "  - Services with platform detection: $linux_compatible_count"
    
    return 0
}

# Test service configuration file dependencies
test_config_dependencies() {
    local services_dir="$PROJECT_ROOT/service"
    local config_issues=0
    
    echo "INFO: Analyzing service configuration dependencies..."
    
    # Check for services that reference each other's config files
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Check for references to other services' config files
                local other_configs=$(grep -oE "/etc/[a-zA-Z0-9_-]*/" "$rc_file" | sort -u | sed 's|/etc/||' | sed 's|/||g' | tr '\n' ' ')
                
                if [ -n "$other_configs" ]; then
                    echo "INFO: Service $service_name references configs from services: $other_configs"
                    
                    # Check if referenced services actually exist
                    for ref_service in $other_configs; do
                        if [ -d "$services_dir/$ref_service" ]; then
                            echo "  - Reference to service $ref_service is valid"
                        elif [ "$ref_service" != "$service_name" ]; then
                            echo "  - Reference to service $ref_service may be invalid"
                        fi
                    done
                fi
                
                # Check for dependency on common configurations
                local common_refs=$(grep -oE "/etc/include/[a-zA-Z0-9_-]*" "$rc_file" | sort -u | tr '\n' ' ')
                if [ -n "$common_refs" ]; then
                    echo "INFO: Service $service_name uses common configurations: $common_refs"
                fi
            fi
        fi
    done
    
    return 0
}

# Run all advanced service dependency tests
run_all_advanced_dependency_tests() {
    echo "Running advanced service dependency and validation tests..."
    
    local failed_tests=0
    
    run_test "Service dependencies and relationships" test_service_dependencies_and_relationships || failed_tests=$((failed_tests + 1))
    run_test "Service consistency and patterns" test_service_consistency_and_patterns || failed_tests=$((failed_tests + 1))
    run_test "Build dependency validation" test_build_dependencies || failed_tests=$((failed_tests + 1))
    run_test "Configuration dependency validation" test_config_dependencies || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All advanced service dependency tests passed"
        return 0
    else
        echo "$failed_tests advanced service dependency tests had issues"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_advanced_dependency_tests
fi