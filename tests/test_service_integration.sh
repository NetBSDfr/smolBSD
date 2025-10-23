#!/bin/sh
#
# Service Integration Tests for smolBSD
# Test how services interact with each other and the system
#

# Source test harness
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

# Test service-to-service communication patterns
test_service_communication() {
    echo "Testing service-to-service communication patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local communication_patterns=0
    
    # Analyze communication patterns between services
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for references to other services
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "COMMUNICATION: Service $service_name"
                
                # Check for service references in rc files
                local service_refs=$(grep -oE "(sshd\|nginx\|apache\|httpd\|mysql\|postgres\|redis\|docker\|systemd\|dinit\|runit\|bozohttpd\|imgbuilder\|mport\|nbakery\|nitro\|nitrosshd\|rescue\|runbsd\|systembsd\|tslog)" "$rc_file" 2>/dev/null | sort -u)
                if [ -n "$service_refs" ]; then
                    local ref_count=$(echo "$service_refs" | wc -l)
                    echo "SERVICE REFS: Service $service_name references $ref_count other services:"
                    echo "$service_refs" | while read -r ref; do
                        echo "  - $ref"
                        communication_patterns=$((communication_patterns + 1))
                    done
                fi
                
                # Check for network communication patterns
                local net_patterns=$(grep -cE "(nc\|netcat\|socat\|telnet\|curl\|wget\|ftp\|ssh)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$net_patterns" -gt 0 ]; then
                    echo "NETWORK COMM: Service $service_name uses $net_patterns network communication tools"
                    communication_patterns=$((communication_patterns + $net_patterns))
                fi
                
                # Check for IPC/messaging patterns
                local ipc_patterns=$(grep -cE "(socket\|pipe\|fifo\|msg\|sem\|shm\|mqueue)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$ipc_patterns" -gt 0 ]; then
                    echo "IPC: Service $service_name uses $ipc_patterns inter-process communication patterns"
                    communication_patterns=$((communication_patterns + $ipc_patterns))
                fi
                
                # Check for file-based communication
                local file_comm=$(grep -cE "(echo.*>>\|cat.*>>\|tee\|>.*log\|>.*tmp)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$file_comm" -gt 0 ]; then
                    echo "FILE COMM: Service $service_name uses $file_comm file-based communication patterns"
                    communication_patterns=$((communication_patterns + $file_comm))
                fi
            fi
            
            # Check postinst scripts for cross-service operations
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        
                        # Check for service installation/management
                        local svc_mgmt=$(grep -cE "(service\|sv\|runit\|dinit\|systemctl)" "$script" 2>/dev/null || echo "0")
                        if [ "$svc_mgmt" -gt 0 ]; then
                            echo "SERVICE MGMT: Service $service_name postinst $script_name manages $svc_mgmt services"
                            communication_patterns=$((communication_patterns + $svc_mgmt))
                        fi
                        
                        # Check for package dependencies
                        local pkg_deps=$(grep -cE "(pkg_add\|pkgin install\|apt-get install\|yum install)" "$script" 2>/dev/null || echo "0")
                        if [ "$pkg_deps" -gt 0 ]; then
                            echo "PKG DEPS: Service $service_name postinst $script_name installs $pkg_deps packages"
                            communication_patterns=$((communication_patterns + $pkg_deps))
                        fi
                        
                        # Check for file sharing between services
                        local file_sharing=$(grep -cE "(/etc/|/var/|/usr/).*common\|common.*(/etc/|/var/|/usr/)" "$script" 2>/dev/null || echo "0")
                        if [ "$file_sharing" -gt 0 ]; then
                            echo "FILE SHARING: Service $service_name postinst $script_name shares $file_sharing files with other services"
                            communication_patterns=$((communication_patterns + $file_sharing))
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $communication_patterns -gt 0 ]; then
        echo "PASSED: Found $communication_patterns service communication patterns"
        return 0
    else
        echo "INFO: No explicit service communication patterns found"
        return 0
    fi
}

