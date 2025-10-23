# Makefile for smolBSD tests

# Variables
SHELL := /bin/sh
PROJECT_ROOT := ..
TEST_DIR := .

# Default target
.PHONY: all
all: unit integration functional app shellcheck performance service

# Run all unit tests
.PHONY: unit
unit:
	@echo "Running unit tests..."
	@bash test_mkimg_unit.sh
	@bash test_startnb_unit.sh
	@echo "✓ Unit tests completed"

# Run integration tests
.PHONY: integration
integration:
	@echo "Running integration tests..."
	@$(TEST_DIR)/test_integration.sh
	@echo "✓ Integration tests completed"

# Run app tests
.PHONY: app
app:
	@echo "Running app tests..."
	@$(TEST_DIR)/test_app.sh
	@echo "✓ App tests completed"

# Run VM boot tests
.PHONY: vm
vm:
	@echo "Running VM boot tests..."
	@$(TEST_DIR)/test_vm_boot.sh
	@echo "✓ VM boot tests completed"

# Run functional tests
.PHONY: functional
functional:
	@echo "Running functional tests..."
	@bash test_functional.sh
	@echo "✓ Functional tests completed"

# Run performance tests
.PHONY: performance
performance:
	@echo "Running performance tests..."
	@bash test_performance.sh
	@echo "✓ Performance tests completed"

# Run service tests (configuration, runtime, integration, security, and advanced tests)
.PHONY: service
service: service-config service-runtime service-integration service-security service-config-enhanced service-dependency service-behavior service-compatibility service-security-audit advanced-config advanced-deps advanced-behavior advanced-security advanced-integration real-service-integration
	@echo "✓ All service tests completed"

# Run advanced service tests
.PHONY: advanced-service
advanced-service: advanced-config advanced-deps advanced-behavior advanced-security advanced-integration
	@echo "✓ All advanced service tests completed"

# Run service configuration tests
.PHONY: service-config
service-config:
	@echo "Running service configuration tests..."
	@bash test_service_config.sh
	@echo "✓ Service configuration tests completed"

# Run service runtime tests
.PHONY: service-runtime
service-runtime:
	@echo "Running service runtime tests..."
	@bash test_service_runtime.sh
	@echo "✓ Service runtime tests completed"

# Run service integration tests
.PHONY: service-integration
service-integration:
	@echo "Running service integration tests..."
	@bash test_service_integration.sh
	@echo "✓ Service integration tests completed"

# Run service security tests
.PHONY: service-security
service-security:
	@echo "Running service security tests..."
	@bash test_service_security.sh
	@echo "✓ Service security tests completed"

# Run enhanced service configuration tests
.PHONY: service-config-enhanced
service-config-enhanced:
	@echo "Running enhanced service configuration tests..."
	@bash test_service_config_enhanced.sh
	@echo "✓ Enhanced service configuration tests completed"

# Run service dependency tests
.PHONY: service-dependency
service-dependency:
	@echo "Running service dependency tests..."
	@bash test_service_dependencies.sh
	@echo "✓ Service dependency tests completed"

# Run service behavior tests
.PHONY: service-behavior
service-behavior:
	@echo "Running service behavior tests..."
	@bash test_service_behavior.sh
	@echo "✓ Service behavior tests completed"

# Run service compatibility tests
.PHONY: service-compatibility
service-compatibility:
	@echo "Running service compatibility tests..."
	@bash test_service_compatibility.sh
	@echo "✓ Service compatibility tests completed"

# Run service security audit tests
.PHONY: service-security-audit
service-security-audit:
	@echo "Running service security audit tests..."
	@bash test_service_security_audit.sh
	@echo "✓ Service security audit tests completed"

# Run advanced service configuration tests
.PHONY: advanced-config
advanced-config:
	@echo "Running advanced service configuration tests..."
	@sh test_service_advanced_config.sh
	@echo "✓ Advanced service configuration tests completed"

