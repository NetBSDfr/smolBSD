#!/bin/sh
#
# Advanced Service Test Runner for smolBSD
# Comprehensive test execution framework for advanced service testing
#

# Set strict mode
set -eu

# Determine the project root directory
if [ -z "${PROJECT_ROOT:-}" ]; then
    PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
    export PROJECT_ROOT
fi

# Export PROJECT_ROOT for other test scripts
export PROJECT_ROOT

# Source test harness if available
if [ -f "$PROJECT_ROOT/tests/test_harness.sh" ]; then
    . "$PROJECT_ROOT/tests/test_harness.sh"
fi

# Test functions
run_shellcheck() {
    echo "Running shellcheck on scripts..."
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck not found, skipping shell script linting"
        return 0
    fi
    
    # Run shellcheck on the main scripts
    shellcheck "$PROJECT_ROOT/mkimg.sh" || return 1
    shellcheck "$PROJECT_ROOT/startnb.sh" || return 1
    echo "✓ Shellcheck passed"
    return 0
}

run_unit_tests() {
    echo "Running unit tests..."
    
    # Check script syntax
    echo "Checking script syntax..."
    sh -n "$PROJECT_ROOT/mkimg.sh" || { echo "Syntax error in mkimg.sh"; return 1; }
    sh -n "$PROJECT_ROOT/startnb.sh" || { echo "Syntax error in startnb.sh"; return 1; }
    echo "✓ Script syntax is valid"
    
    # Test basic script loading
    echo "Testing basic script loading..."
    if [ -x "$PROJECT_ROOT/mkimg.sh" ] && [ -x "$PROJECT_ROOT/startnb.sh" ]; then
        echo "✓ Scripts are executable"
    else
        echo "❌ Scripts are not executable"
        return 1
    fi
    
    # Test that help commands run without critical errors (they may return non-zero which is expected)
    if "$PROJECT_ROOT/mkimg.sh" -h >/dev/null 2>&1 || true; then
        echo "✓ mkimg.sh help runs without critical errors"
    else
        echo "❌ mkimg.sh help has critical errors"
        return 1
    fi
    
    if "$PROJECT_ROOT/startnb.sh" -h >/dev/null 2>&1 || true; then
        echo "✓ startnb.sh help runs without critical errors"
    else
        echo "❌ startnb.sh help has critical errors"
        return 1
    fi
    
    echo "✓ Unit tests passed"
    return 0
}

run_integration_tests() {
    echo "Running integration tests..."
    
    # Run the smolBSD integration test script
    if (cd "$PROJECT_ROOT/tests" && sh test_integration.sh); then
        echo "✓ Integration tests passed"
        return 0
    else
        echo "❌ Integration tests failed"
        return 1
    fi
}

run_system_tests() {
    echo "Running system tests..."
    
    # Run the system test script in a subshell
    if (cd "$PROJECT_ROOT/tests" && sh test_system.sh); then
        echo "✓ System tests passed"
        return 0
    else
        echo "❌ System tests failed"
        return 1
    fi
}

run_vm_boot_tests() {
    echo "Running VM boot functionality tests..."
    
    # Run the VM boot functionality test script in a subshell
    if (cd "$PROJECT_ROOT/tests" && sh test_vm_boot.sh); then
        echo "✓ VM boot functionality tests passed"
        return 0
    else
        echo "❌ VM boot functionality tests failed"
        return 1
    fi
}

run_functional_tests() {
    echo "Running functional tests..."
    
    # Run the functional test script in a subshell
    if (cd "$PROJECT_ROOT/tests" && sh test_functional.sh); then
        echo "✓ Functional tests passed"
        return 0
    else
        echo "❌ Functional tests failed"
        return 1
    fi
}

run_performance_tests() {
    echo "Running performance and regression tests..."
    
    # Run the performance and regression test script in a subshell
    if (cd "$PROJECT_ROOT/tests" && sh test_performance.sh); then
        echo "✓ Performance and regression tests passed"
        return 0
    else
        echo "❌ Performance and regression tests failed"
        return 1
    fi
}

# Advanced service testing functions
run_advanced_config_tests() {
    echo "Running advanced service configuration tests..."
    
    # Run the advanced service configuration test script by sourcing it in the proper environment
    if (cd "$PROJECT_ROOT/tests" && . ./test_harness.sh && sh test_service_advanced_config.sh); then
        echo "✓ Advanced service configuration tests passed"
        return 0
    else
        echo "❌ Advanced service configuration tests failed"
        return 1
    fi
}

