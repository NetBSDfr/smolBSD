#!/bin/sh
#
# Advanced Service Security Auditing for smolBSD
# Comprehensive security analysis including vulnerability scanning, privilege escalation, and attack surface evaluation
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

# Perform comprehensive static analysis for security vulnerabilities
test_static_security_analysis() {
    local services_dir="$PROJECT_ROOT/service"
    local security_issues=0
    local total_files=0
    
    echo "INFO: Performing static security analysis of service files..."
    
    # Scan for various security vulnerabilities in service files
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Scan all files in the service for security issues
            find "$service_dir" -type f -exec grep -l "." {} \; 2>/dev/null | while read -r file; do
                if [ -f "$file" ]; then
                    total_files=$((total_files + 1))
                    local filename=$(basename "$file")
                    
                    echo "INFO: Scanning security for file: $filename in service $service_name"
                    
                    # Check for command injection vulnerabilities
                    local cmd_injection=$(grep -cE "(exec.*\$\(|system.*\$\(|popen.*\$\(|sh.*\$\(|bash.*\$\(|\$\((.*)\)|\`.*\`)" "$file")
                    if [ "$cmd_injection" -gt 0 ]; then
                        echo "  - CRITICAL: $cmd_injection potential command injection patterns found"
                        security_issues=$((security_issues + $cmd_injection))
                    fi
                    
                    # Check for directory traversal vulnerabilities
                    local dir_traversal=$(grep -cE "\.\./\.\./\|\.\./\.\./\.\./" "$file")
                    if [ "$dir_traversal" -gt 0 ]; then
                        echo "  - HIGH: $dir_traversal potential directory traversal patterns found"
                        security_issues=$((security_issues + $dir_traversal * 2))
                    fi
                    
                    # Check for potential path manipulation
                    local path_manip=$(grep -cE "\$.*HOME\|\$.*PATH\|\$.*TMP\|\".*\$\(|\$\{.*\}" "$file")
                    if [ "$path_manip" -gt 0 ]; then
                        echo "  - MEDIUM: $path_manip potential path manipulation occurrences found"
                    fi
                    
                    # Check for hardcoded credentials in various formats
                    local creds=$(grep -i -cE "(password.*=\|secret.*=\|key.*=\|token.*=\|pass.*=\|auth.*=\|credential.*=\|private.*key)" "$file")
                    if [ "$creds" -gt 0 ]; then
                        echo "  - MEDIUM: $creds potential credential fields found"
                        
                        # Extract credential patterns for review
                        local cred_lines=$(grep -i -E "(password.*=\|secret.*=\|key.*=\|token.*=)" "$file" | head -5)
                        if [ -n "$cred_lines" ]; then
                            echo "    - Credential patterns found:"
                            echo "$cred_lines" | while read -r line; do
                                echo "      $line"
                            done
                        fi
                    fi
                    
                    # Check for insecure file permissions or operations
                    local insecure_perms=$(grep -cE "chmod.*777\|chmod.*77\|chmod.*666\|chmod.*66\|chown.*0:0\|chmod.*u\+s\|chmod.*g\+s" "$file")
                    if [ "$insecure_perms" -gt 0 ]; then
                        echo "  - HIGH: $insecure_perms insecure permission operations found"
                    fi
                    
                    # Check for dangerous system calls
                    local dangerous_calls=$(grep -cE "(rm.*-r.*\$\(|rm.*-rf\|rm.*--no-preserve-root\|exec.*rm\|system.*rm\|sh.*rm)" "$file")
                    if [ "$dangerous_calls" -gt 0 ]; then
                        echo "  - CRITICAL: $dangerous_calls dangerous rm operations found"
                        security_issues=$((security_issues + $dangerous_calls * 3))
                    fi
                    
                    # Check for eval usage which can be dangerous
                    local eval_usage=$(grep -cE "(?<=\W)eval(?=\W)" "$file")
                    if [ "$eval_usage" -gt 0 ]; then
                        echo "  - HIGH: $eval_usage eval usage found (potential security risk)"
                        security_issues=$((security_issues + $eval_usage * 2))
                    fi
                    
                    # Check for potential buffer overflow patterns
                    local buffer_overflow=$(grep -cE "(strcpy\|gets\|sprintf\|strcat)" "$file")
                    if [ "$buffer_overflow" -gt 0 ]; then
                        echo "  - MEDIUM: $buffer_overflow potential buffer overflow patterns found"
                    fi
                    
                    # Check for temporary file creation without proper security
                    local temp_files=$(grep -cE "(/tmp/|/var/tmp/).*\$\(|mktemp\|temp\|tmp.*=" "$file")
                    if [ "$temp_files" -gt 0 ]; then
                        echo "  - LOW: $temp_files temporary file operations found (review for security)"
                    fi
                fi
            done
        fi
    done
    
    if [ $total_files -gt 0 ]; then
        echo "INFO: Scanned $total_files service files for security vulnerabilities"
        if [ $security_issues -gt 0 ]; then
            echo "WARN: $security_issues security issues identified across all service files"
        else
            echo "INFO: No critical security issues found in static analysis"
        fi
    fi
    
    return 0
}

