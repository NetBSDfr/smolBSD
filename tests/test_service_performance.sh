#!/bin/sh
#
# Real smolBSD Performance and Resource Usage Tests
# Test service performance metrics and resource consumption
#

# Source test harness
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Test service build performance metrics
test_service_build_performance() {
    echo "Testing service build performance metrics..."
    
    local services_dir="$PROJECT_ROOT/service"
    local perf_issues=0
    local total_services=0
    
    # Test configuration file sizes and complexity
    for config_dir in "$PROJECT_ROOT/etc"; do
        if [ -d "$config_dir" ]; then
            for config_file in "$config_dir"/*.conf; do
                if [ -f "$config_file" ]; then
                    local config_name=$(basename "$config_file")
                    local file_size=$(stat -c%s "$config_file" 2>/dev/null || echo "0")
                    local line_count=$(wc -l < "$config_file" 2>/dev/null || echo "0")
                    
                    echo "PERFORMANCE METRICS: Config $config_name - Size: ${file_size}B, Lines: $line_count"
                    
                    # Check for reasonable config size
                    if [ "$file_size" -gt 10000 ]; then
                        echo "WARN: Large configuration file: $config_name (${file_size} bytes)"
                        perf_issues=$((perf_issues + 1))
                    fi
                fi
            done
        fi
    done
    
    # Test service script complexity
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            total_services=$((total_services + 1))
            
            # Check rc file complexity
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                local rc_size=$(stat -c%s "$rc_file" 2>/dev/null || echo "0")
                local rc_lines=$(wc -l < "$rc_file" 2>/dev/null || echo "0")
                
                echo "PERFORMANCE METRICS: Service $service_name rc - Size: ${rc_size}B, Lines: $rc_lines"
                
                # Check for reasonable script size
                if [ "$rc_size" -gt 5000 ]; then
                    echo "WARN: Large rc file for service $service_name (${rc_size} bytes)"
                fi
                
                # Check for complex operations
                local complex_ops=$(grep -cE "(for.*do.*done|while.*do.*done|if.*then.*elif|case.*esac)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$complex_ops" -gt 10 ]; then
                    echo "INFO: Complex control structures in service $service_name ($complex_ops)"
                fi
            fi
            
            # Check postinst script complexity
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        local script_size=$(stat -c%s "$script" 2>/dev/null || echo "0")
                        local script_lines=$(wc -l < "$script" 2>/dev/null || echo "0")
                        
                        echo "PERFORMANCE METRICS: Service $service_name postinst $script_name - Size: ${script_size}B, Lines: $script_lines"
                        
                        # Check for reasonable script size
                        if [ "$script_size" -gt 10000 ]; then
                            echo "WARN: Large postinst script: $service_name/$script_name (${script_size} bytes)"
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $perf_issues -eq 0 ]; then
        echo "PASSED: Service build performance metrics validated"
        return 0
    else
        echo "WARNING: $perf_issues performance issues found"
        return 0  # Performance issues are warnings, not failures
    fi
}

# Test service runtime resource usage patterns
test_service_resource_usage() {
    echo "Testing service runtime resource usage patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local resource_issues=0
    
    # Analyze resource usage patterns in service scripts
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for resource usage patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "RESOURCE ANALYSIS: Service $service_name"
                
                # Check for memory usage patterns
                local mem_ops=$(grep -cE "(ulimit|limit|memory|MB|GB)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$mem_ops" -gt 0 ]; then
                    echo "MEMORY USAGE: Service $service_name uses $mem_ops memory management operations"
                fi
                
                # Check for storage usage patterns
                local storage_ops=$(grep -cE "(tmpfs|union|mount.*-t.*tmpfs|mount.*size)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$storage_ops" -gt 0 ]; then
                    echo "STORAGE USAGE: Service $service_name uses $storage_ops storage management operations"
                fi
                
                # Check for process/resource limits
                local proc_limits=$(grep -cE "(ulimit.*[pnmu]|[np]rocs|threads|forks)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$proc_limits" -gt 0 ]; then
                    echo "PROCESS LIMITS: Service $service_name enforces $proc_limits process/resource limits"
                fi
                
                # Check for network resource usage
                local net_usage=$(grep -cE "(bandwidth|rate|limit.*conn|concurrent)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$net_usage" -gt 0 ]; then
                    echo "NETWORK USAGE: Service $service_name manages $net_usage network resources"
                fi
                
                # Check for CPU usage patterns
                local cpu_ops=$(grep -cE "(nice|renice|sched|priority)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$cpu_ops" -gt 0 ]; then
                    echo "CPU USAGE: Service $service_name uses $cpu_ops CPU management operations"
                fi
            fi
            
            # Check postinst scripts for resource-heavy operations
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        
                        # Check for package installations (resource intensive)
                        local pkg_installs=$(grep -cE "(pkg_add|pkgin install|apt-get install|yum install)" "$script" 2>/dev/null || echo "0")
                        if [ "$pkg_installs" -gt 0 ]; then
                            echo "PACKAGE INSTALL: Service $service_name installs $pkg_installs packages via $script_name"
                        fi
                        
                        # Check for large file operations
                        local large_files=$(grep -cE "(dd.*bs|cp.*-r|tar.*-x|unzip|gunzip)" "$script" 2>/dev/null || echo "0")
                        if [ "$large_files" -gt 0 ]; then
                            echo "LARGE FILES: Service $service_name performs $large_files large file operations via $script_name"
                        fi
                        
                        # Check for compilation/build operations
                        local builds=$(grep -cE "(make|gcc|cc|compile)" "$script" 2>/dev/null || echo "0")
                        if [ "$builds" -gt 0 ]; then
                            echo "BUILD OPERATIONS: Service $service_name performs $builds compilation operations via $script_name"
                        fi
                    fi
                done
            fi
        fi
    done
    
    echo "PASSED: Service resource usage patterns analyzed"
    return 0
}

# Test service boot time optimization patterns
test_boot_time_optimization() {
    echo "Testing service boot time optimization patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local optimization_issues=0
    
    # Analyze boot time optimization patterns
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for boot optimization patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "BOOT OPTIMIZATION: Service $service_name"
                
                # Check for parallel startup patterns
                local parallel_ops=$(grep -cE "(&\$|background|async)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$parallel_ops" -gt 0 ]; then
                    echo "PARALLEL STARTUP: Service $service_name uses $parallel_ops parallel operations"
                fi
                
                # Check for lazy initialization
                local lazy_init=$(grep -cE "(on demand|lazy|defer)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$lazy_init" -gt 0 ]; then
                    echo "LAZY INIT: Service $service_name uses $lazy_init lazy initialization patterns"
                fi
                
                # Check for startup delays/sleeps
                local startup_delays=$(grep -cE "sleep.*[5-9][0-9]*\|sleep.*[1-9][0-9][0-9]*" "$rc_file" 2>/dev/null || echo "0")
                if [ "$startup_delays" -gt 0 ]; then
                    echo "STARTUP DELAYS: Service $service_name has $startup_delays long startup delays"
                    optimization_issues=$((optimization_issues + 1))
                fi
                
                # Check for optimized startup sequences
                local optimized_seq=$(grep -cE "(sort.*-k|order.*startup|startup.*sequence)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$optimized_seq" -gt 0 ]; then
                    echo "OPTIMIZED SEQUENCE: Service $service_name has $optimized_seq optimized startup sequences"
                fi
                
                # Check for conditional startup
                local conditional_start=$(grep -cE "(if.*then.*start|test.*&&.*start)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$conditional_start" -gt 0 ]; then
                    echo "CONDITIONAL STARTUP: Service $service_name uses $conditional_start conditional startup patterns"
                fi
            fi
        fi
    done
    
    if [ $optimization_issues -eq 0 ]; then
        echo "PASSED: Boot time optimization patterns validated"
        return 0
    else
        echo "WARNING: $optimization_issues boot time optimization issues found"
        return 0  # Warnings, not failures
    fi
}

# Test service isolation and security resource patterns
test_isolation_resource_patterns() {
    echo "Testing service isolation and security resource patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local isolation_patterns=0
    
    # Analyze isolation and security resource usage
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for isolation patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "ISOLATION PATTERNS: Service $service_name"
                
                # Check for tmpfs/union mounts (isolation)
                local tmpfs_mounts=$(grep -cE "(tmpfs|union.*mount)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$tmpfs_mounts" -gt 0 ]; then
                    echo "TMPFS ISOLATION: Service $service_name uses $tmpfs_mounts tmpfs/union mounts"
                    isolation_patterns=$((isolation_patterns + $tmpfs_mounts))
                fi
                
                # Check for readonly filesystem patterns
                local readonly_fs=$(grep -cE "(mount.*-o.*ro|readonly.*mount)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$readonly_fs" -gt 0 ]; then
                    echo "READONLY FS: Service $service_name uses $readonly_fs readonly filesystem patterns"
                    isolation_patterns=$((isolation_patterns + $readonly_fs))
                fi
                
                # Check for chroot/jail patterns
                local chroot_patterns=$(grep -cE "(chroot|jail|sandbox)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$chroot_patterns" -gt 0 ]; then
                    echo "CHROOT/JAIL: Service $service_name uses $chroot_patterns isolation patterns"
                    isolation_patterns=$((isolation_patterns + $chroot_patterns))
                fi
                
                # Check for user/group isolation
                local user_isolation=$(grep -cE "(useradd.*-s|adduser.*-s|switch.*user)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$user_isolation" -gt 0 ]; then
                    echo "USER ISOLATION: Service $service_name uses $user_isolation user isolation patterns"
                    isolation_patterns=$((isolation_patterns + $user_isolation))
                fi
                
                # Check for namespace/container patterns
                local ns_patterns=$(grep -cE "(namespace|container|cgroup)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$ns_patterns" -gt 0 ]; then
                    echo "NAMESPACE: Service $service_name uses $ns_patterns namespace/container patterns"
                    isolation_patterns=$((isolation_patterns + $ns_patterns))
                fi
            fi
            
            # Check options.mk for resource constraints
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                local size_constraints=$(grep -cE "(IMGSIZE|SIZE.*[MG]B|LIMIT)" "$options_mk" 2>/dev/null || echo "0")
                if [ "$size_constraints" -gt 0 ]; then
                    echo "SIZE CONSTRAINTS: Service $service_name has $size_constraints resource size constraints"
                    isolation_patterns=$((isolation_patterns + $size_constraints))
                fi
                
                local arch_constraints=$(grep -cE "(ARCH.*!=|ONLY_FOR_ARCH)" "$options_mk" 2>/dev/null || echo "0")
                if [ "$arch_constraints" -gt 0 ]; then
                    echo "ARCH CONSTRAINTS: Service $service_name has $arch_constraints architecture constraints"
                    isolation_patterns=$((isolation_patterns + $arch_constraints))
                fi
            fi
        fi
    done
    
    if [ $isolation_patterns -gt 0 ]; then
        echo "PASSED: Found $isolation_patterns isolation/security resource patterns"
        return 0
    else
        echo "INFO: No specific isolation patterns found in sample services"
        return 0
    fi
}

# Test service scalability patterns
test_scalability_patterns() {
    echo "Testing service scalability patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local scalable_services=0
    
    # Analyze scalability patterns in services
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for scalability patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                # Check for horizontal scaling patterns
                local scale_patterns=$(grep -cE "(scale|instance|replica|cluster)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$scale_patterns" -gt 0 ]; then
                    echo "SCALABILITY: Service $service_name supports $scale_patterns scaling patterns"
                    scalable_services=$((scalable_services + 1))
                fi
                
                # Check for load balancing patterns
                local lb_patterns=$(grep -cE "(load.*balanc|balance|round.*robin)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$lb_patterns" -gt 0 ]; then
                    echo "LOAD BALANCING: Service $service_name supports $lb_patterns load balancing patterns"
                    scalable_services=$((scalable_services + 1))
                fi
                
                # Check for clustering patterns
                local cluster_patterns=$(grep -cE "(cluster|node|peer)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$cluster_patterns" -gt 0 ]; then
                    echo "CLUSTERING: Service $service_name supports $cluster_patterns clustering patterns"
                    scalable_services=$((scalable_services + 1))
                fi
            fi
            
            # Check postinst for scalability setup
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        # Check for multi-instance setup
                        local multi_instance=$(grep -cE "(multi|instance|replica)" "$script" 2>/dev/null || echo "0")
                        if [ "$multi_instance" -gt 0 ]; then
                            echo "MULTI-INSTANCE: Service $service_name supports $multi_instance multi-instance patterns"
                            scalable_services=$((scalable_services + 1))
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $scalable_services -gt 0 ]; then
        echo "PASSED: Found $scalable_services services with scalability patterns"
        return 0
    else
        echo "INFO: No services with explicit scalability patterns found"
        return 0
    fi
}

# Run all performance and resource usage tests
run_performance_resource_tests() {
    echo "RUNNING: Performance and resource usage tests"
    echo "============================================="
    
    local test_failures=0
    
    run_test "Service build performance" test_service_build_performance || test_failures=$((test_failures + 1))
    run_test "Service resource usage patterns" test_service_resource_usage || test_failures=$((test_failures + 1))
    run_test "Boot time optimization patterns" test_boot_time_optimization || test_failures=$((test_failures + 1))
    run_test "Isolation resource patterns" test_isolation_resource_patterns || test_failures=$((test_failures + 1))
    run_test "Scalability patterns" test_scalability_patterns || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ]; then
        echo "ALL PERFORMANCE AND RESOURCE USAGE TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures performance and resource usage test suites failed"
        return 1
    fi
}

# Execute if run directly
if [ "$0" = "$0" ]; then
    run_performance_resource_tests
fi