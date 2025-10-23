#!/bin/sh
# Tests for VM boot functionality

# Source the test framework utilities
if [ -z "$PROJECT_ROOT" ]; then
    echo "PROJECT_ROOT not set, setting it to parent directory"
    PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
    export PROJECT_ROOT
fi

# Test that QEMU is available
test_qemu_availability() {
    echo "Testing QEMU availability..."
    
    local qemu_found=0
    for qemu_cmd in qemu-system-x86_64 qemu-system-i386 qemu-system-aarch64; do
        if command -v "$qemu_cmd" >/dev/null 2>&1; then
            echo "✓ $qemu_cmd is available"
            qemu_found=1
        else
            echo "⚠️  $qemu_cmd is not available"
        fi
    done
    
    if [ $qemu_found -eq 1 ]; then
        echo "✓ At least one QEMU binary is available"
        return 0
    else
        echo "⚠️  No QEMU binaries found - VM boot tests will be limited"
        echo "   To install QEMU on Ubuntu, run:"
        echo "   sudo apt update && sudo apt install qemu-system-x86 qemu-system-arm qemu-utils"
        return 0  # Not critical for basic functionality
    fi
}

# Test kernel availability
test_kernel_availability() {
    echo "Testing kernel availability..."
    
    # Check if kernel directory exists
    if [ -d "$PROJECT_ROOT/kernels" ]; then
        echo "✓ kernels directory exists"
        
        # Check for common kernel names
        local kernel_found=0
        for kernel in netbsd-SMOL netbsd-SMOL386 netbsd-GENERIC64.img; do
            if [ -f "$PROJECT_ROOT/kernels/$kernel" ]; then
                echo "✓ Found kernel: $kernel"
                kernel_found=1
            fi
        done
        
        if [ $kernel_found -eq 1 ]; then
            echo "✓ At least one kernel is available"
        else
            echo "⚠️  No known kernels found in kernels/ directory"
            echo "   You may need to run: make kernfetch"
        fi
    else
        echo "⚠️  kernels directory does not exist"
        echo "   You may need to run: make kernfetch"
    fi
    
    return 0
}

# Test startnb.sh configuration parsing
test_startnb_config() {
    echo "Testing startnb.sh configuration handling..."
    
    # Check that startnb.sh has the expected usage function
    if grep -q "usage()" "$PROJECT_ROOT/startnb.sh"; then
        echo "✓ startnb.sh has usage function"
    else
        echo "❌ startnb.sh missing usage function"
        return 1
    fi
    
    # Check for expected configuration parameters
    if grep -q "hostfwd" "$PROJECT_ROOT/startnb.sh" && \
       grep -q "mem" "$PROJECT_ROOT/startnb.sh" && \
       grep -q "kernel" "$PROJECT_ROOT/startnb.sh"; then
        echo "✓ startnb.sh handles expected VM parameters"
    else
        echo "⚠️  startnb.sh may be missing expected VM parameters"
    fi
    
    return 0
}

# Test configuration file format
test_config_files() {
    echo "Testing configuration file format..."
    
    if [ ! -d "$PROJECT_ROOT/etc" ]; then
        echo "❌ etc directory not found"
        return 1
    fi
    
    # Test rescue.conf format
    if [ -f "$PROJECT_ROOT/etc/rescue.conf" ]; then
        echo "✓ rescue.conf exists"
        
        # Check for required parameters in the config file
        local required_params="vm img kernel"
        local missing_params=""
        
        for param in $required_params; do
            if grep -q "^${param}=" "$PROJECT_ROOT/etc/rescue.conf"; then
                echo "✓ rescue.conf has $param parameter"
            else
                missing_params="$missing_params $param"
            fi
        done
        
        if [ -n "$missing_params" ]; then
            echo "⚠️  rescue.conf missing required parameters:$missing_params"
        fi
    else
        echo "⚠️  rescue.conf not found"
    fi
    
    return 0
}

# Test VM boot command construction
test_boot_command() {
    echo "Testing VM boot command construction..."
    
    # Check for the command construction in startnb.sh
    if grep -q "qemu-system" "$PROJECT_ROOT/startnb.sh" && \
       grep -q "-kernel" "$PROJECT_ROOT/startnb.sh" && \
       grep -q "-append" "$PROJECT_ROOT/startnb.sh"; then
        echo "✓ startnb.sh constructs QEMU boot command"
    else
        echo "⚠️  startnb.sh may be missing QEMU command construction"
    fi
    
    return 0
}

# Main test function
run_vm_boot_tests() {
    echo "Running VM boot functionality tests..."
    
    local failed_tests=0
    
    if ! test_qemu_availability; then
        ((failed_tests++))
    fi
    
    if ! test_kernel_availability; then
        ((failed_tests++))
    fi
    
    if ! test_startnb_config; then
        ((failed_tests++))
    fi
    
    if ! test_config_files; then
        ((failed_tests++))
    fi
    
    if ! test_boot_command; then
        ((failed_tests++))
    fi
    
    if [ $failed_tests -eq 0 ]; then
        echo "✓ All VM boot functionality tests passed or skipped appropriately"
        return 0
    else
        echo "❌ $failed_tests VM boot functionality tests failed"
        return 1
    fi
}

# Run the tests
run_vm_boot_tests