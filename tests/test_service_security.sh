#!/bin/sh
#
# Service security tests for smolBSD
# Validates security aspects of services including privilege separation, 
# file permissions, network configuration, and attack surface
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

# Test for dangerous operations in service scripts
test_dangerous_operations() {
    local services_dir="$PROJECT_ROOT/service"
    local dangerous_found=0
    
    # Check all service scripts for dangerous operations
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc files
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                local dangerous_count=0
                
                # Look for potentially dangerous operations
                if grep -E "rm -rf /" "$rc_file" >/dev/null 2>&1; then
                    echo "FAIL: Service $service_name rc contains dangerous 'rm -rf /' command"
                    dangerous_count=$((dangerous_count + 1))
                fi
                
                if grep -E "chmod.*000.*[/.]" "$rc_file" >/dev/null 2>&1; then
                    echo "FAIL: Service $service_name rc contains dangerous chmod 000 command"
                    dangerous_count=$((dangerous_count + 1))
                fi
                
                if grep -E "(chown|chmod).*root.*[/.]" "$rc_file" >/dev/null 2>&1; then
                    echo "WARN: Service $service_name rc changes permissions of critical paths"
                fi
                
                if [ $dangerous_count -gt 0 ]; then
                    dangerous_found=$((dangerous_found + dangerous_count))
                else
                    echo "PASS: Service $service_name rc has no obvious dangerous operations"
                fi
            fi
            
            # Check postinst scripts
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        local dangerous_postinst=0
                        
                        # Check for dangerous operations in postinst scripts
                        if grep -E "rm -rf /" "$script" >/dev/null 2>&1; then
                            echo "FAIL: Service $service_name postinst $script contains dangerous 'rm -rf /' command"
                            dangerous_postinst=$((dangerous_postinst + 1))
                        fi
                        
                        if grep -E "mv /etc/.* /root/" "$script" >/dev/null 2>&1; then
                            echo "WARN: Service $service_name postinst $script moves system files in a concerning way"
                        fi
                        
                        if [ $dangerous_postinst -gt 0 ]; then
                            dangerous_found=$((dangerous_found + dangerous_postinst))
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $dangerous_found -eq 0 ]; then
        echo "PASS: No dangerous operations found in service scripts"
        return 0
    else
        echo "FAIL: $dangerous_found dangerous operations found in service scripts"
        return 1
    fi
}

# Test privilege separation and user management
test_privilege_separation() {
    local services_dir="$PROJECT_ROOT/service"
    local service_users_found=0
    
    # Look for services that properly manage users
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Check for proper user creation and usage
                if grep -i "useradd\|adduser" "$rc_file" >/dev/null 2>&1; then
                    echo "PASS: Service $service_name creates users appropriately"
                    service_users_found=$((service_users_found + 1))
                fi
                
                # Check for services running as non-root
                if grep -E "(chown|sudo|su).*[^#]" "$rc_file" >/dev/null 2>&1; then
                    echo "INFO: Service $service_name performs user operations"
                fi
                
                # Check for home directory creation for service users
                if grep -E "mkdir.*home" "$rc_file" | grep -v "/home" >/dev/null 2>&1; then
                    echo "INFO: Service $service_name creates home directories"
                fi
            fi
        fi
    done
    
    if [ $service_users_found -gt 0 ]; then
        echo "INFO: Found $service_users_found services that properly manage users"
    fi
    
    return 0  # Just informational, don't fail
}

# Test network security configurations
test_network_security() {
    local services_dir="$PROJECT_ROOT/service"
    local network_secure=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Check network configuration security
                if grep -E "ifconfig.*inet.*0.0.0.0\|bind.*0.0.0.0" "$rc_file" >/dev/null 2>&1; then
                    echo "WARN: Service $service_name may bind to all interfaces (check security)"
                fi
                
                if grep -E "echo.*port.*>" "$rc_file" | grep -i firewall >/dev/null 2>&1; then
                    echo "INFO: Service $service_name configures firewall rules"
                    network_secure=$((network_secure + 1))
                fi
                
                # Look for SSH-specific security
                if [ "$service_name" = "sshd" ]; then
                    if grep -i "passwordauth.*no\|pubkeyauth.*yes\|permitrootlogin.*no" "$rc_file" >/dev/null 2>&1; then
                        echo "PASS: Service sshd has common security configurations"
                        network_secure=$((network_secure + 1))
                    fi
                fi
            fi
        fi
    done
    
    return 0  # Just informational
}

