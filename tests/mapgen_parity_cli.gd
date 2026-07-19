extends SceneTree

func _initialize() -> void:
	var runner_script: Script = load("res://tests/TestRunner.gd")
	var runner: TestRunner = runner_script.new() as TestRunner
	var results: Dictionary = runner.run_test_class("TestMapgenParity")
	var failed: int = int(results["tests_failed"])
	print("Mapgen parity: %d passed, %d failed" % [int(results["tests_passed"]), failed])
	runner.current_test_instance.set_test_runner(null)
	runner.current_test_instance = null
	runner = null
	runner_script = null
	quit(0 if failed == 0 else 1)
