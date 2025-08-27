#!/bin/bash

# ============================================================================
# Vikings Game - Test Runner Script
# ============================================================================
# 
# Purpose: Convenient shell script for running unit tests
# 
# Usage:
#   ./Users/magic/vikings/run_tests.sh                    # Run all tests
#   ./Users/magic/vikingsrun_tests.sh TestDummy          # Run specific test class
#   ./Users/magic/vikings/run_tests.sh --verbose          # Run with verbose output
#   ./Users/magic/vikings/run_tests.sh --xml              # Generate XML output for CI
#   ./Users/magic/vikings/run_tests.sh --help             # Show help
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default Godot executable (use absolute path as set by user)
GODOT_EXEC="/Applications/Godot.app/Contents/MacOS/Godot"

# Function to find Godot executable
find_godot() {
    # Try different common names for Godot executable
    local godot_names=("godot" "godot4" "Godot" "godot.exe")
    
    for name in "${godot_names[@]}"; do
        if command -v "$name" >/dev/null 2>&1; then
            GODOT_EXEC="$name"
            return 0
        fi
    done
    
    echo -e "${RED}ERROR: Godot executable not found in PATH${NC}"
    echo "Please ensure Godot is installed and available in PATH"
    echo "Or set GODOT_EXEC environment variable to the full path"
    return 1
}

# Function to show help
show_help() {
    echo -e "${BLUE}Vikings Game - Unit Test Runner${NC}"
    echo
    echo "USAGE:"
    echo "  $0 [OPTIONS] [TEST_CLASS]"
    echo
    echo "OPTIONS:"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --xml            Generate JUnit XML output"
    echo "  --help, -h       Show this help message"
    echo
    echo "EXAMPLES:"
    echo "  $0                    # Run all tests"
    echo "  $0 TestDummy          # Run specific test class"
    echo "  $0 --verbose          # Run all tests with verbose output"
    echo "  $0 --xml              # Run all tests and generate XML"
    echo
    echo "ENVIRONMENT VARIABLES:"
    echo "  GODOT_EXEC           Path to Godot executable (default: godot)"
    echo
}

# Function to run tests
run_tests() {
    local args=()
    local test_class=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                args+=("--verbose")
                shift
                ;;
            --xml)
                args+=("--xml")
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            Test*)
                test_class="$1"
                args+=("--class" "$test_class")
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}Starting Vikings Game Unit Tests...${NC}"
    echo -e "${YELLOW}Using Godot executable: $GODOT_EXEC${NC}"
    
    if [[ -n "$test_class" ]]; then
        echo -e "${YELLOW}Running test class: $test_class${NC}"
    else
        echo -e "${YELLOW}Running all tests${NC}"
    fi
    
    echo
    
    # Run the tests
    "$GODOT_EXEC" --headless --script /Users/magic/vikings/tests/cli_test_runner.gd -- "${args[@]}"
    local exit_code=$?
    
    echo
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
    else
        echo -e "${RED}✗ Some tests failed (exit code: $exit_code)${NC}"
    fi
    
    exit $exit_code
}

# Main execution
main() {
    # Check if GODOT_EXEC is set in environment
    if [[ -n "$GODOT_EXEC_ENV" ]]; then
        GODOT_EXEC="$GODOT_EXEC_ENV"
    fi
    
    # Find Godot executable if not explicitly set
    if ! command -v "$GODOT_EXEC" >/dev/null 2>&1; then
        find_godot || exit 1
    fi
    
    # Run the tests
    run_tests "$@"
}

# Execute main function with all arguments
main "$@"