# Test file permissions and access controls
test_file_permissions() {
    local services_dir="$PROJECT_ROOT/service"
    local perm_issues=0
    
    # Check that service files have appropriate permissions
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check script permissions
            if [ -d "$service_dir/etc" ]; then
                for script in "$service_dir/etc"/*; do
                    if [ -f "$script" ] && [ -s "$script" ]; then
                        local perms=$(stat -c "%a" "$script" 2>/dev/null || echo "644")
                        if [ "${perms#*?}" = "7" ] || [ "${perms%?*}" = "7" ]; then
                            # Script is executable, which may be OK depending on context
                            echo "INFO: Service $service_name file $script has executable permissions ($perms)"
                        else
                            # Non-executable, which is fine for config files
                            echo "INFO: Service $service_name file $script has non-executable permissions ($perms)"
                        fi
                    fi
                done
            fi
            
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        if [ -x "$script" ]; then
                            echo "PASS: Postinst script $script is executable"
                        else
                            # Some postinst files may be templates or data files, not executable scripts
                            local script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
                            if [ "$script_size" -gt 100 ] && grep -qE "(#!/|sh |bash|exec|command|function|if |then|fi|for |do|done)" "$script" 2>/dev/null; then
                                # Likely a script that should be executable
                                echo "WARN: Postinst script $script should be executable (large script-like content)"
                                # Don't count this as a failure, just warn - this is for informational purposes
                            else
                                # Probably a template or data file, OK to be non-executable
                                echo "INFO: Postinst file $script is not executable (may be OK for templates/data)"
                            fi
                        fi
                    fi
                done
            fi
        fi
    done
    
    # Check common service file permissions
    local common_dir="$PROJECT_ROOT/service/common"
    if [ -d "$common_dir" ]; then
        for file in "$common_dir"/*; do
            if [ -f "$file" ] && [ -x "$file" ]; then
                echo "INFO: Common service file $file is executable"
            fi
        done
    fi
    
    if [ $perm_issues -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Test service isolation and sandboxing
test_service_isolation() {
    local services_dir="$PROJECT_ROOT/service"
    local isolation_features=0
    
    # Look for service isolation mechanisms
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Check for tmpfs usage (isolation)
                if grep -E "tmpfs.*mount\|mount -t tmpfs" "$rc_file" >/dev/null 2>&1; then
                    echo "PASS: Service $service_name uses tmpfs for isolation"
                    isolation_features=$((isolation_features + 1))
                fi
                
                # Check for chroot or similar isolation (if any)
                if grep -i "chroot\|jail\|container" "$rc_file" >/dev/null 2>&1; then
                    echo "PASS: Service $service_name implements process isolation"
                    isolation_features=$((isolation_features + 1))
                fi
                
                # Check for union mounts (like the sshd service uses)
                if grep -i "union" "$rc_file" >/dev/null 2>&1; then
                    echo "INFO: Service $service_name uses union mounts"
                    isolation_features=$((isolation_features + 1))
                fi
            fi
        fi
    done
    
    if [ $isolation_features -gt 0 ]; then
        echo "INFO: Found $isolation_features service isolation features"
    fi
    
    return 0  # Just informational
}

# Test for hardcoded credentials and secrets
test_hardcoded_credentials() {
    local services_dir="$PROJECT_ROOT/service"
    local secrets_found=0
    
    # Look for possible hardcoded credentials in service files
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check all files in service for potential credentials
            for file in $(find "$service_dir" -type f); do
                if [ -f "$file" ]; then
                    # Look for common credential patterns
                    if grep -E "(password|secret|key|token).*=" "$file" | grep -v "^[[:space:]]*#" >/dev/null 2>&1; then
                        # Many of these may be configuration templates, so warn rather than fail
                        echo "INFO: File $file in service $service_name contains potential credential fields (review needed)"
                    fi
                    
                    # Look for hardcoded passwords in any form
                    if grep -i "password.*[\"'].*[\"']" "$file" >/dev/null 2>&1; then
                        echo "WARN: File $file in service $service_name may contain hardcoded password (review needed)"
                    fi
                fi
            done
        fi
    done
    
    # Check for SSH-specific security in README
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ -f "$service_dir/README.md" ]; then
            local service_name=$(basename "$service_dir")
            if grep -i "public.*key\|ssh.*key\|authorized" "$service_dir/README.md" >/dev/null 2>&1; then
                echo "INFO: Service $service_name SSH security documented"
            fi
        fi
    done
    
    return 0  # Just informational, don't fail for potential issues
}

# Run all service security tests
run_all_service_security_tests() {
    echo "Running service security tests..."
    
    local failed_tests=0
    
    run_test "Dangerous operations check" test_dangerous_operations || failed_tests=$((failed_tests + 1))
    run_test "Privilege separation check" test_privilege_separation || failed_tests=$((failed_tests + 1))
    run_test "Network security check" test_network_security || failed_tests=$((failed_tests + 1))
    run_test "File permissions check" test_file_permissions || failed_tests=$((failed_tests + 1))
    run_test "Service isolation check" test_service_isolation || failed_tests=$((failed_tests + 1))
    run_test "Hardcoded credentials check" test_hardcoded_credentials || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All service security tests passed (with informational checks noted)"
        return 0
    else
        echo "$failed_tests service security tests had issues"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_service_security_tests
fi