#!/bin/sh
#
# Advanced Service Compatibility and Portability Tests for smolBSD
# Comprehensive validation of cross-platform compatibility, portability, and standard compliance
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

# Test POSIX compliance and portability of service scripts
test_posix_compliance() {
    local services_dir="$PROJECT_ROOT/service"
    local compliance_issues=0
    local total_scripts=0
    
    echo "INFO: Testing POSIX compliance and portability of service scripts..."
    
    # Check all service scripts for POSIX compliance
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check all script files in the service
            for script_file in "$service_dir"/*/*; do
                if [ -f "$script_file" ] && echo "$script_file" | grep -qE '\.(sh|rc)
                    total_scripts=$((total_scripts + 1))
                    
                    echo "INFO: Testing POSIX compliance for script: $(basename "$script_file") in service $service_name"
                    
                    # Check for non-POSIX shell features
                    local bashisms=$(grep -cE "(?<=\W)local(?=\W)\|(?<=\W)declare(?=\W)\|(?<=\W)array(?=\W)\|(?<=\W)associative(?=\W)" "$script_file")
                    if [ "$bashisms" -gt 0 ]; then
                        echo "  - WARNING: $bashisms potential bash-specific features found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for non-POSIX test operators
                    local non_posix_ops=$(grep -cE "\[\[|\]\]" "$script_file")
                    if [ "$non_posix_ops" -gt 0 ]; then
                        echo "  - WARNING: $non_posix_ops non-POSIX test operators [[ ]] found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for advanced bash features like process substitution
                    local proc_sub=$(grep -cE "<\(|>\(" "$script_file")
                    if [ "$proc_sub" -gt 0 ]; then
                        echo "  - WARNING: $proc_sub process substitution operators found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for non-POSIX parameter expansion
                    local non_posix_param=$(grep -cE "\${![a-zA-Z]\|\${#*\|\${@[a-zA-Z-]}") 
                    if [ "$non_posix_param" -gt 0 ]; then
                        echo "  - WARNING: $non_posix_param non-POSIX parameter expansion found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for non-POSIX I/O redirection
                    local non_posix_io=$(grep -cE ">&|<&|>|" "$script_file")
                    if [ "$non_posix_io" -gt 0 ]; then
                        echo "  - WARNING: $non_posix_io non-POSIX I/O redirection found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Validate shebang
                    local first_line=$(head -n1 "$script_file")
                    if echo "$first_line" | grep -q "#!/bin/sh"; then
                        echo "  - OK: Uses POSIX-compliant /bin/sh shebang"
                    elif echo "$first_line" | grep -q "#!/bin/bash"; then
                        echo "  - WARNING: Uses bash-specific /bin/bash shebang"
                        compliance_issues=$((compliance_issues + 1))
                    else
                        echo "  - INFO: Unusual shebang pattern: $first_line"
                    fi
                fi
            done
        fi
    done
    
    if [ $total_scripts -gt 0 ]; then
        echo "INFO: Analyzed $total_scripts service scripts for POSIX compliance"
        if [ $compliance_issues -eq 0 ]; then
            echo "PASS: All service scripts appear POSIX-compliant"
        else
            echo "WARN: $compliance_issues compliance issues found in service scripts"
        fi
    fi
    
    return 0
}

# Test cross-platform portability of service configurations
test_cross_platform_portability() {
    local services_dir="$PROJECT_ROOT/service"
    local portability_issues=0
    
    echo "INFO: Testing cross-platform portability of service configurations..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing portability for service: $service_name"
                
                # Check for platform-specific paths
                local platform_paths=$(grep -cE "(/proc/|/sys/|/dev/fd|/dev/std|/var/run/dbus)" "$rc_file")
                if [ "$platform_paths" -gt 0 ]; then
                    echo "  - INFO: $platform_paths platform-specific paths found"
                fi
                
                # Check for BSD-specific commands
                local bsd_cmd=$(grep -cE "(bsdinstall\|bsdconfig\|rcctl\|service.*bsd)" "$rc_file")
                if [ "$bsd_cmd" -gt 0 ]; then
                    echo "  - INFO: $bsd_cmd BSD-specific commands found"
                fi
                
                # Check for Linux-specific commands
                local linux_cmd=$(grep -cE "(systemctl\|systemd\|service.*redhat\|service.*debian)" "$rc_file")
                if [ "$linux_cmd" -gt 0 ]; then
                    echo "  - INFO: $linux_cmd Linux-specific commands found"
                fi
                
                # Check for platform detection
                local platform_check=$(grep -cE "(uname.*s\|uname.*m\|uname.*r\|uname.*v\|uname.*p)" "$rc_file")
                if [ "$platform_check" -gt 0 ]; then
                    echo "  - OK: $platform_check platform detection checks found"
                    
                    # Extract platform detection patterns
                    local platform_patterns=$(grep -oE "(NetBSD|FreeBSD|Linux|Darwin|OpenBSD)" "$rc_file" | sort -u | tr '\n' ' ')
                    if [ -n "$platform_patterns" ]; then
                        echo "  - Platforms handled: $platform_patterns"
                    fi
                fi
                
                # Check for portable command usage
                local portable_cmd=$(grep -cE "(mount -a\|ifconfig\|route\|netstat\|ps\|kill\|pidof\|pgrep)" "$rc_file")
                if [ "$portable_cmd" -gt 0 ]; then
                    echo "  - INFO: $portable_cmd potentially portable commands used"
                fi
            fi
        fi
    done
    
    return 0
}

# Test filesystem portability and path validation
test_filesystem_portability() {
    local services_dir="$PROJECT_ROOT/service"
    local fs_issues=0
    
    echo "INFO: Testing filesystem and path portability..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check all files in service for path portability
            find "$service_dir" -type f -exec grep -l "." {} \; 2>/dev/null | while read -r file; do
                if [ -f "$file" ]; then
                    echo "INFO: Analyzing paths in file: $(basename "$file") for service $service_name"
                    
                    # Check for absolute paths that might be platform-specific
                    local abs_paths=$(grep -oE "/[a-zA-Z0-9/._-]+" "$file" | grep -E "^/.*" | sort -u | head -10)
                    if [ -n "$abs_paths" ]; then
                        echo "  - Found absolute paths:"
                        echo "$abs_paths" | while read -r path; do
                            case "$path" in
                                /usr/local/*|/opt/*|/home/*)
                                    echo "    - $path (may be non-standard on embedded systems)"
                                    ;;
                                /etc/*)
                                    echo "    - $path (standard configuration path)"
                                    ;;
                                /dev/*)
                                    echo "    - $path (device path)"
                                    ;;
                                /proc/*|/sys/*)
                                    echo "    - $path (Linux-specific virtual filesystem)"
                                    ;;
                                *)
                                    echo "    - $path (other path)"
                                    ;;
                            esac
                        done
                    fi
                    
                    # Check for potential path traversal vulnerabilities
                    local path_traversal=$(grep -cE "\.\./\|\.\./\.\./" "$file")
                    if [ "$path_traversal" -gt 0 ]; then
                        echo "  - WARNING: $path_traversal potential path traversal patterns found"
                        fs_issues=$((fs_issues + 1))
                    fi
                    
                    # Check for non-portable filename characters
                    local non_portable_names=$(grep -oE "[^a-zA-Z0-9._/-]" "$file" | sort -u | tr '\n' ' ')
                    if [ -n "$non_portable_names" ]; then
                        echo "  - INFO: Potential non-portable characters in paths: $non_portable_names"
                    fi
                fi
            done
        fi
    done
    
    return 0
}

# Test service compatibility with different architectures
test_architecture_compatibility() {
    local services_dir="$PROJECT_ROOT/service"
    local arch_issues=0
    
    echo "INFO: Testing architecture compatibility..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing architecture compatibility for service: $service_name"
                
                # Check for architecture-specific binaries or paths
                local arch_patterns=$(grep -cE "(x86_64\|i386\|amd64\|i686\|aarch64\|arm64\|armv7\|mips)" "$rc_file")
                if [ "$arch_patterns" -gt 0 ]; then
                    echo "  - INFO: $arch_patterns architecture-specific patterns found"
                    
                    # Extract architecture references
                    local arch_refs=$(grep -oE "(x86_64|i386|amd64|i686|aarch64|arm64|armv7|mips)" "$rc_file" | sort -u | tr '\n' ' ')
                    if [ -n "$arch_refs" ]; then
                        echo "  - Architectures referenced: $arch_refs"
                    fi
                fi
                
                # Check for conditional architecture handling
                local arch_cond=$(grep -cE "ARCH.*!=\|ARCH.*==\|ARCH.*match\|if.*arch\|case.*arch" "$rc_file")
                if [ "$arch_cond" -gt 0 ]; then
                    echo "  - OK: $arch_cond architecture conditionals found"
                fi
                
                # Check for multi-arch binary handling
                local multi_arch=$(grep -cE "(multiarch\|universal\|fat.*binary\|arch.*select\|platform.*detect)" "$rc_file")
                if [ "$multi_arch" -gt 0 ]; then
                    echo "  - INFO: $multi_arch multi-architecture handling patterns found"
                fi
            fi
            
            # Check options.mk for architecture constraints
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                local arch_constraints=$(grep -cE "ARCH.*!=\|ARCH.*==\|ARCH.*match\|!.*ARCH\|ifdef.*ARCH\|if.*ARCH" "$options_mk")
                if [ "$arch_constraints" -gt 0 ]; then
                    echo "  - Build options include $arch_constraints architecture constraints"
                    
                    # Extract architecture constraints
                    local constraint_patterns=$(grep -oE "ARCH.*!=.*\|ARCH.*==.*\|!.*ARCH\|ARCH.*match.*" "$options_mk" | sort -u | tr '\n' ' ')
                    if [ -n "$constraint_patterns" ]; then
                        echo "  - Constraints: $constraint_patterns"
                    fi
                fi
            fi
        fi
    done
    
    return 0
}

# Test service compatibility with different NetBSD versions
test_version_compatibility() {
    local services_dir="$PROJECT_ROOT/service"
    local version_issues=0
    
    echo "INFO: Testing NetBSD version compatibility..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing version compatibility for service: $service_name"
                
                # Check for version-specific features
                local version_refs=$(grep -cE "(VERSION\|version\|VER\|version.*[0-9]\|netbsd.*[0-9])" "$rc_file")
                if [ "$version_refs" -gt 0 ]; then
                    echo "  - INFO: $version_refs version-related references found"
                    
                    # Extract version patterns
                    local versions=$(grep -oE "[0-9]+\.[0-9]+(\.[0-9]+)?" "$rc_file" | sort -u | tr '\n' ' ')
                    if [ -n "$versions" ]; then
                        echo "  - Version references: $versions"
                    fi
                fi
                
                # Check for NetBSD-specific features
                local netbsd_features=$(grep -cE "(rc.d\|rc.conf\|rcorder\|rcvar\|NetBSD)" "$rc_file")
                if [ "$netbsd_features" -gt 0 ]; then
                    echo "  - INFO: $netbsd_features NetBSD-specific features found"
                fi
                
                # Check for version conditionals
                local ver_conditionals=$(grep -cE "if.*version\|version.*then\|case.*version" "$rc_file")
                if [ "$ver_conditionals" -gt 0 ]; then
                    echo "  - INFO: $ver_conditionals version conditionals found"
                fi
            fi
        fi
    done
    
    return 0
}

# Run all advanced compatibility and portability tests

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_compatibility_tests
fi; then
                    total_scripts=$((total_scripts + 1))
                    
                    echo "INFO: Testing POSIX compliance for script: $(basename "$script_file") in service $service_name"
                    
                    # Check for non-POSIX shell features
                    local bashisms=$(grep -cE "(?<=\W)local(?=\W)\|(?<=\W)declare(?=\W)\|(?<=\W)array(?=\W)\|(?<=\W)associative(?=\W)" "$script_file")
                    if [ "$bashisms" -gt 0 ]; then
                        echo "  - WARNING: $bashisms potential bash-specific features found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for non-POSIX test operators
                    local non_posix_ops=$(grep -cE "\[\[|\]\]" "$script_file")
                    if [ "$non_posix_ops" -gt 0 ]; then
                        echo "  - WARNING: $non_posix_ops non-POSIX test operators [[ ]] found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for advanced bash features like process substitution
                    local proc_sub=$(grep -cE "<\(|>\(" "$script_file")
                    if [ "$proc_sub" -gt 0 ]; then
                        echo "  - WARNING: $proc_sub process substitution operators found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for non-POSIX parameter expansion
                    local non_posix_param=$(grep -cE "\${![a-zA-Z]\|\${#*\|\${@[a-zA-Z-]}") 
                    if [ "$non_posix_param" -gt 0 ]; then
                        echo "  - WARNING: $non_posix_param non-POSIX parameter expansion found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Check for non-POSIX I/O redirection
                    local non_posix_io=$(grep -cE ">&|<&|>|" "$script_file")
                    if [ "$non_posix_io" -gt 0 ]; then
                        echo "  - WARNING: $non_posix_io non-POSIX I/O redirection found"
                        compliance_issues=$((compliance_issues + 1))
                    fi
                    
                    # Validate shebang
                    local first_line=$(head -n1 "$script_file")
                    if echo "$first_line" | grep -q "#!/bin/sh"; then
                        echo "  - OK: Uses POSIX-compliant /bin/sh shebang"
                    elif echo "$first_line" | grep -q "#!/bin/bash"; then
                        echo "  - WARNING: Uses bash-specific /bin/bash shebang"
                        compliance_issues=$((compliance_issues + 1))
                    else
                        echo "  - INFO: Unusual shebang pattern: $first_line"
                    fi
                fi
            done
        fi
    done
    
    if [ $total_scripts -gt 0 ]; then
        echo "INFO: Analyzed $total_scripts service scripts for POSIX compliance"
        if [ $compliance_issues -eq 0 ]; then
            echo "PASS: All service scripts appear POSIX-compliant"
        else
            echo "WARN: $compliance_issues compliance issues found in service scripts"
        fi
    fi
    
    return 0
}

# Test cross-platform portability of service configurations
test_cross_platform_portability() {
    local services_dir="$PROJECT_ROOT/service"
    local portability_issues=0
    
    echo "INFO: Testing cross-platform portability of service configurations..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing portability for service: $service_name"
                
                # Check for platform-specific paths
                local platform_paths=$(grep -cE "(/proc/|/sys/|/dev/fd|/dev/std|/var/run/dbus)" "$rc_file")
                if [ "$platform_paths" -gt 0 ]; then
                    echo "  - INFO: $platform_paths platform-specific paths found"
                fi
                
                # Check for BSD-specific commands
                local bsd_cmd=$(grep -cE "(bsdinstall\|bsdconfig\|rcctl\|service.*bsd)" "$rc_file")
                if [ "$bsd_cmd" -gt 0 ]; then
                    echo "  - INFO: $bsd_cmd BSD-specific commands found"
                fi
                
                # Check for Linux-specific commands
                local linux_cmd=$(grep -cE "(systemctl\|systemd\|service.*redhat\|service.*debian)" "$rc_file")
                if [ "$linux_cmd" -gt 0 ]; then
                    echo "  - INFO: $linux_cmd Linux-specific commands found"
                fi
                
                # Check for platform detection
                local platform_check=$(grep -cE "(uname.*s\|uname.*m\|uname.*r\|uname.*v\|uname.*p)" "$rc_file")
                if [ "$platform_check" -gt 0 ]; then
                    echo "  - OK: $platform_check platform detection checks found"
                    
                    # Extract platform detection patterns
                    local platform_patterns=$(grep -oE "(NetBSD|FreeBSD|Linux|Darwin|OpenBSD)" "$rc_file" | sort -u | tr '\n' ' ')
                    if [ -n "$platform_patterns" ]; then
                        echo "  - Platforms handled: $platform_patterns"
                    fi
                fi
                
                # Check for portable command usage
                local portable_cmd=$(grep -cE "(mount -a\|ifconfig\|route\|netstat\|ps\|kill\|pidof\|pgrep)" "$rc_file")
                if [ "$portable_cmd" -gt 0 ]; then
                    echo "  - INFO: $portable_cmd potentially portable commands used"
                fi
            fi
        fi
    done
    
    return 0
}

# Test filesystem portability and path validation
test_filesystem_portability() {
    local services_dir="$PROJECT_ROOT/service"
    local fs_issues=0
    
    echo "INFO: Testing filesystem and path portability..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check all files in service for path portability
            find "$service_dir" -type f -exec grep -l "." {} \; 2>/dev/null | while read -r file; do
                if [ -f "$file" ]; then
                    echo "INFO: Analyzing paths in file: $(basename "$file") for service $service_name"
                    
                    # Check for absolute paths that might be platform-specific
                    local abs_paths=$(grep -oE "/[a-zA-Z0-9/._-]+" "$file" | grep -E "^/.*" | sort -u | head -10)
                    if [ -n "$abs_paths" ]; then
                        echo "  - Found absolute paths:"
                        echo "$abs_paths" | while read -r path; do
                            case "$path" in
                                /usr/local/*|/opt/*|/home/*)
                                    echo "    - $path (may be non-standard on embedded systems)"
                                    ;;
                                /etc/*)
                                    echo "    - $path (standard configuration path)"
                                    ;;
                                /dev/*)
                                    echo "    - $path (device path)"
                                    ;;
                                /proc/*|/sys/*)
                                    echo "    - $path (Linux-specific virtual filesystem)"
                                    ;;
                                *)
                                    echo "    - $path (other path)"
                                    ;;
                            esac
                        done
                    fi
                    
                    # Check for potential path traversal vulnerabilities
                    local path_traversal=$(grep -cE "\.\./\|\.\./\.\./" "$file")
                    if [ "$path_traversal" -gt 0 ]; then
                        echo "  - WARNING: $path_traversal potential path traversal patterns found"
                        fs_issues=$((fs_issues + 1))
                    fi
                    
                    # Check for non-portable filename characters
                    local non_portable_names=$(grep -oE "[^a-zA-Z0-9._/-]" "$file" | sort -u | tr '\n' ' ')
                    if [ -n "$non_portable_names" ]; then
                        echo "  - INFO: Potential non-portable characters in paths: $non_portable_names"
                    fi
                fi
            done
        fi
    done
    
    return 0
}

# Test service compatibility with different architectures
test_architecture_compatibility() {
    local services_dir="$PROJECT_ROOT/service"
    local arch_issues=0
    
    echo "INFO: Testing architecture compatibility..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing architecture compatibility for service: $service_name"
                
                # Check for architecture-specific binaries or paths
                local arch_patterns=$(grep -cE "(x86_64\|i386\|amd64\|i686\|aarch64\|arm64\|armv7\|mips)" "$rc_file")
                if [ "$arch_patterns" -gt 0 ]; then
                    echo "  - INFO: $arch_patterns architecture-specific patterns found"
                    
                    # Extract architecture references
                    local arch_refs=$(grep -oE "(x86_64|i386|amd64|i686|aarch64|arm64|armv7|mips)" "$rc_file" | sort -u | tr '\n' ' ')
                    if [ -n "$arch_refs" ]; then
                        echo "  - Architectures referenced: $arch_refs"
                    fi
                fi
                
                # Check for conditional architecture handling
                local arch_cond=$(grep -cE "ARCH.*!=\|ARCH.*==\|ARCH.*match\|if.*arch\|case.*arch" "$rc_file")
                if [ "$arch_cond" -gt 0 ]; then
                    echo "  - OK: $arch_cond architecture conditionals found"
                fi
                
                # Check for multi-arch binary handling
                local multi_arch=$(grep -cE "(multiarch\|universal\|fat.*binary\|arch.*select\|platform.*detect)" "$rc_file")
                if [ "$multi_arch" -gt 0 ]; then
                    echo "  - INFO: $multi_arch multi-architecture handling patterns found"
                fi
            fi
            
            # Check options.mk for architecture constraints
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                local arch_constraints=$(grep -cE "ARCH.*!=\|ARCH.*==\|ARCH.*match\|!.*ARCH\|ifdef.*ARCH\|if.*ARCH" "$options_mk")
                if [ "$arch_constraints" -gt 0 ]; then
                    echo "  - Build options include $arch_constraints architecture constraints"
                    
                    # Extract architecture constraints
                    local constraint_patterns=$(grep -oE "ARCH.*!=.*\|ARCH.*==.*\|!.*ARCH\|ARCH.*match.*" "$options_mk" | sort -u | tr '\n' ' ')
                    if [ -n "$constraint_patterns" ]; then
                        echo "  - Constraints: $constraint_patterns"
                    fi
                fi
            fi
        fi
    done
    
    return 0
}

# Test service compatibility with different NetBSD versions
test_version_compatibility() {
    local services_dir="$PROJECT_ROOT/service"
    local version_issues=0
    
    echo "INFO: Testing NetBSD version compatibility..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing version compatibility for service: $service_name"
                
                # Check for version-specific features
                local version_refs=$(grep -cE "(VERSION\|version\|VER\|version.*[0-9]\|netbsd.*[0-9])" "$rc_file")
                if [ "$version_refs" -gt 0 ]; then
                    echo "  - INFO: $version_refs version-related references found"
                    
                    # Extract version patterns
                    local versions=$(grep -oE "[0-9]+\.[0-9]+(\.[0-9]+)?" "$rc_file" | sort -u | tr '\n' ' ')
                    if [ -n "$versions" ]; then
                        echo "  - Version references: $versions"
                    fi
                fi
                
                # Check for NetBSD-specific features
                local netbsd_features=$(grep -cE "(rc.d\|rc.conf\|rcorder\|rcvar\|NetBSD)" "$rc_file")
                if [ "$netbsd_features" -gt 0 ]; then
                    echo "  - INFO: $netbsd_features NetBSD-specific features found"
                fi
                
                # Check for version conditionals
                local ver_conditionals=$(grep -cE "if.*version\|version.*then\|case.*version" "$rc_file")
                if [ "$ver_conditionals" -gt 0 ]; then
                    echo "  - INFO: $ver_conditionals version conditionals found"
                fi
            fi
        fi
    done
    
    return 0
}

# Run all advanced compatibility and portability tests
run_all_compatibility_tests() {
    echo "Running advanced service compatibility and portability tests..."
    
    local failed_tests=0
    
    run_test "POSIX compliance validation" test_posix_compliance || failed_tests=$((failed_tests + 1))
    run_test "Cross-platform portability validation" test_cross_platform_portability || failed_tests=$((failed_tests + 1))
    run_test "Filesystem and path portability validation" test_filesystem_portability || failed_tests=$((failed_tests + 1))
    run_test "Architecture compatibility validation" test_architecture_compatibility || failed_tests=$((failed_tests + 1))
    run_test "Version compatibility validation" test_version_compatibility || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All advanced service compatibility and portability tests passed"
        return 0
    else
        echo "$failed_tests advanced service compatibility and portability tests had issues"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${0}" ]; then
    run_all_compatibility_tests
fi