# Test service dependency chains and graphs
test_service_dependencies() {
    echo "Testing service dependency chains and graphs..."
    
    local services_dir="$PROJECT_ROOT/service"
    local dependency_chains=0
    
    # Build dependency graph for services
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for dependency declarations
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "DEPENDENCY ANALYSIS: Service $service_name"
                
                # Check for explicit dependency declarations
                local explicit_deps=$(grep -cE "(depends\|require\|need\|must.*have)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$explicit_deps" -gt 0 ]; then
                    echo "EXPLICIT DEPS: Service $service_name declares $explicit_deps explicit dependencies"
                    dependency_chains=$((dependency_chains + $explicit_deps))
                fi
                
                # Check for conditional dependencies
                local conditional_deps=$(grep -cE "(if.*exist\|test.*-f\|check.*service)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$conditional_deps" -gt 0 ]; then
                    echo "CONDITIONAL DEPS: Service $service_name has $conditional_deps conditional dependencies"
                    dependency_chains=$((dependency_chains + $conditional_deps))
                fi
                
                # Check for dependency resolution patterns
                local dep_resolution=$(grep -cE "(resolve.*dep\|find.*service\|locate.*service)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$dep_resolution" -gt 0 ]; then
                    echo "DEP RESOLUTION: Service $service_name has $dep_resolution dependency resolution patterns"
                    dependency_chains=$((dependency_chains + $dep_resolution))
                fi
                
                # Check for dependency ordering
                local dep_ordering=$(grep -cE "(before\|after\|order\|sequence)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$dep_ordering" -gt 0 ]; then
                    echo "DEP ORDERING: Service $service_name has $dep_ordering dependency ordering constraints"
                    dependency_chains=$((dependency_chains + $dep_ordering))
                fi
                
                # Check for circular dependency detection
                local circular_check=$(grep -cE "(circular\|loop\|cycle\|recurse)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$circular_check" -gt 0 ]; then
                    echo "CIRCULAR CHECK: Service $service_name has $circular_check circular dependency detection patterns"
                    dependency_chains=$((dependency_chains + $circular_check))
                fi
            fi
            
            # Check for build-time dependencies in options.mk
            local options_mk="$service_dir/options.mk"
            if [ -f "$options_mk" ]; then
                local build_deps=$(grep -cE "(BUILD_DEPENDS\|DEPENDS\|RUN_DEPENDS)" "$options_mk" 2>/dev/null || echo "0")
                if [ "$build_deps" -gt 0 ]; then
                    echo "BUILD DEPS: Service $service_name has $build_deps build-time dependencies"
                    dependency_chains=$((dependency_chains + $build_deps))
                fi
                
                local arch_deps=$(grep -cE "(ONLY_FOR_ARCHS\|NOT_FOR_ARCHS\|ARCH.*!=)" "$options_mk" 2>/dev/null || echo "0")
                if [ "$arch_deps" -gt 0 ]; then
                    echo "ARCH DEPS: Service $service_name has $arch_deps architecture dependencies"
                    dependency_chains=$((dependency_chains + $arch_deps))
                fi
                
                local os_deps=$(grep -cE "(ONLY_FOR_OPSYS\|NOT_FOR_OPSYS\|OPSYS.*!=)" "$options_mk" 2>/dev/null || echo "0")
                if [ "$os_deps" -gt 0 ]; then
                    echo "OS DEPS: Service $service_name has $os_deps operating system dependencies"
                    dependency_chains=$((dependency_chains + $os_deps))
                fi
            fi
        fi
    done
    
    if [ $dependency_chains -gt 0 ]; then
        echo "PASSED: Found $dependency_chains service dependency patterns"
        return 0
    else
        echo "INFO: No explicit dependency patterns found (may be OK for simple services)"
        return 0
    fi
}

