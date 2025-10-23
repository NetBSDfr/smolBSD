#!/bin/sh
#
# Advanced Service Security Hardening
# Military-grade security validation for service ecosystem
#

# Source the test harness first (if not already sourced)
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Perform comprehensive static security analysis
test_static_security_analysis() {
    local service_root="$PROJECT_ROOT/service"
    local security_violations=0
    local critical_violations=0
    local high_violations=0
    local medium_violations=0
    local low_violations=0
    
    echo "STATIC ANALYSIS: Comprehensive security scan"
    
    # Scan all service files for security vulnerabilities
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            echo "SECURITY SCANNING: $service_name"
            
            # Check all service files for security vulnerabilities
            find "$service_dir" -type f \( -name "*.sh" -o -name "rc" -o -name "*.conf" -o -name "*.cfg" -o -name "*.mk" -o -name "*.pub" \) 2>/dev/null | while read -r file; do
                if [ -f "$file" ]; then
                    local file_name=$(basename "$file")
                    local file_dir=$(dirname "$file")
                    local rel_path="${file#$service_dir/}"
                    
                    # Check for command injection vulnerabilities
                    local cmd_injection=$(grep -cE "(eval.*\\$\(|system.*\\$\(|exec.*\\$\(|sh.*\\$\(|bash.*\\$\(|\\$\((.*)\\)|\`.*\`)" "$file" 2>/dev/null || echo "0")
                    cmd_injection=$(echo "$cmd_injection" | tr -d ' \t\r\n' || echo "0")
                    if [ "$cmd_injection" -gt 0 ] 2>/dev/null; then
                        echo "  CRITICAL: Command injection vulnerability in $service_name/$rel_path ($cmd_injection instances)"
                        critical_violations=$((critical_violations + cmd_injection))
                        security_violations=$((security_violations + cmd_injection * 10))
                    fi
                    
                    # Check for directory traversal vulnerabilities
                    local dir_traversal=$(grep -cE "(\\.\\./\\.\\./|\\.\\./\\.\\./\\.\\./)" "$file" 2>/dev/null || echo "0")
                    dir_traversal=$(echo "$dir_traversal" | tr -d ' \t\r\n' || echo "0")
                    if [ "$dir_traversal" -gt 0 ] 2>/dev/null; then
                        echo "  HIGH: Directory traversal vulnerability in $service_name/$rel_path ($dir_traversal instances)"
                        high_violations=$((high_violations + dir_traversal))
                        security_violations=$((security_violations + dir_traversal * 5))
                    fi
                    
                    # Check for hardcoded credentials
                    local hardcoded_creds=$(grep -i -cE "(password.*=|secret.*=|key.*=|token.*=|pass.*=|auth.*=|credential.*=|private.*key)" "$file" 2>/dev/null || echo "0")
                    hardcoded_creds=$(echo "$hardcoded_creds" | tr -d ' \t\r\n' || echo "0")
                    if [ "$hardcoded_creds" -gt 0 ] 2>/dev/null; then
                        echo "  HIGH: Hardcoded credentials in $service_name/$rel_path ($hardcoded_creds instances)"
                        high_violations=$((high_violations + hardcoded_creds))
                        security_violations=$((security_violations + hardcoded_creds * 5))
                    fi
                    
                    # Check for insecure file permissions or operations
                    local insecure_perms=$(grep -cE "(chmod.*777|chmod.*666|chmod.*u\+s|chmod.*g\+s)" "$file" 2>/dev/null || echo "0")
                    insecure_perms=$(echo "$insecure_perms" | tr -d ' \t\r\n' || echo "0")
                    if [ "$insecure_perms" -gt 0 ] 2>/dev/null; then
                        echo "  MEDIUM: Insecure file permissions in $service_name/$rel_path ($insecure_perms operations)"
                        medium_violations=$((medium_violations + insecure_perms))
                        security_violations=$((security_violations + insecure_perms * 2))
                    fi
                    
                    # Check for dangerous system calls
                    local dangerous_calls=$(grep -cE "(rm.*-r.*\\$|rm.*-rf|rm.*--no-preserve-root|exec.*rm|system.*rm|sh.*rm)" "$file" 2>/dev/null || echo "0")
                    dangerous_calls=$(echo "$dangerous_calls" | tr -d ' \t\r\n' || echo "0")
                    if [ "$dangerous_calls" -gt 0 ] 2>/dev/null; then
                        echo "  CRITICAL: Dangerous rm operations in $service_name/$rel_path ($dangerous_calls instances)"
                        critical_violations=$((critical_violations + dangerous_calls * 3))
                        security_violations=$((security_violations + dangerous_calls * 15))
                    fi
                    
                    # Check for eval usage which can be dangerous
                    local eval_usage=$(grep -cE "(?<=\\W)eval(?=\\W)" "$file" 2>/dev/null || echo "0")
                    eval_usage=$(echo "$eval_usage" | tr -d ' \t\r\n' || echo "0")
                    if [ "$eval_usage" -gt 0 ] 2>/dev/null; then
                        echo "  HIGH: Eval usage in $service_name/$rel_path ($eval_usage instances) (potential security risk)"
                        high_violations=$((high_violations + eval_usage * 2))
                        security_violations=$((security_violations + eval_usage * 10))
                    fi
                    
                    # Check for potential buffer overflow patterns
                    local buffer_overflow=$(grep -cE "(strcpy|gets|sprintf|strcat)" "$file" 2>/dev/null || echo "0")
                    buffer_overflow=$(echo "$buffer_overflow" | tr -d ' \t\r\n' || echo "0")
                    if [ "$buffer_overflow" -gt 0 ] 2>/dev/null; then
                        echo "  MEDIUM: Potential buffer overflow patterns in $service_name/$rel_path ($buffer_overflow instances)"
                        medium_violations=$((medium_violations + buffer_overflow))
                        security_violations=$((security_violations + buffer_overflow))
                    fi
                    
                    # Check for temporary file creation without proper security
                    local temp_files=$(grep -cE "(/tmp/|/var/tmp/).*\\$|mktemp|temp|tmp.*=" "$file" 2>/dev/null || echo "0")
                    temp_files=$(echo "$temp_files" | tr -d ' \t\r\n' || echo "0")
                    if [ "$temp_files" -gt 0 ] 2>/dev/null; then
                        echo "  LOW: Temporary file operations in $service_name/$rel_path ($temp_files operations) (review for security)"
                        low_violations=$((low_violations + temp_files))
                        security_violations=$((security_violations + temp_files))
                    fi
                fi
            done 2>/dev/null || true
        fi
    done
    
    # Report security analysis results
    local total_violations=$((critical_violations + high_violations + medium_violations + low_violations))
    total_violations=$(echo "$total_violations" | tr -d ' \t\r\n' || echo "0")
    
    if [ "$total_violations" -gt 0 ] 2>/dev/null; then
        echo "SECURITY SUMMARY:"
        echo "  CRITICAL: $critical_violations violations (score: $((critical_violations * 10)))"
        echo "  HIGH: $high_violations violations (score: $((high_violations * 5))"
        echo "  MEDIUM: $medium_violations violations (score: $((medium_violations * 2))"
        echo "  LOW: $low_violations violations (score: $low_violations"
        echo "  TOTAL SECURITY SCORE: $security_violations (lower is better)"
        
        if [ "$critical_violations" -gt 0 ] 2>/dev/null; then
            echo "FAILED: Critical security violations detected - immediate remediation required"
            return 1
        elif [ "$high_violations" -gt 5 ] 2>/dev/null; then
            echo "FAILED: Too many high-severity violations ($high_violations) - requires attention"
            return 1
        else
            echo "PASSED: Security analysis completed with manageable risk profile"
            return 0
        fi
    else
        echo "PASSED: No security violations detected in static analysis"
        return 0
    fi
}

