extends Node

const CONTROLLER_PATH := "res://scripts/systems/world_generation/exploration_mode_controller.gd"
const TEST_PATH := "res://tests/test_exploration_mode_smoke.gd"

func _ready() -> void:
	_patch_controller()
	_patch_test()
	print("FIRST_EXPLORATION_CHAMBER_PATCHED central=true tutorial_only=true")
	get_tree().quit()

func _replace_exact(source: String, old_text: String, new_text: String, label: String) -> String:
	assert(source.contains(old_text), "Patch target missing: %s" % label)
	return source.replace(old_text, new_text)

func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not open %s for writing" % path)
	file.store_string(source)
	file.close()

func _patch_controller() -> void:
	var source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	source = _replace_exact(
		source,
		"const FIRST_NEST_CELL := Vector2i(-4, 6)",
		"const FIRST_NEST_CELL := Vector2i(0, 6)",
		"central first nest"
	)
	source = _replace_exact(
		source,
		"# warning signs -> buried chamber -> defenders and a living nest -> artifact clue\n# -> artifact power and a two-way return shortcut. Deeper nests/artifacts remain\n# available so the complete run can still reach the bottom boss.",
		"# one-time central tutorial chamber -> defenders and a living nest -> artifact clue\n# -> artifact power and a two-way return shortcut. Later nests stay optional, so\n# the long-term loop returns to free mining instead of constant forced encounters.",
		"mode intent comment"
	)
	source = _replace_exact(
		source,
		"hud.show_notice(\"EXPLORATION: descend and listen. Nearby threats reveal themselves before you break through.\", 5.5)",
		"hud.show_notice(\"EXPLORATION: the first disturbance blocks the central descent. Clear it once; later nests are optional.\", 5.5)",
		"opening notice"
	)
	source = _replace_exact(
		source,
		"hud.show_notice(\"You hear creatures behind the rock. Follow the directional warning if you want to investigate.\", 4.0)",
		"hud.show_notice(\"Something alive blocks the central descent. Break through when you are ready.\", 4.0)",
		"tutorial warning notice"
	)
	source = _replace_exact(
		source,
		"hint_label.text = \"Dig deeper. Nearby threats announce themselves before discovery.\"",
		"hint_label.text = \"Dig deeper. The first chamber teaches nests; later discoveries are optional.\"",
		"default exploration hint"
	)
	_write(CONTROLLER_PATH, source)

func _patch_test() -> void:
	var source := FileAccess.get_file_as_string(TEST_PATH)
	source = _replace_exact(
		source,
		"const FIRST_NEST_CELL := Vector2i(-4, 6)",
		"const FIRST_NEST_CELL := Vector2i(0, 6)",
		"test first nest position"
	)
	source = _replace_exact(
		source,
		"const CHAMBER_ENTRY_PATH := [Vector2i(-1, 2), Vector2i(-1, 3), Vector2i(-1, 4), Vector2i(-1, 5)]",
		"const CHAMBER_ENTRY_PATH := [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]",
		"test central entry path"
	)
	source = _replace_exact(
		source,
		"assert(level.get_node(\"BlockLayer\").get_cell_source_id(FIRST_NEST_CELL) == -1, \"The first nest should sit inside a pre-carved buried chamber\")",
		"assert(level.get_node(\"BlockLayer\").get_cell_source_id(FIRST_NEST_CELL) == -1, \"The first nest should sit inside a pre-carved chamber on the central descent\")\n\tassert(FIRST_NEST_CELL.x == 0, \"The tutorial chamber must interrupt the central shaft instead of hiding on a side route\")",
		"test mandatory central chamber"
	)
	_write(TEST_PATH, source)