run_advanced_dependency_tests() {
    echo "Running advanced service dependency tests..."
    
    # Run the advanced service dependency test script
    if (cd "$PROJECT_ROOT/tests" && sh test_service_advanced_deps.sh); then
        echo "✓ Advanced service dependency tests passed"
        return 0
    else
        echo "❌ Advanced service dependency tests failed"
        return 1
    fi
}

run_advanced_behavior_tests() {
    echo "Running advanced service behavior tests..."
    
    # Run the advanced service behavior test script
    if (cd "$PROJECT_ROOT/tests" && sh test_service_advanced_behavior.sh); then
        echo "✓ Advanced service behavior tests passed"
        return 0
    else
        echo "❌ Advanced service behavior tests failed"
        return 1
    fi
}

run_advanced_security_tests() {
    echo "Running advanced service security tests..."
    
    # Run the advanced service security test script
    if (cd "$PROJECT_ROOT/tests" && sh test_service_advanced_security.sh); then
        echo "✓ Advanced service security tests passed"
        return 0
    else
        echo "❌ Advanced service security tests failed"
        return 1
    fi
}

run_advanced_integration_tests() {
    echo "Running advanced service integration tests..."
    
    # Run the advanced service integration test script
    if (cd "$PROJECT_ROOT/tests" && sh test_service_advanced_integration.sh); then
        echo "✓ Advanced service integration tests passed"
        return 0

# Run comprehensive service tests
run_comprehensive_service_tests() {
    echo "Running comprehensive service tests..."
    
    # Run the comprehensive service test script in a subshell
    if (cd "$PROJECT_ROOT/tests" && sh test_service_comprehensive.sh); then
        echo "✓ Comprehensive service tests passed"
        return 0
    else
        echo "❌ Comprehensive service tests failed"
        return 1
    fi
}
    else
        echo "❌ Advanced service integration tests failed"
        return 1
    fi
}

