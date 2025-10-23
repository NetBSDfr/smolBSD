#!/bin/sh
#
# Comprehensive Service Testing Suite
# Groups all service tests for unified execution
#

# Source the test harness
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Test service configuration integrity and consistency
test_service_config_integrity() {
    echo "Testing service configuration integrity and consistency..."
    
    # Run the existing service config tests
    if sh "$PROJECT_ROOT/tests/test_service_config.sh"; then
        echo "PASS: Service configuration integrity validated"
        return 0
    else
        echo "FAIL: Service configuration integrity issues found"
        return 1
    fi
}

# Test service runtime behavior and execution
test_service_runtime_behavior() {
    echo "Testing service runtime behavior and execution..."
    
    # Run the existing service runtime tests
    if sh "$PROJECT_ROOT/tests/test_service_runtime.sh"; then
        echo "PASS: Service runtime behavior validated"
        return 0
    else
        echo "FAIL: Service runtime behavior issues found"
        return 1
    fi
}

# Test service integration with system components
test_service_system_integration() {
    echo "Testing service integration with system components..."
    
    # Run the existing service integration tests
    if sh "$PROJECT_ROOT/tests/test_service_integration.sh"; then
        echo "PASS: Service system integration validated"
        return 0
    else
        echo "FAIL: Service system integration issues found"
        return 1
    fi
}

# Test service security and hardening
test_service_security_hardening() {
    echo "Testing service security and hardening..."
    
    # Run the existing service security tests
    if sh "$PROJECT_ROOT/tests/test_service_security.sh"; then
        echo "PASS: Service security validated"
        return 0
    else
        echo "FAIL: Service security issues found"
        return 1
    fi
}

# Test enhanced service configuration
test_enhanced_service_config() {
    echo "Testing enhanced service configuration..."
    
    # Run the enhanced service config tests
    if sh "$PROJECT_ROOT/tests/test_service_config_enhanced.sh"; then
        echo "PASS: Enhanced service configuration validated"
        return 0
    else
        echo "FAIL: Enhanced service configuration issues found"
        return 1
    fi
}

# Test service dependencies and relationships
test_service_dependencies_relations() {
    echo "Testing service dependencies and relationships..."
    
    # Run the service dependency tests
    if sh "$PROJECT_ROOT/tests/test_service_dependencies.sh"; then
        echo "PASS: Service dependencies validated"
        return 0
    else
        echo "FAIL: Service dependency issues found"
        return 1
    fi
}

# Test service behavior patterns
test_service_behavior_patterns() {
    echo "Testing service behavior patterns..."
    
    # Run the service behavior tests
    if sh "$PROJECT_ROOT/tests/test_service_behavior.sh"; then
        echo "PASS: Service behavior patterns validated"
        return 0
    else
        echo "FAIL: Service behavior pattern issues found"
        return 1
    fi
}

# Test service compatibility and portability
test_service_compatibility_portability() {
    echo "Testing service compatibility and portability..."
    
    # Run the service compatibility tests
    if sh "$PROJECT_ROOT/tests/test_service_compatibility.sh"; then
        echo "PASS: Service compatibility validated"
        return 0
    else
        echo "FAIL: Service compatibility issues found"
        return 1
    fi
}

# Test service security audit
test_service_security_audit() {
    echo "Testing service security audit..."
    
    # Run the service security audit tests
    if sh "$PROJECT_ROOT/tests/test_service_security_audit.sh"; then
        echo "PASS: Service security audit validated"
        return 0
    else
        echo "FAIL: Service security audit issues found"
        return 1
    fi
}

# Test advanced service configuration
test_advanced_service_config() {
    echo "Testing advanced service configuration..."
    
    # Run the advanced service config tests
    if sh "$PROJECT_ROOT/tests/test_service_advanced_config.sh"; then
        echo "PASS: Advanced service configuration validated"
        return 0
    else
        echo "FAIL: Advanced service configuration issues found"
        return 1
    fi
}

# Test advanced service dependencies
test_advanced_service_deps() {
    echo "Testing advanced service dependencies..."
    
    # Run the advanced service dependency tests
    if sh "$PROJECT_ROOT/tests/test_service_advanced_deps.sh"; then
        echo "PASS: Advanced service dependencies validated"
        return 0
    else
        echo "FAIL: Advanced service dependency issues found"
        return 1
    fi
}

# Test advanced service behavior
test_advanced_service_behavior() {
    echo "Testing advanced service behavior..."
    
    # Run the advanced service behavior tests
    if sh "$PROJECT_ROOT/tests/test_service_advanced_behavior.sh"; then
        echo "PASS: Advanced service behavior validated"
        return 0
    else
        echo "FAIL: Advanced service behavior issues found"
        return 1
    fi
}

# Test advanced service security
test_advanced_service_security() {
    echo "Testing advanced service security..."
    
    # Run the advanced service security tests
    if sh "$PROJECT_ROOT/tests/test_service_advanced_security.sh"; then
        echo "PASS: Advanced service security validated"
        return 0
    else
        echo "FAIL: Advanced service security issues found"
        return 1
    fi
}

# Test advanced service integration
test_advanced_service_integration() {
    echo "Testing advanced service integration..."
    
    # Run the advanced service integration tests
    if sh "$PROJECT_ROOT/tests/test_service_advanced_integration.sh"; then
        echo "PASS: Advanced service integration validated"
        return 0
    else
        echo "FAIL: Advanced service integration issues found"
        return 1
    fi
}

# Run all comprehensive service tests
run_all_comprehensive_service_tests() {
    echo "RUNNING: Comprehensive service testing suite"
    echo "=========================================="
    
    local failed_tests=0
    
    run_test "Service configuration integrity" test_service_config_integrity || failed_tests=$((failed_tests + 1))
    run_test "Service runtime behavior" test_service_runtime_behavior || failed_tests=$((failed_tests + 1))
    run_test "Service system integration" test_service_system_integration || failed_tests=$((failed_tests + 1))
    run_test "Service security hardening" test_service_security_hardening || failed_tests=$((failed_tests + 1))
    run_test "Enhanced service configuration" test_enhanced_service_config || failed_tests=$((failed_tests + 1))
    run_test "Service dependencies and relations" test_service_dependencies_relations || failed_tests=$((failed_tests + 1))
    run_test "Service behavior patterns" test_service_behavior_patterns || failed_tests=$((failed_tests + 1))
    run_test "Service compatibility and portability" test_service_compatibility_portability || failed_tests=$((failed_tests + 1))
    run_test "Service security audit" test_service_security_audit || failed_tests=$((failed_tests + 1))
    run_test "Advanced service configuration" test_advanced_service_config || failed_tests=$((failed_tests + 1))
    run_test "Advanced service dependencies" test_advanced_service_deps || failed_tests=$((failed_tests + 1))
    run_test "Advanced service behavior" test_advanced_service_behavior || failed_tests=$((failed_tests + 1))
    run_test "Advanced service security" test_advanced_service_security || failed_tests=$((failed_tests + 1))
    run_test "Advanced service integration" test_advanced_service_integration || failed_tests=$((failed_tests + 1))
    
    if [ $failed_tests -eq 0 ]; then
        echo "🎉 ALL COMPREHENSIVE SERVICE TESTS PASSED"
        return 0
    else
        echo "💥 $failed_tests comprehensive service test suites failed"
        return 1
    fi
}

# Execute if run directly
if [ "$0" = "${0}" ]; then
    run_all_comprehensive_service_tests
fi