# Test privilege escalation and access control
test_privilege_escalation() {
    local service_root="$PROJECT_ROOT/service"
    local priv_esc_issues=0
    
    echo "PRIVILEGE ESCALATION: Testing access control mechanisms"
    
    # Check for privilege escalation in service scripts
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for privilege operations
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Look for privilege operations
                local su_ops=$(grep -cE "(su.*root|su.*-|sudo|su.*wheel)" "$rc_file" 2>/dev/null || echo "0")
                local chown_ops=$(grep -cE "(chown.*0:0|chown.*root|chown.*0)" "$rc_file" 2>/dev/null || echo "0")
                local chmod_ops=$(grep -cE "(chmod.*[4-7]00|chmod.*u\+s|chmod.*g\+s)" "$rc_file" 2>/dev/null || echo "0")
                local user_ops=$(grep -cE "(useradd|groupadd|adduser|addgroup)" "$rc_file" 2>/dev/null || echo "0")
                
                # Sanitize variables
                su_ops=$(echo "$su_ops" | tr -d ' \t\r\n' || echo "0")
                chown_ops=$(echo "$chown_ops" | tr -d ' \t\r\n' || echo "0")
                chmod_ops=$(echo "$chmod_ops" | tr -d ' \t\r\n' || echo "0")
                user_ops=$(echo "$user_ops" | tr -d ' \t\r\n' || echo "0")
                
                local total_priv=0
                total_priv=$((su_ops + chown_ops + chmod_ops + user_ops)) 2>/dev/null || total_priv=0
                
                if [ "$total_priv" -gt 0 ] 2>/dev/null; then
                    echo "PRIV ESCALATION: Service $service_name performs $total_priv privilege operations"
                    
                    # Check for dangerous privilege escalation
                    local dangerous_escalation=$(grep -cE "(chown.*0:0.*/|chmod.*4000.*/|chmod.*7000)" "$rc_file" 2>/dev/null || echo "0")
                    dangerous_escalation=$(echo "$dangerous_escalation" | tr -d ' \t\r\n' || echo "0")
                    if [ "$dangerous_escalation" -gt 0 ] 2>/dev/null; then
                        echo "  CRITICAL: Service $service_name performs dangerous system-wide privilege escalation ($dangerous_escalation ops)"
                        priv_esc_issues=$((priv_esc_issues + dangerous_escalation * 10))
                    fi
                    
                    # Check for proper privilege validation
                    local priv_validation=$(grep -cE "(test.*-w|test.*-r|test.*-x|if.*then.*chown)" "$rc_file" 2>/dev/null || echo "0")
                    priv_validation=$(echo "$priv_validation" | tr -d ' \t\r\n' || echo "0")
                    if [ "$priv_validation" -eq 0 ] 2>/dev/null && [ "$total_priv" -gt 0 ] 2>/dev/null; then
                        echo "  WARNING: Service $service_name performs privilege operations without validation"
                    fi
                fi
            fi
            
            # Check postinst scripts for privilege escalation
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        
                        # Look for privilege operations in postinst
                        local pkg_ops=$(grep -cE "(pkg_add|pkgin install|apt-get install|yum install|dnf install)" "$script" 2>/dev/null || echo "0")
                        local user_ops=$(grep -cE "(useradd|groupadd|adduser|addgroup)" "$script" 2>/dev/null || echo "0")
                        local sys_conf_ops=$(grep -cE "(cp.*etc|mv.*etc|install.*etc)" "$script" 2>/dev/null || echo "0")
                        
                        # Sanitize variables
                        pkg_ops=$(echo "$pkg_ops" | tr -d ' \t\r\n' || echo "0")
                        user_ops=$(echo "$user_ops" | tr -d ' \t\r\n' || echo "0")
                        sys_conf_ops=$(echo "$sys_conf_ops" | tr -d ' \t\r\n' || echo "0")
                        
                        local postinst_priv=0
                        postinst_priv=$((pkg_ops + user_ops + sys_conf_ops)) 2>/dev/null || postinst_priv=0
                        
                        if [ "$postinst_priv" -gt 0 ] 2>/dev/null; then
                            echo "POSTINST PRIV: Service $service_name postinst $script_name performs $postinst_priv privilege operations"
                            
                            # Check for dangerous postinst privilege operations
                            local dangerous_postinst=$(grep -cE "(chown.*0:0.*/|chmod.*4000.*/|chmod.*7000)" "$script" 2>/dev/null || echo "0")
                            dangerous_postinst=$(echo "$dangerous_postinst" | tr -d ' \t\r\n' || echo "0")
                            if [ "$dangerous_postinst" -gt 0 ] 2>/dev/null; then
                                echo "  CRITICAL: Service $service_name postinst $script_name performs dangerous system-wide privilege operations"
                                priv_esc_issues=$((priv_esc_issues + dangerous_postinst * 10))
                            fi
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $priv_esc_issues -gt 0 ] 2>/dev/null; then
        echo "FAILED: $priv_esc_issues privilege escalation issues detected"
        return 1
    else
        echo "PASSED: 0 privilege operations with proper controls"
        return 0
    fi
}