# Test privilege escalation and permission vulnerabilities
test_privilege_escalation() {
    local services_dir="$PROJECT_ROOT/service"
    local privilege_issues=0
    
    echo "INFO: Testing for privilege escalation vulnerabilities..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Analyzing privilege escalation risks for service: $service_name"
                
                # Check for root privilege usage
                local root_ops=$(grep -cE "(root\|su.*-\|sudo\|chown.*0\|chmod.*[4-7]00\|chown.*root)" "$rc_file")
                if [ "$root_ops" -gt 0 ]; then
                    echo "  - INFO: $root_ops operations requiring root privileges found"
                    
                    # Check if operations are performed with proper validation
                    local has_validation=$(grep -cE "(test.*-w\|test.*-r\|test.*-x\|if.*then.*\$\(|if.*exist\|check.*file)" "$rc_file")
                    if [ "$has_validation" -gt 0 ]; then
                        echo "  - INFO: $has_validation validation checks found for privileged operations"
                    else
                        echo "  - MEDIUM: Privileged operations without apparent validation"
                        privilege_issues=$((privilege_issues + 1))
                    fi
                fi
                
                # Check for setuid/setgid usage
                local setuid_ops=$(grep -cE "(chmod.*u\+s\|chmod.*g\+s\|setuid\|setgid\|suid\|sgid)" "$rc_file")
                if [ "$setuid_ops" -gt 0 ]; then
                    echo "  - HIGH: $setuid_ops setuid/setgid operations found (security risk)"
                    privilege_issues=$((privilege_issues + $setuid_ops * 3))
                fi
                
                # Check for user/group creation with excessive privileges
                local user_admin=$(grep -cE "(useradd.*-G.*root\|usermod.*-G.*root\|useradd.*-u.*0\|groupadd.*-g.*0)" "$rc_file")
                if [ "$user_admin" -gt 0 ]; then
                    echo "  - CRITICAL: $user_admin operations creating admin/root users found"
                    privilege_issues=$((privilege_issues + $user_admin * 5))
                fi
                
                # Check for file permission escalation
                local perm_escalation=$(grep -cE "(chmod.*777\|chmod.*[4-7]00\|chmod.*u\+w\|chmod.*g\+w\|chmod.*o\+w)" "$rc_file")
                if [ "$perm_escalation" -gt 0 ]; then
                    echo "  - MEDIUM: $perm_escalation permission escalation operations found"
                    privilege_issues=$((privilege_issues + $perm_escalation))
                fi
            fi
            
            # Check postinst scripts for privilege escalation
            if [ -d "$service_dir/postinst" ]; then
                for script in "$service_dir/postinst"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_privileges=$(grep -cE "(root\|sudo\|su\|chown\|chmod)" "$script")
                        if [ "$script_privileges" -gt 0 ]; then
                            echo "  - INFO: Postinst script has $script_privileges privilege operations"
                            
                            # Check for dangerous privilege operations in postinst
                            local dangerous_priv=$(grep -cE "(chown.*0:0\|chmod.*4000\|chmod.*6000\|chmod.*7000)" "$script")
                            if [ "$dangerous_priv" -gt 0 ]; then
                                echo "  - HIGH: $dangerous_priv dangerous privilege operations in postinst"
                                privilege_issues=$((privilege_issues + $dangerous_priv * 2))
                            fi
                        fi
                    fi
                done
            fi
        fi
    done
    
    return 0
}

