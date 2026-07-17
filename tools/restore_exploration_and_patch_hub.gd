extends Node

const EXPLORATION_BACKUP := "res://.godot-mcp/backups/2026-07-17T17-47-22.429Z/scripts/systems/world_generation/exploration_mode_controller.gd"
const EXPLORATION_TARGET := "res://scripts/systems/world_generation/exploration_mode_controller.gd"
const HUB_CONTROLLER := "res://scripts/systems/preparation/preparation_world_controller.gd"
const PROJECT_FILE := "res://project.godot"
const MAIN_MENU := "res://scripts/ui/menus/main/menu.gd"
const SIEGE_BOOTSTRAP := "res://siege_mode_bootstrap.gd"
const EXPLORATION_BOOTSTRAP := "res://exploration_mode_bootstrap.gd"

func _ready() -> void:
	_restore_exploration()
	_patch_project()
	_patch_main_menu()
	_patch_bootstraps()
	_patch_hub()
	print("MINEWARS_DIRECTIONAL_HUB_OK")
	get_tree().quit()

func _read(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Could not read non-empty file: %s" % path)
	return text

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not open file for writing: %s" % path)
	file.store_string(text)
	file.close()

func _replace_once(source: String, old_text: String, new_text: String, label: String) -> String:
	if source.contains(new_text):
		return source
	assert(source.contains(old_text), "Patch target missing: %s" % label)
	return source.replace(old_text, new_text)

func _restore_exploration() -> void:
	var backup := _read(EXPLORATION_BACKUP)
	assert(backup.length() > 1000, "Adventure controller backup is unexpectedly small")
	_write(EXPLORATION_TARGET, backup)

func _patch_project() -> void:
	var source := _read(PROJECT_FILE)
	source = _replace_once(
		source,
		"GameModeMenuBootstrap=\"*res://game_mode_menu_bootstrap.gd\"",
		"SiegeModeBootstrap=\"*res://siege_mode_bootstrap.gd\"",
		"replace temporary mode menu bootstrap"
	)
	_write(PROJECT_FILE, source)

func _patch_main_menu() -> void:
	var source := _read(MAIN_MENU)
	source = _replace_once(
		source,
		"func _on_single_player_pressed() -> void:\n\tGameMode.set_mode(GameMode.Mode.EXPLORATION)",
		"func _on_single_player_pressed() -> void:\n\t# Single Player always enters the shared overworld. The player chooses the\n\t# actual destination physically from there.\n\tGameMode.set_mode(GameMode.Mode.SIEGE)",
		"single player enters shared overworld"
	)
	_write(MAIN_MENU, source)

func _patch_bootstraps() -> void:
	var siege := _read(SIEGE_BOOTSTRAP)
	siege = _replace_once(
		siege,
		"\tif bool(node.get(\"is_vs_mode\")) or node.has_node(\"SiegeModeController\"):",
		"\tif bool(node.get(\"is_vs_mode\")) or bool(node.get(\"preparation_mode\")) or node.has_node(\"SiegeModeController\"):",
		"siege ignores overworld preparation level"
	)
	_write(SIEGE_BOOTSTRAP, siege)

	var adventure := _read(EXPLORATION_BOOTSTRAP)
	adventure = _replace_once(
		adventure,
		"\tif bool(node.get(\"is_vs_mode\")) or node.has_node(\"ExplorationModeController\"):",
		"\tif bool(node.get(\"is_vs_mode\")) or bool(node.get(\"preparation_mode\")) or node.has_node(\"ExplorationModeController\"):",
		"adventure ignores overworld preparation level"
	)
	_write(EXPLORATION_BOOTSTRAP, adventure)

func _patch_hub() -> void:
	var source := _read(HUB_CONTROLLER)
	source = _replace_once(
		source,
		"const START_Y := 104.0\nconst START_HALF_WIDTH := 112.0",
		"const RUN_SCENE := \"res://scenes/boot/main.tscn\"\nconst LINE_WARS_SCENE := \"res://maze_vs_prototype.tscn\"\nconst MINEWARS_GATE_Y := 104.0\nconst MINEWARS_GATE_HALF_WIDTH := 112.0\nconst LINE_WARS_GATE_Y := -270.0\nconst LINE_WARS_GATE_HALF_WIDTH := 92.0\nconst ADVENTURE_GATE_X := 338.0\nconst ADVENTURE_GATE_MIN_Y := -36.0\nconst ADVENTURE_GATE_MAX_Y := 108.0",
		"directional gate constants"
	)
	source = _replace_once(
		source,
		"\t_build_world_choices()\n\t_build_interface()",
		"\t_carve_mode_routes()\n\t_build_world_choices()\n\t_build_interface()",
		"carve overworld mode routes"
	)
	source = _replace_once(
		source,
		"\tif player.position.y >= START_Y and absf(player.position.x) <= START_HALF_WIDTH:\n\t\t_begin_run()",
		"\tif player.position.y >= MINEWARS_GATE_Y and absf(player.position.x) <= MINEWARS_GATE_HALF_WIDTH:\n\t\t_begin_mode(GameMode.Mode.SIEGE, RUN_SCENE, \"Descending into MineWars...\")\n\telif player.position.y <= LINE_WARS_GATE_Y and absf(player.position.x) <= LINE_WARS_GATE_HALF_WIDTH:\n\t\t_begin_mode(GameMode.Mode.LINE_WARS, LINE_WARS_SCENE, \"Marching to the Line Wars battlefield...\")\n\telif player.position.x >= ADVENTURE_GATE_X and player.position.y >= ADVENTURE_GATE_MIN_Y and player.position.y <= ADVENTURE_GATE_MAX_Y:\n\t\t_begin_mode(GameMode.Mode.EXPLORATION, RUN_SCENE, \"Setting out on an Adventure...\")",
		"directional gate detection"
	)
	source = _replace_once(
		source,
		"func _build_world_choices() -> void:",
		"func _carve_mode_routes() -> void:\n\t# Extend the already-existing preparation room into three readable exits.\n\t# Down remains the mine shaft, up becomes the battlefield road, and the\n\t# eastern corridor leads to Adventure.\n\tvar previous_generation_flag := bool(world.world_generation_in_progress)\n\tworld.world_generation_in_progress = true\n\tfor x in range(-1, 2):\n\t\tfor y in range(-7, -4):\n\t\t\tworld.on_cell_dug(Vector2i(x, y))\n\tfor x in range(5, 9):\n\t\tfor y in range(-2, 2):\n\t\t\tworld.on_cell_dug(Vector2i(x, y))\n\tworld.world_generation_in_progress = previous_generation_flag\n\nfunc _build_world_choices() -> void:",
		"mode route carving helper"
	)
	source = _replace_once(source, "\ttunnel_marker.name = \"TunnelStartMarker\"", "\ttunnel_marker.name = \"MineWarsGateMarker\"", "minewars marker name")
	source = _replace_once(source, "\tgate_label.text = \"DESCEND TO START\"", "\tgate_label.text = \"MINEWARS\"", "minewars gate label")
	source = _replace_once(
		source,
		"\ttunnel_marker.add_child(gate_label)\n\nfunc _create_hero_pad",
		"\ttunnel_marker.add_child(gate_label)\n\n\t_create_mode_gate(choices_root, \"LineWarsGateMarker\", Vector2(0, -292), \"LINE WARS\", Color(1.0, 0.48, 0.2, 1.0), false)\n\t_create_mode_gate(choices_root, \"AdventureGateMarker\", Vector2(368, 36), \"ADVENTURE\", Color(0.42, 1.0, 0.48, 1.0), true)\n\nfunc _create_mode_gate(parent: Node2D, gate_name: String, gate_position: Vector2, gate_text: String, accent: Color, points_right: bool) -> void:\n\tvar marker := Node2D.new()\n\tmarker.name = gate_name\n\tmarker.position = gate_position\n\tmarker.z_index = 8\n\tparent.add_child(marker)\n\tvar glow := Polygon2D.new()\n\tif points_right:\n\t\tglow.polygon = PackedVector2Array([Vector2(-30, -66), Vector2(42, -66), Vector2(92, 0), Vector2(42, 66), Vector2(-30, 66)])\n\telse:\n\t\tglow.polygon = PackedVector2Array([Vector2(-92, 32), Vector2(-44, -34), Vector2(0, -78), Vector2(44, -34), Vector2(92, 32)])\n\tglow.color = Color(accent.r, accent.g, accent.b, 0.2)\n\tmarker.add_child(glow)\n\tvar outline := Line2D.new()\n\toutline.closed = true\n\toutline.points = glow.polygon\n\toutline.width = 4.0\n\toutline.default_color = Color(accent.r, accent.g, accent.b, 0.92)\n\tmarker.add_child(outline)\n\tvar label := Label.new()\n\tlabel.position = Vector2(-100, -12) if points_right else Vector2(-105, 20)\n\tlabel.size = Vector2(200, 30)\n\tlabel.text = gate_text\n\tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tlabel.add_theme_font_size_override(\"font_size\", 16)\n\tlabel.add_theme_color_override(\"font_color\", accent)\n\tlabel.add_theme_color_override(\"font_outline_color\", Color.BLACK)\n\tlabel.add_theme_constant_override(\"outline_size\", 4)\n\tmarker.add_child(label)\n\nfunc _create_hero_pad",
		"up and right gate visuals"
	)
	source = _replace_once(source, "\ttitle.text = \"PREPARE AT THE MINE ENTRANCE\"", "\ttitle.text = \"PREPARE, THEN CHOOSE YOUR PATH\"", "overworld title")
	source = _replace_once(source, "\tstatus_label.text = \"Walk to a side-wall hero or a back-wall base to inspect and select it.\"", "\tstatus_label.text = \"Choose a hero and base, then go up, down, or right to begin.\"", "initial directional status")
	source = _replace_once(
		source,
		"\tinstructions.text = \"Move normally  •  Approach a statue to inspect/select  •  Walk down the center shaft to begin\"",
		"\tinstructions.text = \"↑ LINE WARS   •   ↓ MINEWARS   •   → ADVENTURE   •   Approach statues to change hero or base\"",
		"directional instructions"
	)
	source = source.replace("Walk to a side-wall hero or a back-wall base to inspect and select it.", "Choose a hero and base, then take a marked path.")
	source = source.replace("This hero will enter the mine.", "This hero will enter the selected destination.")
	source = _replace_once(
		source,
		"func _begin_run() -> void:\n\t_started = true\n\tGlobal.apply_selected_loadout()\n\tGlobal.save_game()\n\tbase.set_process(true)\n\tbase.set_process_input(true)\n\t_enable_runtime_upgrade_menu()\n\tvar choices := world.get_node_or_null(\"LoadoutChoices\")\n\tif choices:\n\t\tchoices.queue_free()\n\tif interface:\n\t\tinterface.queue_free()\n\tworld.begin_run_from_preparation()\n\tvar hud := world.get_node_or_null(\"HUD\")\n\tif hud and hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"Loadout confirmed. The run starts now.\", 2.2)\n\tqueue_free()",
		"func _begin_mode(mode: GameMode.Mode, scene_path: String, transition_text: String) -> void:\n\tif _started:\n\t\treturn\n\t_started = true\n\tGameMode.set_mode(mode)\n\tGlobal.apply_selected_loadout()\n\tGlobal.save_game()\n\tplayer.velocity = Vector2.ZERO\n\tplayer.movement_enabled = false\n\tstatus_label.text = transition_text\n\tawait get_tree().create_timer(0.16).timeout\n\tget_tree().change_scene_to_file(scene_path)",
		"mode-specific transition"
	)
	_write(HUB_CONTROLLER, source)
