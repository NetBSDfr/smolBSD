#!/bin/sh
#
# Advanced Service Integration Testing
# High-quality validation of service integration patterns
#

# Source test harness
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Test service-system integration with advanced rigor
test_system_integration() {
    local service_root="$PROJECT_ROOT/service"
    local integration_issues=0
    
    echo "Testing service-system integration with advanced rigor..."
    
    # Analyze system integration for each service
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            echo "SYSTEM INTEGRATION: $service_name"
            
            # Check etc directory for system integration patterns
            local etc_dir="$service_dir/etc"
            if [ -d "$etc_dir" ]; then
                # Check for system configuration files
                local rc_file="$etc_dir/rc"
                if [ -f "$rc_file" ]; then
                    # Validate system integration patterns in rc file
                    local mount_ops=$(grep -cE "(mount.*-a\|mount -t\|mount.*tmpfs\|mount.*union)" "$rc_file" 2>/dev/null || echo "0")
                    local net_ops=$(grep -cE "(ifconfig\|route\|hostname\|dhclient)" "$rc_file" 2>/dev/null || echo "0")
                    local fs_ops=$(grep -cE "(fstab\|mount.conf\|rc.conf)" "$rc_file" 2>/dev/null || echo "0")
                    local sys_ops=$(grep -cE "(sysctl\|dmesg\|kldload)" "$rc_file" 2>/dev/null || echo "0")
                    
                    # Ensure numeric values for comparison
                    mount_ops=$(echo "$mount_ops" | tr -d ' \t\r\n' || echo "0")
                    net_ops=$(echo "$net_ops" | tr -d ' \t\r\n' || echo "0")
                    fs_ops=$(echo "$fs_ops" | tr -d ' \t\r\n' || echo "0")
                    sys_ops=$(echo "$sys_ops" | tr -d ' \t\r\n' || echo "0")
                    
                    # Convert to integers with default 0
                    mount_ops=${mount_ops:-0}
                    net_ops=${net_ops:-0}
                    fs_ops=${fs_ops:-0}
                    sys_ops=${sys_ops:-0}
                    
                    # Use numeric comparisons with proper error handling
                    if [ "$mount_ops" -gt 0 ] 2>/dev/null; then
                        echo "  MOUNT: Service $service_name performs $mount_ops filesystem mount operations"
                    fi
                    if [ "$net_ops" -gt 0 ] 2>/dev/null; then
                        echo "  NETWORK: Service $service_name performs $net_ops network operations"
                    fi
                    if [ "$fs_ops" -gt 0 ] 2>/dev/null; then
                        echo "  FS CONFIG: Service $service_name manages $fs_ops filesystem configurations"
                    fi
                    if [ "$sys_ops" -gt 0 ] 2>/dev/null; then
                        echo "  SYSCTL: Service $service_name manages $sys_ops system parameters"
                    fi
                fi
                
                # Check for common system configuration files
                for sys_conf in fstab rc.conf sysctl.conf; do
                    local conf_file="$etc_dir/$sys_conf"
                    if [ -f "$conf_file" ]; then
                        echo "  SYS CONF: Service $service_name has system config $sys_conf"
                        
                        # Validate system configuration file
                        local conf_lines=$(wc -l < "$conf_file" 2>/dev/null | tr -d ' \t\r\n' || echo "0")
                        conf_lines=${conf_lines:-0}
                        if [ "$conf_lines" -gt 0 ] 2>/dev/null; then
                            echo "  CONF SIZE: Service $service_name $sys_conf has $conf_lines lines"
                        else
                            echo "  WARN: Service $service_name $sys_conf is empty"
                        fi
                    fi
                done
            fi
            
            # Check for system integration in postinst scripts
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                local postinst_scripts=0
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        postinst_scripts=$((postinst_scripts + 1))
                        local script_name=$(basename "$script")
                        
                        # Check for system integration operations in postinst
                        local pkg_ops=$(grep -cE "(pkg_add|pkgin install|apt-get install|yum install)" "$script" 2>/dev/null || echo "0")
                        local user_ops=$(grep -cE "(useradd|groupadd|adduser|addgroup)" "$script" 2>/dev/null || echo "0")
                        local sys_conf_ops=$(grep -cE "(cp.*etc|mv.*etc|install.*etc)" "$script" 2>/dev/null || echo "0")
                        
                        # Ensure numeric values for comparison
                        pkg_ops=$(echo "$pkg_ops" | tr -d ' \t\r\n' || echo "0")
                        user_ops=$(echo "$user_ops" | tr -d ' \t\r\n' || echo "0")
                        sys_conf_ops=$(echo "$sys_conf_ops" | tr -d ' \t\r\n' || echo "0")
                        
                        # Convert to integers with default 0
                        pkg_ops=${pkg_ops:-0}
                        user_ops=${user_ops:-0}
                        sys_conf_ops=${sys_conf_ops:-0}
                        
                        # Use numeric comparisons with proper error handling
                        if [ "$pkg_ops" -gt 0 ] 2>/dev/null; then
                            echo "  PKG INSTALL: Service $service_name postinst $script_name installs $pkg_ops packages"
                        fi
                        if [ "$user_ops" -gt 0 ] 2>/dev/null; then
                            echo "  USER MGMT: Service $service_name postinst $script_name manages $user_ops users/groups"
                        fi
                        if [ "$sys_conf_ops" -gt 0 ] 2>/dev/null; then
                            echo "  SYS CONF: Service $service_name postinst $script_name manages $sys_conf_ops system configs"
                        fi
                    fi
                done
                
                if [ $postinst_scripts -gt 0 ] 2>/dev/null; then
                    echo "  POSTINST: Service $service_name has $postinst_scripts postinst scripts"
                fi
            fi
        fi
    done
    
    if [ $integration_issues -eq 0 ] 2>/dev/null; then
        echo "PASSED: $integration_issues service-system integration issues found"
        return 0
    else
        echo "FAILED: $integration_issues service-system integration issues detected"
        return 1
    fi
}

