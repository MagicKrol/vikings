extends SceneTree
class_name CLITestRunner

# ============================================================================
# COMMAND LINE TEST RUNNER
# ============================================================================
# 
# Purpose: Dedicated command-line test runner with argument parsing
# 
# Usage:
# godot --headless --script tests/cli_test_runner.gd
# godot --headless --script tests/cli_test_runner.gd -- --class TestDummy
# godot --headless --script tests/cli_test_runner.gd -- --help
# 
# Arguments:
# --class <TestClassName>  Run specific test class
# --verbose               Enable verbose output
# --xml                   Output results in JUnit XML format
# --help                  Show help message
# ============================================================================

var verbose_mode: bool = false
var xml_output: bool = false
var target_class: String = ""

func _initialize():
	"""Parse command line arguments and run tests"""
	var args = OS.get_cmdline_args()
	_parse_arguments(args)
	
	if args.has("--help") or args.has("-h"):
		_print_help()
		quit(0)
		return
	
	DebugLogger.log("Testing", "[CLI Test Runner] Starting test execution...")
	
	# Load and create test runner directly
	var TestRunnerScript = load("res://tests/TestRunner.gd")
	var runner = TestRunnerScript.new()
	var results: Dictionary
	if target_class != "":
		DebugLogger.log("Testing", "[CLI Test Runner] Running specific test class: " + target_class)
		results = runner.run_test_class(target_class)
	else:
		DebugLogger.log("Testing", "[CLI Test Runner] Running all tests")
		results = runner.run_all_tests()
	
	if xml_output:
		_output_junit_xml(results)
	
	if verbose_mode:
		_print_detailed_results(results)
	
	# Exit with appropriate code
	var exit_code = 0 if results.tests_failed == 0 else 1
	DebugLogger.log("Testing", "\n[CLI Test Runner] Exiting with code: " + str(exit_code))
	quit(exit_code)

func _parse_arguments(args: PackedStringArray) -> void:
	"""Parse command line arguments"""
	var i = 0
	while i < args.size():
		var arg = args[i]
		
		match arg:
			"--verbose", "-v":
				verbose_mode = true
			"--xml":
				xml_output = true
			"--class", "-c":
				if i + 1 < args.size():
					target_class = args[i + 1]
					i += 1
			"--help", "-h":
				_print_help()
				quit(0)
				return
		
		i += 1

func _print_help() -> void:
	"""Print help message"""
	print("""
Vikings Game - Unit Test Runner

USAGE:
    godot --headless --script tests/cli_test_runner.gd [OPTIONS]

OPTIONS:
    --class <TestClassName>    Run only the specified test class
    -c <TestClassName>         Short form of --class
    
    --verbose                  Enable verbose output with detailed results
    -v                         Short form of --verbose
    
    --xml                      Output results in JUnit XML format
    
    --help                     Show this help message
    -h                         Short form of --help

EXAMPLES:
    # Run all tests
    godot --headless --script tests/cli_test_runner.gd
    
    # Run specific test class
    godot --headless --script tests/cli_test_runner.gd -- --class TestDummy
    
    # Run with verbose output
    godot --headless --script tests/cli_test_runner.gd -- --verbose
    
    # Run with XML output for CI systems
    godot --headless --script tests/cli_test_runner.gd -- --xml
""")

func _print_detailed_results(results: Dictionary) -> void:
	"""Print detailed test results"""
	DebugLogger.log("Testing", "\n=== DETAILED RESULTS ===")
	DebugLogger.log("Testing", "Total Tests: " + str(results.tests_run))
	DebugLogger.log("Testing", "Passed: " + str(results.tests_passed))
	DebugLogger.log("Testing", "Failed: " + str(results.tests_failed))
	DebugLogger.log("Testing", "Success Rate: " + str(int(results.success_rate * 100)) + "%")
	
	if results.results.size() > 0:
		DebugLogger.log("Testing", "\nTEST DETAILS:")
		for result in results.results:
			var status = "PASS" if result.success else "FAIL"
			DebugLogger.log("Testing", "  [" + status + "] " + result.class + "::" + result.method)
			if not result.success and result.error != "":
				DebugLogger.log("Testing", "    Error: " + result.error)

func _output_junit_xml(results: Dictionary) -> void:
	"""Output results in JUnit XML format for CI systems"""
	var xml_content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	xml_content += "<testsuite "
	xml_content += "name=\"Vikings Game Tests\" "
	xml_content += "tests=\"" + str(results.tests_run) + "\" "
	xml_content += "failures=\"" + str(results.tests_failed) + "\" "
	xml_content += "time=\"0\">\n"
	
	for result in results.results:
		xml_content += "  <testcase "
		xml_content += "classname=\"" + result.class + "\" "
		xml_content += "name=\"" + result.method + "\" "
		xml_content += "time=\"0\""
		
		if not result.success:
			xml_content += ">\n"
			xml_content += "    <failure message=\"Test failed\">"
			xml_content += result.error.xml_escape()
			xml_content += "</failure>\n"
			xml_content += "  </testcase>\n"
		else:
			xml_content += "/>\n"
	
	xml_content += "</testsuite>\n"
	
	# Write to file
	var file = FileAccess.open("test_results.xml", FileAccess.WRITE)
	if file:
		file.store_string(xml_content)
		file.close()
		DebugLogger.log("Testing", "[CLI Test Runner] JUnit XML results written to: test_results.xml")
	else:
		DebugLogger.log("Testing", "[CLI Test Runner] ERROR: Could not write XML results file")