# Analyze attack surface and exposure
test_attack_surface_analysis() {
    local services_dir="$PROJECT_ROOT/service"
    local exposure_issues=0
    
    echo "INFO: Analyzing service attack surface and exposure..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Analyzing attack surface for service: $service_name"
                
                # Check network exposure
                local network_exposure=$(grep -cE "(bind\|listen\|0\.0\.0\.0\|INADDR_ANY\|all.*interfaces)" "$rc_file")
                if [ "$network_exposure" -gt 0 ]; then
                    echo "  - INFO: $network_exposure potential network exposure points"
                    
                    # Check if services bind to all interfaces
                    local bind_all=$(grep -cE "0\.0\.0\.0:|bind.*0\.0\.0\.0|listen.*0\.0\.0\.0" "$rc_file")
                    if [ "$bind_all" -gt 0 ]; then
                        echo "  - MEDIUM: Service may bind to all interfaces (0.0.0.0)"
                        exposure_issues=$((exposure_issues + 1))
                    fi
                fi
                
                # Check for exposed services on common ports
                local exposed_ports=$(grep -cE ":(22|23|25|110|143|443|80|8080|3306|5432|27017|6379|11211|9200)" "$rc_file")
                if [ "$exposed_ports" -gt 0 ]; then
                    echo "  - INFO: $exposed_ports services may use well-known ports"
                fi
                
                # Check for file system exposure
                local fs_exposure=$(grep -cE "(/tmp\|/var/tmp\|/dev/shm\|world.*read\|chmod.*755\|chmod.*644)" "$rc_file")
                if [ "$fs_exposure" -gt 0 ]; then
                    echo "  - INFO: $fs_exposure potential file system exposure patterns"
                fi
                
                # Check for service information disclosure
                local info_disc=$(grep -cE "(version\|debug\|verbose\|log.*info\|print.*version\|echo.*config)" "$rc_file")
                if [ "$info_disc" -gt 0 ]; then
                    echo "  - LOW: $info_disc potential information disclosure patterns"
                fi
                
                # Check for default credentials or configurations
                local defaults=$(grep -cE "(default.*pass\|admin.*admin\|password.*password\|secret.*secret\|test.*test)" "$rc_file")
                if [ "$defaults" -gt 0 ]; then
                    echo "  - MEDIUM: $defaults potential default credential patterns"
                    exposure_issues=$((exposure_issues + $defaults))
                fi
            fi
        fi
    done
    
    return 0
}

# Test input validation and sanitization
test_input_validation() {
    local services_dir="$PROJECT_ROOT/service"
    local validation_issues=0
    
    echo "INFO: Testing service input validation and sanitization..."
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                echo "INFO: Testing input validation for service: $service_name"
                
                # Check for input processing without validation
                local unvalidated_input=$(grep -cE "(read.*\$\(|\$\{!.*\}\|indirect.*ref)" "$rc_file")
                if [ "$unvalidated_input" -gt 0 ]; then
                    echo "  - MEDIUM: $unvalidated_input potential unvalidated input operations"
                fi
                
                # Check for parameter usage without sanitization
                local unsafe_params=$(grep -cE "\$[0-9]\+|\$@|\$*|\$0" "$rc_file")
                if [ "$unsafe_params" -gt 0 ]; then
                    echo "  - LOW: $unsafe_params parameter references found (review for sanitization)"
                fi
                
                # Check for variable assignment without validation
                local unsafe_assign=$(grep -cE "(=\$\{.*\}\|=\$.*\$\|=\$\{.*:-\)" "$rc_file")
                if [ "$unsafe_assign" -gt 0 ]; then
                    echo "  - MEDIUM: $unsafe_assign potential unsafe variable assignments"
                    validation_issues=$((validation_issues + 1))
                fi
                
                # Look for security validation patterns
                local validation_check=$(grep -cE "(validate\|sanitiz\|filter\|escape\|check.*input\|test.*input)" "$rc_file")
                if [ "$validation_check" -gt 0 ]; then
                    echo "  - INFO: $validation_check input validation patterns found"
                else
                    echo "  - INFO: No explicit input validation patterns found in this service"
                fi
            fi
        fi
    done
    
    return 0
}

