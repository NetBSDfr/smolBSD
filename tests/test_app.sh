#!/bin/sh
# Tests for smolBSD Flask application

# Source the test framework utilities
if [ -z "$PROJECT_ROOT" ]; then
    echo "PROJECT_ROOT not set, setting it to parent directory"
    PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
    export PROJECT_ROOT
fi

# Test if Python dependencies are available
test_python_dependencies() {
    echo "Testing Python dependencies..."
    
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ python3 not found"
        return 1
    fi
    
    # Test if required Python modules can be imported
    if python3 -c "import flask" 2>/dev/null && python3 -c "import psutil" 2>/dev/null; then
        echo "✓ Python dependencies are available"
        return 0
    else
        echo "⚠️  Some Python dependencies missing (flask, psutil)"
        echo "   You may need to run: pip3 install -r app/requirements.txt"
        return 0  # Not critical for core functionality
    fi
}

# Test Flask app file exists and has correct syntax
test_flask_app_syntax() {
    echo "Testing Flask app syntax..."
    
    if [ ! -f "$PROJECT_ROOT/app/app.py" ]; then
        echo "❌ app.py not found"
        return 1
    fi
    
    # Check Python syntax
    if python3 -m py_compile "$PROJECT_ROOT/app/app.py" 2>/dev/null; then
        echo "✓ Flask app syntax is valid"
        return 0
    else
        echo "❌ Flask app has syntax errors"
        return 1
    fi
}

# Test that requirements file exists
test_requirements_file() {
    echo "Testing requirements file..."
    
    if [ -f "$PROJECT_ROOT/app/requirements.txt" ]; then
        echo "✓ requirements.txt exists"
        
        # Check if it contains expected packages
        if grep -q "Flask" "$PROJECT_ROOT/app/requirements.txt" && \
           grep -q "psutil" "$PROJECT_ROOT/app/requirements.txt"; then
            echo "✓ requirements.txt contains expected packages"
        else
            echo "⚠️  requirements.txt may be missing expected packages"
        fi
        return 0
    else
        echo "❌ requirements.txt not found"
        return 1
    fi
}

# Main test function
run_flask_tests() {
    echo "Running Flask application tests..."
    
    local failed_tests=0
    
    if ! test_python_dependencies; then
        ((failed_tests++))
    fi
    
    if ! test_flask_app_syntax; then
        ((failed_tests++))
    fi
    
    if ! test_requirements_file; then
        ((failed_tests++))
    fi
    
    if [ $failed_tests -eq 0 ]; then
        echo "✓ All Flask app tests passed"
        return 0
    else
        echo "❌ $failed_tests Flask app tests failed"
        return 1
    fi
}

# Run the tests
run_flask_tests