extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_suites")

func _run_suites() -> void:
	var runner := McpTestRunner.new()
	var suite_paths := [
		"res://tests/test_hud_module_layout.gd",
		"res://tests/test_upgrade_tree_layout.gd",
		"res://tests/test_upgrade_tree_ui.gd"
	]
	var total_passed := 0
	var total_failed := 0
	
	for path in suite_paths:
		var script := load(path)
		if script == null:
			print("[ERROR] Could not load suite: ", path)
			total_failed += 1
			continue
		var suite: McpTestSuite = script.new()
		runner.run_suite(suite)
		for r in runner._results:
			if r.get("passed", false):
				print("  ✓ [", r.get("suite", ""), "] ", r.get("test", ""), " -> PASS")
				total_passed += 1
			else:
				print("  ✗ [", r.get("suite", ""), "] ", r.get("test", ""), " -> FAIL: ", r.get("message", ""))
				total_failed += 1
		runner._results.clear()
	
	print("\nUI Verification Summary: %d Passed, %d Failed" % [total_passed, total_failed])
	get_tree().quit(0 if total_failed == 0 else 1)