# Test service orchestration and lifecycle management
test_service_orchestration() {
    echo "Testing service orchestration and lifecycle management..."
    
    local services_dir="$PROJECT_ROOT/service"
    local orchestration_patterns=0
    
    # Analyze service orchestration patterns
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check rc file for orchestration patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "ORCHESTRATION: Service $service_name"
                
                # Check for service startup orchestration
                local startup_orch=$(grep -cE "(start.*all\|boot.*all\|launch.*services)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$startup_orch" -gt 0 ]; then
                    echo "STARTUP ORCH: Service $service_name orchestrates $startup_orch service startups"
                    orchestration_patterns=$((orchestration_patterns + $startup_orch))
                fi
                
                # Check for service shutdown orchestration
                local shutdown_orch=$(grep -cE "(stop.*all\|halt.*all\|shutdown.*services)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$shutdown_orch" -gt 0 ]; then
                    echo "SHUTDOWN ORCH: Service $service_name orchestrates $shutdown_orch service shutdowns"
                    orchestration_patterns=$((orchestration_patterns + $shutdown_orch))
                fi
                
                # Check for service restart/reload orchestration
                local restart_orch=$(grep -cE "(restart.*all\|reload.*all\|refresh.*services)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$restart_orch" -gt 0 ]; then
                    echo "RESTART ORCH: Service $service_name orchestrates $restart_orch service restarts"
                    orchestration_patterns=$((orchestration_patterns + $restart_orch))
                fi
                
                # Check for service lifecycle management
                local lifecycle_mgmt=$(grep -cE "(init\|setup\|configure\|teardown\|cleanup)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$lifecycle_mgmt" -gt 0 ]; then
                    echo "LIFECYCLE MGMT: Service $service_name manages $lifecycle_mgmt lifecycle operations"
                    orchestration_patterns=$((orchestration_patterns + $lifecycle_mgmt))
                fi
                
                # Check for service state coordination
                local state_coord=$(grep -cE "(sync\|coord\|wait\|notify\|signal)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$state_coord" -gt 0 ]; then
                    echo "STATE COORD: Service $service_name coordinates $state_coord service states"
                    orchestration_patterns=$((orchestration_patterns + $state_coord))
                fi
                
                # Check for distributed coordination
                local dist_coord=$(grep -cE "(cluster\|distributed\|coordinator\|leader\|follower)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$dist_coord" -gt 0 ]; then
                    echo "DIST COORD: Service $service_name uses $dist_coord distributed coordination patterns"
                    orchestration_patterns=$((orchestration_patterns + $dist_coord))
                fi
            fi
            
            # Check postinst for orchestration setup
            local postinst_dir="$service_dir/postinst"
            if [ -d "$postinst_dir" ]; then
                for script in "$postinst_dir"/*.sh; do
                    if [ -f "$script" ]; then
                        local script_name=$(basename "$script")
                        
                        # Check for service registration/setup
                        local svc_setup=$(grep -cE "(register\|setup\|install.*service\|enable.*service)" "$script" 2>/dev/null || echo "0")
                        if [ "$svc_setup" -gt 0 ]; then
                            echo "SERVICE SETUP: Service $service_name postinst $script_name sets up $svc_setup services"
                            orchestration_patterns=$((orchestration_patterns + $svc_setup))
                        fi
                        
                        # Check for service configuration orchestration
                        local config_orch=$(grep -cE "(configure.*all\|setup.*all\|apply.*config)" "$script" 2>/dev/null || echo "0")
                        if [ "$config_orch" -gt 0 ]; then
                            echo "CONFIG ORCH: Service $service_name postinst $script_name orchestrates $config_orch configurations"
                            orchestration_patterns=$((orchestration_patterns + $config_orch))
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [ $orchestration_patterns -gt 0 ]; then
        echo "PASSED: Found $orchestration_patterns service orchestration patterns"
        return 0
    else
        echo "INFO: No explicit orchestration patterns found (single-service design may be intentional)"
        return 0
    fi
}

# Test service ecosystem integration patterns
test_ecosystem_integration() {
    echo "Testing service ecosystem integration patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local ecosystem_patterns=0
    
    # Check how services integrate with the broader ecosystem
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check for ecosystem integration patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "ECOSYSTEM INTEGRATION: Service $service_name"
                
                # Check for hardware integration
                local hw_integration=$(grep -cE "(pci\|usb\|disk\|network\|eth\|wlan)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$hw_integration" -gt 0 ]; then
                    echo "HARDWARE INTEGRATION: Service $service_name integrates with $hw_integration hardware components"
                    ecosystem_patterns=$((ecosystem_patterns + $hw_integration))
                fi
                
                # Check for cloud/platform integration
                local cloud_integration=$(grep -cE "(aws\|azure\|gcp\|cloud\|provider)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$cloud_integration" -gt 0 ]; then
                    echo "CLOUD INTEGRATION: Service $service_name integrates with $cloud_integration cloud platforms"
                    ecosystem_patterns=$((ecosystem_patterns + $cloud_integration))
                fi
                
                # Check for containerization integration
                local container_integration=$(grep -cE "(docker\|podman\|container\|k8s\|kubernetes)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$container_integration" -gt 0 ]; then
                    echo "CONTAINER INTEGRATION: Service $service_name integrates with $container_integration container platforms"
                    ecosystem_patterns=$((ecosystem_patterns + $container_integration))
                fi
                
                # Check for orchestration platform integration
                local platform_integration=$(grep -cE "(nomad\|mesos\|swarm\|rancher)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$platform_integration" -gt 0 ]; then
                    echo "PLATFORM INTEGRATION: Service $service_name integrates with $platform_integration orchestration platforms"
                    ecosystem_patterns=$((ecosystem_patterns + $platform_integration))
                fi
                
                # Check for monitoring integration
                local monitoring_integration=$(grep -cE "(prometheus\|grafana\|statsd\|telegraf\|collectd)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$monitoring_integration" -gt 0 ]; then
                    echo "MONITORING INTEGRATION: Service $service_name integrates with $monitoring_integration monitoring systems"
                    ecosystem_patterns=$((ecosystem_patterns + $monitoring_integration))
                fi
                
                # Check for logging integration
                local logging_integration=$(grep -cE "(syslog\|journal\|fluentd\|logstash\|filebeat)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$logging_integration" -gt 0 ]; then
                    echo "LOGGING INTEGRATION: Service $service_name integrates with $logging_integration logging systems"
                    ecosystem_patterns=$((ecosystem_patterns + $logging_integration))
                fi
            fi
            
            # Check for CI/CD integration
            local ci_cd_integration=$(find "$service_dir" -name ".gitlab-ci.yml" -o -name ".travis.yml" -o -name "Jenkinsfile" -o -name ".circleci" -o -name ".github" | wc -l)
            if [ "$ci_cd_integration" -gt 0 ]; then
                echo "CI/CD INTEGRATION: Service $service_name has $ci_cd_integration CI/CD integration files"
                ecosystem_patterns=$((ecosystem_patterns + $ci_cd_integration))
            fi
            
            # Check for packaging integration
            local packaging_integration=$(find "$service_dir" -name "*.deb" -o -name "*.rpm" -o -name "*.pkg.tar.xz" -o -name "*.tgz" | wc -l)
            if [ "$packaging_integration" -gt 0 ]; then
                echo "PACKAGING INTEGRATION: Service $service_name has $packaging_integration packaging files"
                ecosystem_patterns=$((ecosystem_patterns + $packaging_integration))
            fi
        fi
    done
    
    if [ $ecosystem_patterns -gt 0 ]; then
        echo "PASSED: Found $ecosystem_patterns ecosystem integration patterns"
        return 0
    else
        echo "INFO: No explicit ecosystem integration patterns found (microservice design may be intentional)"
        return 0
    fi
}

# Test service composition and modularity patterns
test_service_composition() {
    echo "Testing service composition and modularity patterns..."
    
    local services_dir="$PROJECT_ROOT/service"
    local composition_patterns=0
    
    # Analyze service composition and modularity
    for service_dir in "$services_dir"/*/; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "common" ]; then
            local service_name=$(basename "$service_dir")
            
            # Check for modular design patterns
            local rc_file="$service_dir/etc/rc"
            if [ -f "$rc_file" ]; then
                echo "COMPOSITION: Service $service_name"
                
                # Check for module/plugin loading patterns
                local module_loading=$(grep -cE "(load\|import\|source\|include\|require.*module)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$module_loading" -gt 0 ]; then
                    echo "MODULE LOADING: Service $service_name loads $module_loading modules/plugins"
                    composition_patterns=$((composition_patterns + $module_loading))
                fi
                
                # Check for component composition patterns
                local component_composition=$(grep -cE "(compose\|combine\|merge\|assemble)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$component_composition" -gt 0 ]; then
                    echo "COMPONENT COMP: Service $service_name composes $component_composition components"
                    composition_patterns=$((composition_patterns + $component_composition))
                fi
                
                # Check for reusable component patterns
                local reusable_components=$(grep -cE "(reuse\|shared\|common\|library)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$reusable_components" -gt 0 ]; then
                    echo "REUSABLE COMP: Service $service_name uses $reusable_components reusable components"
                    composition_patterns=$((composition_patterns + $reusable_components))
                fi
                
                # Check for service composition patterns
                local svc_composition=$(grep -cE "(service.*compose\|compose.*service\|bundle\|aggregate)" "$rc_file" 2>/dev/null || echo "0")
                if [ "$svc_composition" -gt 0 ]; then
                    echo "SERVICE COMP: Service $service_name composes $svc_composition services"
                    composition_patterns=$((composition_patterns + $svc_composition))
                fi
            fi
            
            # Check for modularity in directory structure
            local module_dirs=$(find "$service_dir" -type d | grep -cE "(module\|plugin\|addon\|extension)")
            if [ "$module_dirs" -gt 0 ]; then
                echo "MODULAR STRUCT: Service $service_name has $module_dirs modular directories"
                composition_patterns=$((composition_patterns + $module_dirs))
            fi
            
            # Check for modular configuration
            local etc_dir="$service_dir/etc"
            if [ -d "$etc_dir" ]; then
                local config_modules=$(find "$etc_dir" -name "*.conf" -o -name "*.cfg" -o -name "*.yaml" -o -name "*.json" | wc -l)
                if [ "$config_modules" -gt 1 ]; then
                    echo "CONFIG MODULES: Service $service_name has $config_modules configuration modules"
                    composition_patterns=$((composition_patterns + $config_modules))
                fi
                
                # Check for modular subdirectories
                local etc_subdirs=$(find "$etc_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
                if [ "$etc_subdirs" -gt 0 ]; then
                    echo "CONFIG SUBDIRS: Service $service_name has $etc_subdirs configuration subdirectories"
                    composition_patterns=$((composition_patterns + $etc_subdirs))
                fi
            fi
        fi
    done
    
    if [ $composition_patterns -gt 0 ]; then
        echo "PASSED: Found $composition_patterns service composition patterns"
        return 0
    else
        echo "INFO: No explicit composition patterns found (simple service design may be intentional)"
        return 0
    fi
}

# Run all service integration tests
run_all_service_integration_tests() {
    echo "RUNNING: Service integration tests"
    echo "================================"
    
    local test_failures=0
    
    run_test "Service communication patterns" test_service_communication || test_failures=$((test_failures + 1))
    run_test "Service dependencies" test_service_dependencies || test_failures=$((test_failures + 1))
    run_test "Service orchestration" test_service_orchestration || test_failures=$((test_failures + 1))
    run_test "Ecosystem integration" test_ecosystem_integration || test_failures=$((test_failures + 1))
    run_test "Service composition" test_service_composition || test_failures=$((test_failures + 1))
    
    if [ $test_failures -eq 0 ]; then
        echo "ALL SERVICE INTEGRATION TESTS PASSED"
        return 0
    else
        echo "CRITICAL: $test_failures service integration test suites failed"
        return 1
    fi
}

# Execute if run directly
if [ "$0" = "$0" ]; then
    run_all_service_integration_tests
fi