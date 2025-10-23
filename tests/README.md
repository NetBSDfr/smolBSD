# smolBSD Test Suite

This directory contains the test suite for the smolBSD project, designed to validate the functionality of the minimal NetBSD VM creation and management system.

## Test Structure

The test suite is organized into multiple categories:

1. **Unit Tests** - Test individual script functions and syntax
2. **Integration Tests** - Test the integration between components
3. **Service Configuration Tests** - Validate service structures and configurations
4. **System Tests** - Test full system functionality (requires VM environment)
5. **Shellcheck Tests** - Lint shell scripts for best practices

## Running Tests

### Using Make (recommended):
```bash
cd tests
make test          # Run all tests
make unit          # Run only unit tests
make integration   # Run only integration tests
make app           # Run Flask application tests
make shellcheck    # Run shellcheck on scripts
make syntax        # Quick syntax check for shell scripts
make help          # Show available targets
```

### Using the test runner directly:
```bash
cd tests
./test_runner.sh all          # Run all tests
./test_runner.sh unit         # Run only unit tests
./test_runner.sh integration  # Run only integration tests
./test_runner.sh system       # Run system tests
./test_runner.sh shellcheck   # Run shellcheck
```

### Running individual test files:
```bash
cd tests
sh test_mkimg.sh      # Test mkimg.sh functionality
sh test_startnb.sh    # Test startnb.sh functionality
sh test_integration.sh # Test integration functionality
sh test_app.sh        # Test Flask application
sh test_service_config.sh # Test service configurations
```

## Test Categories

### Unit Tests
- Syntax validation for shell scripts
- Function-level testing for core scripts (mkimg.sh, startnb.sh)
- Basic functionality verification

### Integration Tests
- Makefile target validation
- Service directory structure validation
- Dependency checking
- Configuration file validation

### Service Configuration Tests
- Validation of service directory structures
- Configuration file format validation
- Basic service functionality checks

### System Tests
- VM execution environment validation
- QEMU availability checks
- (Currently limited due to VM environment requirements)

## Adding New Tests

When adding new functionality to smolBSD, please add corresponding tests:

1. For new shell script functions, add tests in `test_mkimg.sh` or `test_startnb.sh`
2. For new service types, add tests in `test_service_config.sh`
3. For new integration points, add tests in `test_integration.sh`
4. For new application features, add tests in `test_app.sh`

## Test Requirements

### Basic Tests
- `make` for the Makefile-based test runner
- Basic Unix tools: `sh`, `grep`, `find`, `curl`, `tar`, `dd`, etc.
- `shellcheck` for shell script linting (optional, for shellcheck tests)

### Application Tests
- `python3` and modules: `flask`, `psutil` for application tests

### System/VM Tests (Optional)
- QEMU for VM execution and system-level tests:
  - `qemu-system-x86_64` for x86_64 VMs
  - `qemu-system-i386` for i386 VMs  
  - `qemu-system-aarch64` for ARM64 VMs
  - `qemu-utils` for image manipulation tools

### Installing Dependencies on Ubuntu

```bash
# Install basic dependencies
sudo apt update
sudo apt install -y make curl tar xz-utils git rsync bmake libarchive-tools e2fsprogs

# Install shellcheck for linting (optional)
sudo apt install -y shellcheck

# Install QEMU for VM tests (optional but recommended)
sudo apt install -y qemu-system-x86 qemu-system-arm qemu-utils

# Install Python dependencies for web app tests
cd app && pip3 install -r requirements.txt
```

## Continuous Integration

The test suite is designed to work with CI systems. The GitHub Actions workflow in `.github/workflows/main.yml` currently builds images but could be extended to run these tests as well.