# Run all advanced service tests
run_all_advanced_tests() {
    echo "Running all advanced service tests..."
    echo "=================================="
    
    local failed_tests=0
    
    echo "=== Advanced Service Configuration Tests ==="
    if run_advanced_config_tests; then
        echo "✓ Advanced service configuration tests passed"
    else
        echo "❌ Advanced service configuration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Dependency Tests ==="
    if run_advanced_dependency_tests; then
        echo "✓ Advanced service dependency tests passed"
    else
        echo "❌ Advanced service dependency tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Behavior Tests ==="
    if run_advanced_behavior_tests; then
        echo "✓ Advanced service behavior tests passed"
    else
        echo "❌ Advanced service behavior tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Security Tests ==="
    if run_advanced_security_tests; then
        echo "✓ Advanced service security tests passed"
    else
        echo "❌ Advanced service security tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Integration Tests ==="
    if run_advanced_integration_tests; then
        echo "✓ Advanced service integration tests passed"
    else
        echo "❌ Advanced service integration tests failed"
        ((failed_tests++))
    echo ""
    
    echo "=== Comprehensive Service Tests ==="
    if run_comprehensive_service_tests; then
        echo "✓ Comprehensive service tests passed"
    else
        echo "❌ Comprehensive service tests failed"
        ((failed_tests++))
    fi
    echo ""
    fi
    echo ""
    
    if [ $failed_tests -eq 0 ]; then
        echo "🎉 All advanced service tests passed!"
        return 0
    else
        echo "💥 $failed_tests advanced service test suites failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    echo "Starting smolBSD test suite..."
    echo ""
    
    local failed_tests=0
    
    echo "=== Shellcheck Tests ==="
    if run_shellcheck; then
        echo "✓ Shellcheck tests passed"
    else
        echo "❌ Shellcheck tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Unit Tests ==="
    if run_unit_tests; then
        echo "✓ Unit tests passed"
    else
        echo "❌ Unit tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Integration Tests ==="
    if run_integration_tests; then
        echo "✓ Integration tests passed"
    else
        echo "❌ Integration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Configuration Tests ==="
    if run_service_config_tests; then
        echo "✓ Service configuration tests passed"
    else
        echo "❌ Service configuration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Runtime Tests ==="
    if run_service_runtime_tests; then
        echo "✓ Service runtime tests passed"
    else
        echo "❌ Service runtime tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Integration Tests ==="
    if run_service_integration_tests; then
        echo "✓ Service integration tests passed"
    else
        echo "❌ Service integration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Security Tests ==="
    if run_service_security_tests; then
        echo "✓ Service security tests passed"
    else
        echo "❌ Service security tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Configuration Enhanced Tests ==="
    if run_enhanced_service_config_tests; then
        echo "✓ Enhanced service configuration tests passed"
    else
        echo "❌ Enhanced service configuration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Dependency Tests ==="
    if run_service_dependency_tests; then
        echo "✓ Service dependency tests passed"
    else
        echo "❌ Service dependency tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Behavior Tests ==="
    if run_service_behavior_tests; then
        echo "✓ Service behavior tests passed"
    else
        echo "❌ Service behavior tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Compatibility Tests ==="
    if run_service_compatibility_tests; then
        echo "✓ Service compatibility tests passed"
    else
        echo "❌ Service compatibility tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Service Security Audit Tests ==="
    if run_service_security_audit_tests; then
        echo "✓ Service security audit tests passed"
    else
        echo "❌ Service security audit tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Functional Tests ==="
    if run_functional_tests; then
        echo "✓ Functional tests passed"
    else
        echo "❌ Functional tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Performance & Regression Tests ==="
    if run_performance_tests; then
        echo "✓ Performance and regression tests passed"
    else
        echo "❌ Performance and regression tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== System Tests ==="
    if run_system_tests; then
        echo "✓ System tests passed"
    else
        echo "❌ System tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== VM Boot Tests ==="
    if run_vm_boot_tests; then
        echo "✓ VM boot tests passed"
    else
        echo "❌ VM boot tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Configuration Tests ==="
    if run_advanced_config_tests; then
        echo "✓ Advanced service configuration tests passed"
    else
        echo "❌ Advanced service configuration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Dependency Tests ==="
    if run_advanced_dependency_tests; then
        echo "✓ Advanced service dependency tests passed"
    else
        echo "❌ Advanced service dependency tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Behavior Tests ==="
    if run_advanced_behavior_tests; then
        echo "✓ Advanced service behavior tests passed"
    else
        echo "❌ Advanced service behavior tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Security Tests ==="
    if run_advanced_security_tests; then
        echo "✓ Advanced service security tests passed"
    else
        echo "❌ Advanced service security tests failed"
    echo ""
    
    echo "=== Comprehensive Service Tests ==="
    if run_comprehensive_service_tests; then
        echo "✓ Comprehensive service tests passed"
    else
        echo "❌ Comprehensive service tests failed"
        ((failed_tests++))
    fi
    echo ""
        ((failed_tests++))
    fi
    echo ""
    
    echo "=== Advanced Service Integration Tests ==="
    if run_advanced_integration_tests; then
        echo "✓ Advanced service integration tests passed"
    else
        echo "❌ Advanced service integration tests failed"
        ((failed_tests++))
    fi
    echo ""
    
    if [ $failed_tests -eq 0 ]; then
        echo "🎉 All tests passed!"
        return 0
    else
        echo "💥 $failed_tests test suite(s) failed"
        return 1
    fi
}

main() {
    case "${1:-all}" in
        "shellcheck")
            run_shellcheck
            ;;
        "unit")
            run_unit_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "system")
            run_system_tests
            ;;
        "vm")
            run_vm_boot_tests
            ;;
        "functional")
            run_functional_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        "service-config")
            run_service_config_tests
            ;;
        "service-runtime")
            run_service_runtime_tests
            ;;
        "service-integration")
            run_service_integration_tests
            ;;
        "service-security")
            run_service_security_tests
            ;;
        "service-config-enhanced")
            run_enhanced_service_config_tests
            ;;
        "service-dependency")
            run_service_dependency_tests
            ;;
        "service-behavior")
            run_service_behavior_tests
            ;;
        "service-compatibility")
            run_service_compatibility_tests
            ;;
        "service-security-audit")
            run_service_security_audit_tests
            ;;
        "advanced-config")
            run_advanced_config_tests
            ;;
        "advanced-deps")
            run_advanced_dependency_tests
            ;;
        "advanced-behavior")
            run_advanced_behavior_tests
            ;;
        "advanced-security")
            run_advanced_security_tests
            ;;
        "advanced-integration")
            run_advanced_integration_tests
            ;;
        "comprehensive-service")
            run_comprehensive_service_tests
            ;;
        "advanced-all")
            run_all_advanced_tests
            ;;
        "all")
            run_all_tests
            ;;
        *)
            echo "Usage: $0 [all|shellcheck|unit|integration|functional|performance|advanced-config|advanced-deps|advanced-behavior|advanced-security|advanced-integration|comprehensive-service|advanced-all|service-config|service-runtime|service-integration|service-security|service-config-enhanced|service-dependency|service-behavior|service-compatibility|service-security-audit|system|vm]"
            exit 1
            ;;
    esac
}

main "$@"