# Run advanced service dependency tests
.PHONY: advanced-deps
advanced-deps:
	@echo "Running advanced service dependency tests..."
	@sh test_service_advanced_deps.sh
	@echo "✓ Advanced service dependency tests completed"

# Run advanced service behavior tests
.PHONY: advanced-behavior
advanced-behavior:
	@echo "Running advanced service behavior tests..."
	@sh test_service_advanced_behavior.sh
	@echo "✓ Advanced service behavior tests completed"

# Run advanced service security tests
.PHONY: advanced-security
advanced-security:
	@echo "Running advanced service security tests..."
	@sh test_service_advanced_security.sh
	@echo "✓ Advanced service security tests completed"

# Run advanced service integration tests
.PHONY: advanced-integration
advanced-integration:
	@echo "Running advanced service integration tests..."
	@sh test_service_advanced_integration.sh
	@echo "✓ Advanced service integration tests completed"

# Run real service integration tests
.PHONY: real-service-integration
real-service-integration:
	@echo "Running real service integration tests..."
	@sh test_real_service_integration.sh
	@echo "✓ Real service integration tests completed"

# Run real service integration tests
	@echo "Running real service integration tests..."
	@sh test_real_service_integration.sh
	@echo "✓ Real service integration tests completed"

# Run shellcheck
.PHONY: shellcheck
shellcheck:
	@echo "Running shellcheck..."
	@$(TEST_DIR)/test_runner.sh shellcheck
	@echo "✓ Shellcheck completed"

# Run all tests using the test runner
.PHONY: test
test:
	bash test_runner.sh all

# Quick syntax check
.PHONY: syntax
syntax:
	@echo "Checking syntax of shell scripts..."
	@sh -n $(PROJECT_ROOT)/mkimg.sh && echo "✓ mkimg.sh syntax OK"
	@sh -n $(PROJECT_ROOT)/startnb.sh && echo "✓ startnb.sh syntax OK"

# Clean test artifacts
.PHONY: clean
clean:
	@echo "Cleaning test artifacts..."
	@find $(TEST_DIR) -name "*.pyc" -delete 2>/dev/null || true
	@find $(TEST_DIR) -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Test artifacts cleaned"

# Help target
.PHONY: help
help:
	@echo "smolBSD Test Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all                      - Run all tests (default)"
	@echo "  test                     - Run all tests using the test runner"
	@echo "  unit                     - Run unit tests for shell scripts"
	@echo "  integration              - Run integration tests"
	@echo "  functional               - Run functional tests"
	@echo "  performance              - Run performance and regression tests"
	@echo "  service                  - Run all service tests"
	@echo "  service-config           - Run service configuration tests"
	@echo "  service-runtime          - Run service runtime tests"
	@echo "  service-integration      - Run service integration tests"
	@echo "  service-security         - Run service security tests"
	@echo "  service-config-enhanced  - Run enhanced service configuration tests"
	@echo "  service-dependency       - Run service dependency tests"
	@echo "  service-behavior         - Run service behavior tests"
	@echo "  service-compatibility    - Run service compatibility tests"
	@echo "  service-security-audit   - Run comprehensive service security audit"
	@echo "  advanced-config          - Run advanced service configuration tests"
	@echo "  advanced-deps            - Run advanced service dependency tests"
	@echo "  advanced-behavior        - Run advanced service behavior tests"
	@echo "  advanced-security        - Run advanced service security tests"
	@echo "  advanced-integration     - Run advanced service integration tests"
	@echo "  real-service-integration - Run real service integration tests"
	@echo "  app                      - Run Flask application tests"
	@echo "  vm                       - Run VM boot functionality tests"
	@echo "  shellcheck               - Run shellcheck on shell scripts"
	@echo "  syntax                   - Quick syntax check for shell scripts"
	@echo "  clean                    - Clean test artifacts"
	@echo "  help                     - Show this help"