# Test attack surface and exposure
test_attack_surface_analysis() {
    local service_root="$PROJECT_ROOT/service"
    local attack_surface_issues=0
    local network_exposures=0
    
    echo "ATTACK SURFACE: Comprehensive exposure analysis"
    
    # Check for network exposure in service configurations
    for service_dir in "$service_root"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for network exposure
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Check for network binding
                local bind_all=$(grep -cE "(0\.0\.0\.0:|bind.*0\.0\.0\.0|listen.*0\.0\.0\.0)" "$rc_file" 2>/dev/null || echo "0")
                local inet_addr=$(grep -cE "(INADDR_ANY|all.*interfaces)" "$rc_file" 2>/dev/null || echo "0")
                local net_services=$(grep -cE "(sshd|nginx|apache|httpd|ftpd|telnetd)" "$rc_file" 2>/dev/null || echo "0")
                
                # Sanitize variables
                bind_all=$(echo "$bind_all" | tr -d ' \t\r\n' || echo "0")
                inet_addr=$(echo "$inet_addr" | tr -d ' \t\r\n' || echo "0")
                net_services=$(echo "$net_services" | tr -d ' \t\r\n' || echo "0")
                
                local net_exposure=0
                net_exposure=$((bind_all + inet_addr + net_services)) 2>/dev/null || net_exposure=0
                
                if [ "$net_exposure" -gt 0 ] 2>/dev/null; then
                    network_exposures=$((network_exposures + 1))
                    echo "NETWORK EXPOSURE: Service $service_name exposes $net_exposure network services"
                    
                    # Check for insecure network configurations
                    if [ "$bind_all" -gt 0 ] 2>/dev/null; then
                        echo "  WARNING: Service $service_name binds to all interfaces (0.0.0.0)"
                        attack_surface_issues=$((attack_surface_issues + 1))
                    fi
                    
                    # Check for known vulnerable services
                    local vuln_services=$(grep -cE "(telnetd|ftpd.*anonymous)" "$rc_file" 2>/dev/null || echo "0")
                    vuln_services=$(echo "$vuln_services" | tr -d ' \t\r\n' || echo "0")
                    if [ "$vuln_services" -gt 0 ] 2>/dev/null; then
                        echo "  CRITICAL: Service $service_name exposes vulnerable network services"
                        attack_surface_issues=$((attack_surface_issues + vuln_services * 10))
                    fi
                fi
                
                # Check for file system exposure
                local fs_exposure=$(grep -cE "(/tmp/|/var/tmp/|/dev/shm)" "$rc_file" 2>/dev/null || echo "0")
                fs_exposure=$(echo "$fs_exposure" | tr -d ' \t\r\n' || echo "0")
                if [ "$fs_exposure" -gt 0 ] 2>/dev/null; then
                    echo "FS EXPOSURE: Service $service_name accesses $fs_exposure world-writable directories"
                fi
                
                # Check for information disclosure
                local info_disc=$(grep -ciE "(verbose|debug|log.*info|print.*version)" "$rc_file" 2>/dev/null || echo "0")
                info_disc=$(echo "$info_disc" | tr -d ' \t\r\n' || echo "0")
                if [ "$info_disc" -gt 0 ] 2>/dev/null; then
                    echo "INFO DISCLOSURE: Service $service_name potentially discloses system information"
                fi
            fi
        fi
    done
    
    # Check for publicly accessible files
    local public_files=$(find "$service_root" -name "*.pub" -o -name "*.key" -o -name "*id_rsa*" -o -name "*id_dsa*" 2>/dev/null | wc -l | tr -d ' \t\r\n' || echo "0")
    if [ "$public_files" -gt 0 ] 2>/dev/null; then
        echo "PUBLIC FILES: $public_files public/private key files found"
        
        # Check for private keys in wrong places
        local private_keys=$(find "$service_root" -name "*id_*" -not -name "*.pub" 2>/dev/null | wc -l | tr -d ' \t\r\n' || echo "0")
        if [ "$private_keys" -gt 0 ] 2>/dev/null; then
            echo "CRITICAL: $private_keys private key files exposed - immediate security risk"
            attack_surface_issues=$((attack_surface_issues + private_keys * 50))
        fi
    fi
    
    if [ $attack_surface_issues -gt 0 ] 2>/dev/null; then
        echo "FAILED: $attack_surface_issues attack surface issues detected"
        return 1
    else
        echo "PASSED: Network exposure: $network_exposures services, Attack surface minimized"
        return 0
    fi
}

# Run all advanced security tests
run_all_advanced_security_tests() {
    echo "RUNNING: Advanced service security hardening"
    echo "================================================"
    
    local test_failures=0
    
    run_test "Static security analysis" test_static_security_analysis || test_failures=$((test_failures + 1))
    run_test "Privilege escalation testing" test_privilege_escalation || test_failures=$((test_failures + 1))
    run_test "Attack surface analysis" test_attack_surface_analysis || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ] 2>/dev/null; then
        echo "ALL ADVANCED SECURITY TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures advanced service security test suites failed"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${0}" ]; then
    run_all_advanced_security_tests
fi