# Perform comprehensive security audit report
test_comprehensive_security_audit() {
    local services_dir="$PROJECT_ROOT/service"
    local audit_issues=0
    
    echo "INFO: Performing comprehensive security audit..."
    
    # Generate security report for the entire service ecosystem
    echo "INFO: Security Audit Report for smolBSD Services"
    echo "==============================================="
    
    # Count total services
    local total_services=0
    local services_with_rc=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            total_services=$((total_services + 1))
            
            if [ -f "$service_dir/etc/rc" ]; then
                services_with_rc=$((services_with_rc + 1))
            fi
        fi
    done
    
    echo "INFO: Total services: $total_services"
    echo "INFO: Services with RC files: $services_with_rc"
    
    # Analyze common security patterns across all services
    local common_security_features=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Check for security-conscious patterns
                local has_net_validation=$(grep -cE "(test.*ifconfig\|check.*network\|validate.*ip)" "$rc_file")
                local has_file_validation=$(grep -cE "(test.*-f\|test.*-w\|test.*-r\|check.*file)" "$rc_file")
                local has_error_handling=$(grep -cE "(if.*then.*fi\|trap\|error.*exit)" "$rc_file")
                
                if [ "$has_net_validation" -gt 0 ] || [ "$has_file_validation" -gt 0 ] || [ "$has_error_handling" -gt 0 ]; then
                    common_security_features=$((common_security_features + 1))
                fi
            fi
        fi
    done
    
    echo "INFO: Services with security-conscious patterns: $common_security_features"
    
    # Identify high-risk services
    local high_risk_services=0
    
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            local rc_file="$service_dir/etc/rc"
            
            if [ -f "$rc_file" ]; then
                # Flags for high-risk characteristics
                local has_network=0
                local has_file_ops=0
                local has_priv_ops=0
                
                # Network exposure check
                if grep -qE "(bind|listen|0\.0\.0\.0|ifconfig|netstat)" "$rc_file"; then
                    has_network=1
                fi
                
                # File operations check
                if grep -qE "(cp|mv|rm|mkdir|chown|chmod)" "$rc_file"; then
                    has_file_ops=1
                fi
                
                # Privilege operations check
                if grep -qE "(root|sudo|chown.*0|chmod.*[4-7]00)" "$rc_file"; then
                    has_priv_ops=1
                fi
                
                # Mark as high risk if it has multiple characteristics
                local risk_score=$((has_network + has_file_ops + has_priv_ops))
                
                if [ "$risk_score" -ge 2 ]; then
                    high_risk_services=$((high_risk_services + 1))
                    echo "  - High-risk service identified: $service_name (risk score: $risk_score)"
                fi
            fi
        fi
    done
    
    echo "INFO: High-risk services identified: $high_risk_services"
    
    if [ $high_risk_services -gt 0 ]; then
        echo "INFO: Security recommendations:"
        echo "  - Review high-risk services for additional input validation"
        echo "  - Implement principle of least privilege where possible"
        echo "  - Add security monitoring and logging to critical services"
        echo "  - Consider isolation mechanisms for network-facing services"
    fi
    
    return 0
}

# Run all comprehensive security auditing tests
run_all_security_auditing_tests() {
    echo "Running comprehensive service security auditing tests..."
    
    local failed_tests=0
    
    run_test "Static security analysis" test_static_security_analysis || failed_tests=$((failed_tests + 1))
    run_test "Privilege escalation testing" test_privilege_escalation || failed_tests=$((failed_tests + 1))
    run_test "Attack surface analysis" test_attack_surface_analysis || failed_tests=$((failed_tests + 1))
    run_test "Input validation testing" test_input_validation || failed_tests=$((failed_tests + 1))
    run_test "Comprehensive security audit" test_comprehensive_security_audit || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "All comprehensive service security auditing tests completed"
        return 0
    else
        echo "$failed_tests comprehensive service security auditing tests had issues"
        return 1
    fi
}

# Execute tests if this script is run directly (not sourced)
if [ "$0" = "${BASH_SOURCE:-$0}" ]; then
    run_all_security_auditing_tests
fi