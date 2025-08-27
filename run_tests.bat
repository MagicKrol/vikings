@echo off
REM ============================================================================
REM Vikings Game - Test Runner Script (Windows)
REM ============================================================================
REM
REM Purpose: Convenient batch script for running unit tests on Windows
REM
REM Usage:
REM   run_tests.bat                    REM Run all tests
REM   run_tests.bat TestDummy          REM Run specific test class
REM   run_tests.bat --verbose          REM Run with verbose output
REM   run_tests.bat --xml              REM Generate XML output for CI
REM   run_tests.bat --help             REM Show help
REM ============================================================================

setlocal EnableDelayedExpansion

REM Default Godot executable name
set "GODOT_EXEC=godot.exe"

REM Try to find Godot executable
where godot.exe >nul 2>nul
if %errorlevel% == 0 (
    set "GODOT_EXEC=godot.exe"
    goto :found_godot
)

where godot >nul 2>nul
if %errorlevel% == 0 (
    set "GODOT_EXEC=godot"
    goto :found_godot
)

where Godot.exe >nul 2>nul
if %errorlevel% == 0 (
    set "GODOT_EXEC=Godot.exe"
    goto :found_godot
)

echo ERROR: Godot executable not found in PATH
echo Please ensure Godot is installed and available in PATH
exit /b 1

:found_godot

REM Parse arguments
set "ARGS="
set "TEST_CLASS="

:parse_args
if "%~1"=="" goto :run_tests
if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help
if "%~1"=="--verbose" (
    set "ARGS=%ARGS% --verbose"
    shift
    goto :parse_args
)
if "%~1"=="-v" (
    set "ARGS=%ARGS% --verbose"
    shift
    goto :parse_args
)
if "%~1"=="--xml" (
    set "ARGS=%ARGS% --xml"
    shift
    goto :parse_args
)

REM Check if it's a test class name (starts with "Test")
echo %~1 | findstr /b "Test" >nul
if %errorlevel% == 0 (
    set "TEST_CLASS=%~1"
    set "ARGS=%ARGS% --class %~1"
    shift
    goto :parse_args
)

echo Unknown option: %~1
goto :show_help

:show_help
echo Vikings Game - Unit Test Runner
echo.
echo USAGE:
echo   %~nx0 [OPTIONS] [TEST_CLASS]
echo.
echo OPTIONS:
echo   --verbose, -v     Enable verbose output
echo   --xml            Generate JUnit XML output
echo   --help, -h       Show this help message
echo.
echo EXAMPLES:
echo   %~nx0                    ^& REM Run all tests
echo   %~nx0 TestDummy          ^& REM Run specific test class
echo   %~nx0 --verbose          ^& REM Run all tests with verbose output
echo   %~nx0 --xml              ^& REM Run all tests and generate XML
echo.
exit /b 0

:run_tests
echo Starting Vikings Game Unit Tests...
echo Using Godot executable: %GODOT_EXEC%

if not "%TEST_CLASS%"=="" (
    echo Running test class: %TEST_CLASS%
) else (
    echo Running all tests
)

echo.

REM Run the tests
%GODOT_EXEC% --headless --script tests/cli_test_runner.gd -- %ARGS%
set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% == 0 (
    echo ✓ All tests passed!
) else (
    echo ✗ Some tests failed ^(exit code: %EXIT_CODE%^)
)

exit /b %EXIT_CODE%