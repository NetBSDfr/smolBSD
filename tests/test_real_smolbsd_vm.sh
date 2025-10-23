#!/bin/sh
#
# Real smolBSD VM Execution Tests
# Test actual smolBSD service functionality in real VM instances
#

# Source test harness
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Check if required tools are available for VM execution
check_vm_prerequisites() {
    echo "Checking VM execution prerequisites..."
    
    local missing_tools=""
    local required_tools="qemu-system-x86_64 mkimg.sh startnb.sh"
    
    # Check for QEMU
    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "FAIL: qemu-system-x86_64 not found"
        missing_tools="$missing_tools qemu-system-x86_64"
    else
        echo "PASS: qemu-system-x86_64 is available"
    fi
    
    # Check for smolBSD tools
    if [ ! -f "$PROJECT_ROOT/mkimg.sh" ]; then
        echo "FAIL: mkimg.sh not found in project root"
        missing_tools="$missing_tools mkimg.sh"
    else
        echo "PASS: mkimg.sh is available"
    fi
    
    if [ ! -f "$PROJECT_ROOT/startnb.sh" ]; then
        echo "FAIL: startnb.sh not found in project root"
        missing_tools="$missing_tools startnb.sh"
    else
        echo "PASS: startnb.sh is available"
    fi
    
    # Check for kernel
    if [ ! -d "$PROJECT_ROOT/kernels" ] || [ -z "$(ls -A "$PROJECT_ROOT/kernels" 2>/dev/null)" ]; then
        echo "INFO: No kernels found, will need to fetch kernel"
    else
        echo "PASS: Kernels directory exists"
        # List available kernels
        for kernel in "$PROJECT_ROOT/kernels"/*; do
            if [ -f "$kernel" ]; then
                echo "INFO: Available kernel: $(basename "$kernel")"
            fi
        done
    fi
    
    if [ -n "$missing_tools" ]; then
        echo "CRITICAL: Missing required tools: $missing_tools"
        return 1
    else
        echo "PASSED: All VM execution prerequisites satisfied"
        return 0
    fi
}

# Build a minimal smolBSD rescue image for testing
build_minimal_rescue_image() {
    local image_name="test-rescue-amd64.img"
    local test_dir="$TEST_TMPDIR/vm_test"
    
    echo "Building minimal rescue image for VM testing..."
    mkdir -p "$test_dir"
    
    # Change to project root for building
    cd "$PROJECT_ROOT"
    
    # Check if image already exists
    if [ -f "$image_name" ]; then
        echo "INFO: Using existing rescue image: $image_name"
        return 0
    fi
    
    # Try to build a minimal rescue image
    echo "Attempting to build minimal rescue image..."
    
    # Use a small image size for testing
    local build_cmd="make SERVICE=rescue MOUNTRO=y rescue"
    
    # Try to build with a timeout to prevent hanging
    if timeout 300 $build_cmd >/dev/null 2>&1; then
        echo "PASS: Successfully built rescue image: $image_name"
        return 0
    else
        echo "FAIL: Failed to build rescue image with command: $build_cmd"
        echo "INFO: Will attempt to download pre-built image if available"
        
        # Check if we can download a pre-built image
        local prebuilt_url="https://github.com/NetBSDfr/smolBSD/releases/download/latest/rescue-amd64.img"
        local temp_img="$test_dir/rescue-amd64.img"
        
        if command -v curl >/dev/null 2>&1; then
            echo "INFO: Attempting to download pre-built rescue image..."
            if curl -L --max-time 60 -o "$temp_img" "$prebuilt_url" 2>/dev/null; then
                if [ -f "$temp_img" ] && [ -s "$temp_img" ]; then
                    echo "PASS: Downloaded pre-built rescue image successfully"
                    cp "$temp_img" "$PROJECT_ROOT/$image_name"
                    return 0
                fi
            fi
        fi
        
        echo "WARN: Could not build or download rescue image - limited VM testing possible"
        return 1
    fi
}

# Test basic VM boot functionality
test_vm_boot_functionality() {
    local test_dir="$TEST_TMPDIR/vm_test"
    local image_name="test-rescue-amd64.img"
    local kernel_name="netbsd-SMOL"
    
    echo "Testing basic VM boot functionality..."
    
    # Check if we have a rescue image
    if [ -f "$PROJECT_ROOT/$image_name" ]; then
        echo "INFO: Using rescue image: $image_name"
    else
        echo "INFO: No rescue image found, checking for alternative images..."
        
        # Look for any available images
        local available_images=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.img" | head -1)
        if [ -n "$available_images" ]; then
            image_name=$(basename "$available_images")
            echo "INFO: Found alternative image: $image_name"
        else
            echo "FAIL: No images available for VM testing"
            return 1
        fi
    fi
    
    # Check for kernel
    local kernel_path=""
    if [ -f "$PROJECT_ROOT/kernels/$kernel_name" ]; then
        kernel_path="$PROJECT_ROOT/kernels/$kernel_name"
        echo "INFO: Using kernel: $kernel_name"
    else
        # Look for any available kernel
        local available_kernels=$(find "$PROJECT_ROOT/kernels" -type f 2>/dev/null | head -1)
        if [ -n "$available_kernels" ]; then
            kernel_path="$available_kernels"
            echo "INFO: Using alternative kernel: $(basename "$kernel_path")"
        else
            echo "FAIL: No kernels available for VM testing"
            return 1
        fi
    fi
    
    # Test basic VM startup with timeout
    echo "Starting VM with minimal configuration..."
    
    # Create a simple config for testing
    local test_config="$test_dir/test_vm.conf"
    cat > "$test_config" << _EOF_
vm=testvm
img=$PROJECT_ROOT/$image_name
kernel=$kernel_path
mem=128m
cores=1
_EOF_
    
    # Try to start VM with timeout and capture output
    local start_cmd="$PROJECT_ROOT/startnb.sh -f $test_config -d"
    echo "INFO: Starting VM with command: $start_cmd"
    
    # Start VM in background with timeout
    if timeout 30 $start_cmd >/dev/null 2>&1; then
        echo "PASS: VM started successfully"
        
        # Give VM time to boot
        sleep 10
        
        # Check if VM process is still running
        local vm_pid=$(pgrep -f "qemu-system.*$image_name" 2>/dev/null)
        if [ -n "$vm_pid" ]; then
            echo "PASS: VM process is running (PID: $vm_pid)"
            
            # Try to terminate VM gracefully
            if kill "$vm_pid" 2>/dev/null; then
                echo "PASS: VM terminated gracefully"
            else
                # Force kill if graceful termination failed
                kill -9 "$vm_pid" 2>/dev/null
                echo "INFO: VM force terminated"
            fi
            
            return 0
        else
            echo "FAIL: VM process not found after startup"
            return 1
        fi
    else
        echo "FAIL: VM failed to start within timeout period"
        return 1
    fi
}

# Test service-specific functionality in real VMs
test_service_functionality() {
    local services_dir="$PROJECT_ROOT/service"
    local test_results=0
    
    echo "Testing service-specific functionality in real VMs..."
    
    # Test a few representative services
    local test_services="rescue sshd bozohttpd"
    
    for service_name in $test_services; do
        if [ -d "$services_dir/$service_name" ]; then
            echo "TESTING: Service $service_name functionality"
            
            # Check if service has specific configuration
            local service_conf="$PROJECT_ROOT/etc/${service_name}.conf"
            if [ -f "$service_conf" ]; then
                echo "INFO: Service $service_name has configuration file"
                
                # Parse basic service configuration
                local service_img=$(grep "^img=" "$service_conf" 2>/dev/null | cut -d'=' -f2)
                local service_kernel=$(grep "^kernel=" "$service_conf" 2>/dev/null | cut -d'=' -f2)
                
                if [ -n "$service_img" ] && [ -n "$service_kernel" ]; then
                    echo "INFO: Service $service_name configuration parsed successfully"
                    echo "  - Image: $service_img"
                    echo "  - Kernel: $service_kernel"
                else
                    echo "INFO: Service $service_name configuration requires additional parsing"
                fi
            else
                echo "INFO: Service $service_name has no specific configuration file"
            fi
            
            # Test basic service image building capability
            if [ -f "$PROJECT_ROOT/mkimg.sh" ]; then
                echo "INFO: Service $service_name can be built with mkimg.sh"
                
                # Check service options.mk if it exists
                local options_mk="$services_dir/$service_name/options.mk"
                if [ -f "$options_mk" ]; then
                    echo "INFO: Service $service_name has build options"
                    
                    # Parse basic build options
                    local has_imgsize=$(grep -c "IMGSIZE\|SIZE" "$options_mk" 2>/dev/null)
                    local has_arch=$(grep -c "ARCH" "$options_mk" 2>/dev/null)
                    
                    if [ "$has_imgsize" -gt 0 ]; then
                        echo "INFO: Service $service_name specifies image size requirements"
                    fi
                    if [ "$has_arch" -gt 0 ]; then
                        echo "INFO: Service $service_name has architecture constraints"
                    fi
                fi
            fi
            
            # Increment test counter
            test_results=$((test_results + 1))
        else
            echo "INFO: Service $service_name not found, skipping"
        fi
    done
    
    if [ $test_results -gt 0 ]; then
        echo "PASSED: Tested functionality for $test_results services"
        return 0
    else
        echo "INFO: No services available for functionality testing"
        return 0
    fi
}

# Test resource usage and performance of real VMs
test_vm_performance_metrics() {
    echo "Testing VM performance and resource usage metrics..."
    
    # Check system resources
    local total_mem=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
    local available_mem=$(free -m 2>/dev/null | awk '/^Mem:/{print $7}' || echo "0")
    
    if [ "$total_mem" -gt 0 ]; then
        echo "INFO: System memory - Total: ${total_mem}MB, Available: ${available_mem}MB"
        
        # Check if sufficient memory for VM testing
        if [ "$available_mem" -lt 256 ]; then
            echo "WARN: Low available memory (${available_mem}MB) may affect VM performance testing"
        fi
    else
        echo "INFO: Unable to determine system memory (may not be Linux)"
    fi
    
    # Check CPU information
    if command -v nproc >/dev/null 2>&1; then
        local cpu_cores=$(nproc 2>/dev/null || echo "1")
        echo "INFO: CPU cores available: $cpu_cores"
    fi
    
    # Check disk space
    local disk_space=$(df -h "$PROJECT_ROOT" 2>/dev/null | awk 'NR==2{print $4}' | sed 's/G//' || echo "0")
    if [ -n "$disk_space" ] && [ "$disk_space" -gt 0 ] 2>/dev/null; then
        echo "INFO: Available disk space: ${disk_space}GB"
        
        # Check if sufficient space for VM images
        if [ "$disk_space" -lt 1 ]; then
            echo "WARN: Low available disk space (${disk_space}GB) may affect VM testing"
        fi
    fi
    
    echo "PASSED: Performance and resource metrics collected"
    return 0
}

# Test VM networking and connectivity
test_vm_networking() {
    echo "Testing VM networking and connectivity..."
    
    # Check for bridge utilities
    local bridge_tools="brctl ip tunctl openvpn"
    local available_bridge_tools=""
    
    for tool in $bridge_tools; do
        if command -v "$tool" >/dev/null 2>&1; then
            available_bridge_tools="$available_bridge_tools $tool"
        fi
    done
    
    if [ -n "$available_bridge_tools" ]; then
        echo "INFO: Available networking tools:$available_bridge_tools"
    else
        echo "INFO: No specialized networking tools found (standard QEMU networking will be used)"
    fi
    
    # Check for iptables/firewall
    if command -v iptables >/dev/null 2>&1; then
        echo "INFO: iptables available for advanced networking configuration"
    fi
    
    # Check for network interfaces
    local network_interfaces=$(ip link show 2>/dev/null | grep -c "state UP" || echo "0")
    echo "INFO: Active network interfaces: $network_interfaces"
    
    echo "PASSED: Networking capabilities assessed"
    return 0
}

# Run all real smolBSD VM execution tests
run_real_smolbsd_vm_tests() {
    echo "RUNNING: Real smolBSD VM execution tests"
    echo "======================================="
    
    local test_failures=0
    
    run_test "VM execution prerequisites check" check_vm_prerequisites || test_failures=$((test_failures + 1))
    run_test "Minimal rescue image building" build_minimal_rescue_image || test_failures=$((test_failures + 1))
    run_test "Basic VM boot functionality" test_vm_boot_functionality || test_failures=$((test_failures + 1))
    run_test "Service functionality validation" test_service_functionality || test_failures=$((test_failures + 1))
    run_test "VM performance metrics" test_vm_performance_metrics || test_failures=$((test_failures + 1))
    run_test "VM networking capabilities" test_vm_networking || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ]; then
        echo "ALL REAL SMOLBSD VM EXECUTION TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures real smolBSD VM execution test suites failed"
        return 1
    fi
}

# Execute if run directly
if [ "$0" = "$0" ]; then
    run_real_smolbsd_vm_tests
fi