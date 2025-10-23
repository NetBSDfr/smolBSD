#!/bin/sh
#
# Test data fixture management for smolBSD tests
# Provides safe, isolated test data for all tests
#

# Source the test harness only if not already sourced
if [ -z "${TEST_TMPDIR:-}" ]; then
    . "$(dirname "$0")/test_harness.sh"
fi

# Create test fixtures in the temp directory
create_test_fixtures() {
    local fixtures_dir="$TEST_TMPDIR/fixtures"
    mkdir -p "$fixtures_dir"
    
    # Create minimal directories that mimic the real structure (portable way)
    mkdir -p "$fixtures_dir/service" "$fixtures_dir/rescue" "$fixtures_dir/common" \
             "$fixtures_dir/sets" "$fixtures_dir/etc" "$fixtures_dir/kernels" "$fixtures_dir/images"
    
    # Create a fake service directory structure
    mkdir -p "$fixtures_dir/service/rescue/etc"
    mkdir -p "$fixtures_dir/service/common"
    mkdir -p "$fixtures_dir/sets/amd64"
    
    # Create fake NetBSD set (minimal tar file)
    (
        cd "$fixtures_dir"
        echo "fake rescue content" > fake_file.txt
        tar -cf "sets/amd64/rescue.tar.xz" fake_file.txt 2>/dev/null || true
        rm -f fake_file.txt
    )
    
    # Create fake kernel file
    echo "fake kernel data" > "$fixtures_dir/kernels/fake-kernel"
    
    # Create fake common scripts
    echo '#!/bin/sh
export HOME=/
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
' > "$fixtures_dir/service/common/basicrc"
    
    # Create fake rescue config
    echo '#!/bin/sh
echo "Starting fake rescue service"
' > "$fixtures_dir/service/rescue/etc/rc"
    
    # Create fake etc files
    echo 'fake etc content' > "$fixtures_dir/etc/passwd"
    
    echo "Test fixtures created in $fixtures_dir"
    return 0
}

# Return path to test fixtures
get_fixtures_path() {
    echo "$TEST_TMPDIR/fixtures"
}

# Verify fixtures exist and are accessible
verify_fixtures() {
    local fixtures_dir="$TEST_TMPDIR/fixtures"
    
    if [ ! -d "$fixtures_dir" ]; then
        echo "FAIL: Test fixtures directory does not exist"
        return 1
    fi
    
    # Check for essential fixture components
    local required_paths="
        $fixtures_dir/service/rescue
        $fixtures_dir/service/common
        $fixtures_dir/sets/amd64
        $fixtures_dir/kernels
    "
    
    for path in $required_paths; do
        if [ ! -d "$path" ] && [ ! -f "$path" ]; then
            echo "FAIL: Required fixture path missing: $path"
            return 1
        fi
    done
    
    echo "PASS: Test fixtures verified"
    return 0
}

# Function to create a fake set file
create_fake_set() {
    local set_name="$1"
    local arch="${2:-amd64}"
    local sets_dir="$TEST_TMPDIR/fixtures/sets/$arch"
    
    mkdir -p "$sets_dir"
    
    # Create a fake file and tar it
    local temp_dir="$TEST_TMPDIR/temp_set"
    mkdir -p "$temp_dir"
    echo "fake $set_name content" > "$temp_dir/fake_file.txt"
    
    (cd "$temp_dir" && tar -cf "$sets_dir/$set_name" fake_file.txt 2>/dev/null || tar -czf "$sets_dir/$set_name" fake_file.txt 2>/dev/null)
    
    rm -rf "$temp_dir"
    
    if [ -f "$sets_dir/$set_name" ]; then
        echo "PASS: Created fake set $set_name"
        return 0
    else
        echo "FAIL: Failed to create fake set $set_name"
        return 1
    fi
}

# Only create test fixtures and export functions, don't run harness init again
# (Assumes test harness has already been sourced)

create_test_fixtures || return 1

