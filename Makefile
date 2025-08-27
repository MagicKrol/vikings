# ============================================================================
# Vikings Game - Makefile
# ============================================================================
#
# Purpose: Convenient make targets for common development tasks
#
# Usage:
#   make test              # Run all unit tests
#   make test-verbose      # Run tests with verbose output
#   make test-class CLASS=TestDummy  # Run specific test class
#   make test-xml          # Run tests and generate XML output
#   make help              # Show available targets
# ============================================================================

# Default Godot executable (can be overridden)
# On macOS, Godot is typically installed as an app bundle
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot

# Colors for output
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
BLUE := \033[34m
RESET := \033[0m

.PHONY: help test test-verbose test-class test-xml clean

# Default target
all: test

# Show help
help:
	@echo "$(BLUE)Vikings Game - Available Make Targets$(RESET)"
	@echo ""
	@echo "$(YELLOW)Testing:$(RESET)"
	@echo "  make test              Run all unit tests"
	@echo "  make test-verbose      Run tests with verbose output"
	@echo "  make test-xml          Run tests and generate XML output"
	@echo "  make test-class CLASS=TestDummy  Run specific test class"
	@echo ""
	@echo "$(YELLOW)Development:$(RESET)"
	@echo "  make clean             Clean generated files"
	@echo ""
	@echo "$(YELLOW)Environment:$(RESET)"
	@echo "  GODOT=path/to/godot    Override Godot executable path"
	@echo ""
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  make test CLASS=TestDummy"
	@echo "  GODOT=godot4 make test-verbose"

# Run all unit tests
test:
	@echo "$(BLUE)Running all unit tests...$(RESET)"
	@"$(GODOT)" --headless --script tests/cli_test_runner.gd
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)All tests passed!$(RESET)"; \
	else \
		echo "$(RED)Some tests failed$(RESET)"; \
		exit 1; \
	fi

# Run tests with verbose output
test-verbose:
	@echo "$(BLUE)Running all unit tests (verbose)...$(RESET)"
	@"$(GODOT)" --headless --script tests/cli_test_runner.gd -- --verbose

# Run specific test class
test-class:
ifndef CLASS
	@echo "$(RED)Error: CLASS parameter is required$(RESET)"
	@echo "Usage: make test-class CLASS=TestDummy"
	@exit 1
endif
	@echo "$(BLUE)Running test class: $(CLASS)$(RESET)"
	@"$(GODOT)" --headless --script tests/cli_test_runner.gd -- --class $(CLASS)

# Run tests and generate XML output
test-xml:
	@echo "$(BLUE)Running tests and generating XML output...$(RESET)"
	@"$(GODOT)" --headless --script tests/cli_test_runner.gd -- --xml
	@if [ -f test_results.xml ]; then \
		echo "$(GREEN)XML results generated: test_results.xml$(RESET)"; \
	fi

# Clean generated files
clean:
	@echo "$(BLUE)Cleaning generated files...$(RESET)"
	@rm -f test_results.xml
	@rm -f *.tmp
	@echo "$(GREEN)Clean complete$(RESET)"

# Quick aliases
t: test
tv: test-verbose
tx: test-xml
tc: test-class