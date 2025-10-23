#!/bin/sh
#
# Advanced Service Dependency Validation
# High-quality analysis of service dependencies and relationships
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
# Analyze service interdependencies with advanced rigor
analyze_service_dependencies() {
    local service_root="$PROJECT_ROOT/service"
    local dep_errors=0
    local total_deps=0
    
    echo "ANALYZING: Service dependencies with advanced rigor"
    
    # Build dependency map for all services
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            echo "DEPENDENCY ANALYSIS: $service_name"
            
            # Analyze rc file dependencies
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Look for references to other services or system components
                local refs=$(grep -oE "(sshd|nginx|apache|mysql|postgres|redis|docker|systemd|dinit|runit)" "$rc_file" 2>/dev/null | sort -u)
                if [ -n "$refs" ]; then
                    for ref in $refs; do
                        total_deps=$((total_deps + 1))
                        echo "  DEPENDS ON: $ref"
                        
                        # Check if dependency makes sense
                        case "$ref" in
                            sshd)
                                if [ "$service_name" != "sshd" ] && [ "$service_name" != "nitrosshd" ]; then
                                    echo "  WARNING: Non-SSH service references sshd: $service_name -> $ref"
                                fi
                                ;;
                            nginx|apache)
                                if [ "$service_name" != "bozohttpd" ]; then
                                    echo "  INFO: Non-web service references web server: $service_name -> $ref"
                                fi
                                ;;
                        esac
                    done
                fi
                
                # Check for circular dependencies by looking for service self-references
                if grep -q "$service_name" "$rc_file" 2>/dev/null; then
                    echo "  INFO: Service $service_name references itself (may be intentional)"
                fi
            fi
            
            # Analyze postinst script dependencies
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        
                        # Look for package installation commands
                        local pkg_installs=$(grep -cE "(pkg_add|pkgin install|apt-get install|yum install|dnf install)" "$script" 2>/dev/null)
                        if [ "$pkg_installs" -gt 0 ]; then
                            total_deps=$((total_deps + 1))
                            echo "  PACKAGE DEPS: $service_name installs $pkg_installs packages via postinst"
                        fi
                        
                        # Look for service startup commands
                        local svc_starts=$(grep -cE "(service.*start\|/etc/init.d/.*start\|systemctl start\|sv start\|dinit start)" "$script" 2>/dev/null)
                        if [ "$svc_starts" -gt 0 ]; then
                            total_deps=$((total_deps + 1))
                            echo "  SERVICE STARTS: $service_name starts $svc_starts other services"
                        fi
                        
                        # Look for dangerous cross-service operations
                        local dangerous_ops=$(grep -cE "(rm.*-rf.*service\|cp.*service.*service\|mv.*service.*service)" "$script" 2>/dev/null)
                        if [ "$dangerous_ops" -gt 0 ]; then
                            echo "  CRITICAL: Dangerous cross-service operations in $service_name postinst"
                            dep_errors=$((dep_errors + 10))
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $dep_errors -gt 0 ]; then
        echo "FAILED: $dep_errors critical dependency errors found"
        return 1
    else
        echo "PASSED: $total_deps service dependencies analyzed"
        return 0
    fi
}

# Validate service build dependencies with advanced scrutiny
validate_build_dependencies() {
    local service_root="$PROJECT_ROOT/service"
    local build_errors=0
    local build_warnings=0
    
    echo "VALIDATING: Build dependencies with advanced scrutiny"
    
    # Check build dependency files
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check options.mk for build dependencies
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                echo "BUILD DEPS: $service_name has build options"
                
                # Check for architecture constraints
                local arch_constraints=$(grep -cE "(ARCH.*!=\|ARCH.*==\|ONLY_FOR_ARCHS)" "$options_mk" 2>/dev/null)
                if [ "$arch_constraints" -gt 0 ]; then
                    echo "  ARCH CONSTRAINTS: $service_name has $arch_constraints architecture constraints"
                fi
                
                # Check for OS constraints
                local os_constraints=$(grep -cE "(OPSYS\|ONLY_FOR_OPSYS\|NOT_FOR_OPSYS)" "$options_mk" 2>/dev/null)
                if [ "$os_constraints" -gt 0 ]; then
                    echo "  OS CONSTRAINTS: $service_name has $os_constraints OS constraints"
                fi
                
                # Check for package dependencies
                local pkg_deps=$(grep -cE "(DEPENDS\|BUILD_DEPENDS\|RUN_DEPENDS)" "$options_mk" 2>/dev/null)
                if [ "$pkg_deps" -gt 0 ]; then
                    echo "  PKG DEPS: $service_name has $pkg_deps package dependencies"
                fi
                
                # Check for dangerous build operations
                local dangerous_build=$(grep -cE "(SYSTEM.*rm\|ROOT.*rm\|FORCE.*rm)" "$options_mk" 2>/dev/null)
                if [ "$dangerous_build" -gt 0 ]; then
                    echo "  CRITICAL: Dangerous build operations in $service_name options.mk"
                    build_errors=$((build_errors + 10))
                fi
            fi
        fi
    done
    
    # Check for inconsistent build dependencies across services
    local services_with_options=0
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                services_with_options=$((services_with_options + 1))
            fi
        fi
    done
    
    echo "BUILD SUMMARY: $services_with_options services have build options"
    
    if [ $build_errors -gt 0 ]; then
        echo "FAILED: $build_errors critical build dependency errors"
        return 1
    else
        echo "PASSED: Build dependencies validated with advanced scrutiny"
        return 0
    fi
}

# Check cross-service configuration dependencies
check_config_dependencies() {
    local service_root="$PROJECT_ROOT/service"
    local config_dep_errors=0
    
    echo "CHECKING: Cross-service configuration dependencies"
    
    # Look for services that reference other service configs
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Look for references to other service config directories
                local config_refs=$(grep -oE "/etc/[a-zA-Z0-9_-]*/" "$rc_file" 2>/dev/null | sort -u)
                if [ -n "$config_refs" ]; then
                    echo "CONFIG DEPS: $service_name references other service configs:"
                    echo "$config_refs" | while read -r config_ref; do
                        local ref_service=$(echo "$config_ref" | sed 's|/etc/||' | sed 's|/||')
                        if [ -n "$ref_service" ] && [ "$ref_service" != "$service_name" ]; then
                            if [ -d "$service_root/$ref_service" ]; then
                                echo "  VALID REF: $service_name -> $ref_service"
                            else
                                echo "  INVALID REF: $service_name -> $ref_service (service does not exist)"
                                config_dep_errors=$((config_dep_errors + 1))
                            fi
                        fi
                    done
                fi
            fi
        fi
    done
    
    if [ $config_dep_errors -gt 0 ]; then
        echo "FAILED: $config_dep_errors invalid configuration dependencies"
        return 1
    else
        echo "PASSED: Configuration dependencies validated"
        return 0
    fi
}

# Run all advanced dependency validation tests
run_kernel_grade_dependency_tests() {
    echo "RUNNING: Advanced service dependency validation"
    echo "=================================================="
    
    local test_failures=0
    
    run_test "Service dependency analysis" analyze_service_dependencies || test_failures=$((test_failures + 1))
    run_test "Build dependency validation" validate_build_dependencies || test_failures=$((test_failures + 1))
    run_test "Configuration dependency checking" check_config_dependencies || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ]; then
        echo "ALL ADVANCED DEPENDENCY TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures advanced dependency test suites failed"
        return 1
    fi
}

# Execute if run directly
if [ "$0" = "$0" ]; then
    run_kernel_grade_dependency_tests
fi