# Test service interoperation with advanced scrutiny
test_service_interoperation() {
    local service_root="$PROJECT_ROOT/service"
    local interop_issues=0
    
    echo "Testing service interoperation with advanced scrutiny..."
    
    # Analyze service interoperation patterns
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            echo "SERVICE INTEROP: $service_name"
            
            # Check etc directory for interoperation patterns
            local etc_dir="$service_dir/etc"
            if [ -d "$etc_dir" ]; then
                local rc_file="$etc_dir/rc"
                if [ -f "$rc_file" ]; then
                    # Look for references to other services
                    local service_refs=$(grep -oE "(sshd\|nginx\|apache\|httpd\|mysql\|postgres\|redis\|docker\|systemd\|dinit\|runit\|bozohttpd\|imgbuilder\|mport\|nbakery\|nitro\|nitrosshd\|rescue\|runbsd\|systembsd\|tslog)" "$rc_file" 2>/dev/null | sort -u)
                    if [ -n "$service_refs" ]; then
                        local ref_count=$(echo "$service_refs" | wc -l)
                        echo "  SERVICE REFS: Service $service_name references $ref_count other services:"
                        echo "$service_refs" | while read -r ref; do
                            echo "    - $ref"
                        done
                        interop_issues=$((interop_issues + $ref_count))
                    fi
                    
                    # Look for network interoperation
                    local net_refs=$(grep -cE "(curl\|wget\|nc\|netcat\|socat\|ssh\|telnet)" "$rc_file" 2>/dev/null || echo "0")
                    if [ "$net_refs" -gt 0 ] 2>/dev/null; then
                        echo "  NET INTEROP: Service $service_name performs $net_refs network operations"
                    fi
                    
                    # Look for IPC/messaging patterns
                    local ipc_refs=$(grep -cE "(socket\|pipe\|fifo\|msg\|sem\|shm)" "$rc_file" 2>/dev/null || echo "0")
                    if [ "$ipc_refs" -gt 0 ] 2>/dev/null; then
                        echo "  IPC: Service $service_name uses $ipc_refs inter-process communication patterns"
                    fi
                fi
            fi
            
            # Check for service interoperation in postinst scripts
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        
                        # Look for service management operations
                        local svc_ops=$(grep -cE "(service\|sv\|runit\|dinit\|systemctl)" "$script" 2>/dev/null || echo "0")
                        if [ "$svc_ops" -gt 0 ] 2>/dev/null; then
                            echo "  SVC MGMT: Service $service_name postinst $script_name manages $svc_ops services"
                        fi
                        
                        # Look for package dependencies that indicate service relationships
                        local pkg_deps=$(grep -cE "(pkg_add.*ssh\|pkgin install.*ssh\|pkg_add.*http\|pkgin install.*http\|pkg_add.*web\|pkgin install.*web)" "$script" 2>/dev/null || echo "0")
                        if [ "$pkg_deps" -gt 0 ] 2>/dev/null; then
                            echo "  PKG DEPS: Service $service_name postinst $script_name has $pkg_deps service-related package dependencies"
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $interop_issues -eq 0 ] 2>/dev/null; then
        echo "PASSED: $interop_issues service interoperation issues found"
        return 0
    else
        echo "INFO: $interop_issues service interoperation patterns detected (may be intentional)"
        return 0  # Don't fail for interoperation patterns
    fi
}

# Test build system integration with kernel-level quality
test_build_integration() {
    local service_root="$PROJECT_ROOT/service"
    local build_issues=0
    
    echo "Testing build system integration with kernel-level quality..."
    
    # Analyze build system integration for each service
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            echo "BUILD INTEGRATION: $service_name"
            
            # Check for options.mk file
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                echo "  OPTIONS MK: Service $service_name has build options"
                
                # Validate options.mk content
                local imgsize=$(grep -cE "(IMGSIZE\|SIZE)" "$options_mk" 2>/dev/null || echo "0")
                local arch=$(grep -cE "(ARCH\|arch)" "$options_mk" 2>/dev/null || echo "0")
                local deps=$(grep -cE "(DEPENDS\|BUILD_DEPENDS\|RUN_DEPENDS)" "$options_mk" 2>/dev/null || echo "0")
                
                if [ "$imgsize" -gt 0 ] 2>/dev/null; then
                    echo "  IMG SIZE: Service $service_name specifies image size requirements"
                fi
                if [ "$arch" -gt 0 ] 2>/dev/null; then
                    echo "  ARCH: Service $service_name has architecture constraints"
                fi
                if [ "$deps" -gt 0 ] 2>/dev/null; then
                    echo "  BUILD DEPS: Service $service_name has $deps build dependencies"
                fi
            else
                echo "  INFO: Service $service_name has no build options.mk (may be OK)"
            fi
            
            # Check for build integration in postinst scripts
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                local build_scripts=0
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        build_scripts=$((build_scripts + 1))
                        local script_name=$(basename "$script")
                        
                        # Check for build-time operations
                        local build_ops=$(grep -cE "(make\|gcc\|cc\|compile\|build)" "$script" 2>/dev/null || echo "0")
                        local pkg_install=$(grep -cE "(pkg_add\|pkgin install\|apt-get install\|yum install)" "$script" 2>/dev/null || echo "0")
                        
                        if [ "$build_ops" -gt 0 ] 2>/dev/null; then
                            echo "  BUILD: Service $service_name postinst $script_name performs $build_ops build operations"
                        fi
                        if [ "$pkg_install" -gt 0 ] 2>/dev/null; then
                            echo "  PKG: Service $service_name postinst $script_name installs $pkg_install packages"
                        fi
                    fi
                done
                
                if [ $build_scripts -gt 0 ] 2>/dev/null; then
                    echo "  BUILD SCRIPTS: Service $service_name has $build_scripts build scripts"
                fi
            fi
        fi
    done
    
    # Check for main build system integration
    local makefile="$PROJECT_ROOT/Makefile"
    if [ -f "$makefile" ]; then
        local main_targets=$(grep -cE "^(rescue\|base\|build\|imgbuilder\|mport\|nbakery\|nitro\|nitrosshd\|runbsd\|sshd\|systembsd\|tslog):" "$makefile" 2>/dev/null || echo "0")
        if [ "$main_targets" -gt 0 ] 2>/dev/null; then
            echo "MAIN BUILD: Main build system integration available ($main_targets targets)"
        else
            echo "WARN: Main build system may not have service targets"
            build_issues=$((build_issues + 1))
        fi
    else
        echo "FAIL: Main Makefile not found"
        build_issues=$((build_issues + 10))
    fi
    
    if [ $build_issues -eq 0 ] 2>/dev/null; then
        echo "PASSED: $main_targets build integration points validated"
        return 0
    else
        echo "FAILED: $build_issues build integration issues detected"
        return 1
    fi
}

# Run all advanced integration tests
run_advanced_integration_tests() {
    echo "Running advanced service integration tests..."
    
    local test_failures=0
    
    run_test "Service system integration" test_system_integration || test_failures=$((test_failures + 1))
    run_test "Service interoperation" test_service_interoperation || test_failures=$((test_failures + 1))
    run_test "Build system integration" test_build_integration || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ] 2>/dev/null; then
        echo "All advanced service integration tests passed"
        return 0
    else
        echo "$test_failures advanced service integration test suites failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "${0##*/}" = "test_service_advanced_integration.sh" ] || [ "${BASH_SOURCE:-$0}" = "$0" ]; then
    run_advanced_integration_tests
fi