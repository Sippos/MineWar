extends Node

## Test suite verifying POLISH-030:
## 1. Procedural generation of 3 distinct sub-surface anomaly chambers
## 2. Dense stone perimeter sealing (hard rock border cells surrounding open vault)
## 3. Acoustic & visual discovery cues when digging adjacent to borders
## 4. Unearthing chamber when breaking the dense perimeter
## 5. RelicShrine entity activation and flare effects
## 6. Expedition modifiers & passive buffs applied to player
## 7. Retrospective Quantic Foundry Discovery scoring (+300 pts per anomaly)

const LEVEL_SCENE := preload("res://scenes/world/mine/level.tscn")
const SUMMARY_DATA_SCRIPT: GDScript = preload("res://scripts/systems/gameplay/run_summary_data.gd")
const TEST_SAVE_PATH := "user://test_biome_anomalies.save"

var failures := 0
var level: Node2D
var player: CharacterBody2D
var hud: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_all_tests")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _finish() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	Global.set_save_path_override("")
	if failures == 0:
		print("BIOME_ANOMALIES_PASS")
		get_tree().quit(0)
	else:
		print("BIOME_ANOMALIES_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _run_all_tests() -> void:
	await _setup_environment()
	_test_procedural_anomaly_generation()
	_test_dense_stone_sealing()
	_test_discovery_cue_and_detection()
	_test_unearthing_and_relic_activation()
	_test_expedition_modifier_buffs()
	_test_run_summary_score_with_anomalies()
	_finish()

func _setup_environment() -> void:
	Global.set_save_path_override(TEST_SAVE_PATH)
	GameMode.set_mode(GameMode.Mode.SIEGE)
	level = LEVEL_SCENE.instantiate()
	level.set("is_vs_mode", false)
	level.set("preparation_mode", false)
	add_child(level)
	await _wait_frames(10)
	player = level.get_node_or_null("Player") as CharacterBody2D
	hud = level.get_node_or_null("HUD")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	_expect(level != null and player != null, "Level and Player should instantiate cleanly")

func _test_procedural_anomaly_generation() -> void:
	var chambers: Dictionary = level.call("get_anomaly_chambers")
	_expect(chambers.size() >= 3, "World generation should seed at least 3 anomaly chambers (got %d)" % chambers.size())
	_expect(chambers.has("ancient_steam_pump"), "Chambers must include 'ancient_steam_pump'")
	_expect(chambers.has("magma_seam"), "Chambers must include 'magma_seam'")
	_expect(chambers.has("geode_shrine"), "Chambers must include 'geode_shrine'")

	for chamber_id in ["ancient_steam_pump", "magma_seam", "geode_shrine"]:
		if not chambers.has(chamber_id):
			continue
		var chamber: Dictionary = chambers[chamber_id]
		var border: Array = chamber.get("border_cells", [])
		var interior: Array = chamber.get("interior_cells", [])
		var shrine: Node = chamber.get("shrine")
		_expect(not border.is_empty(), "%s must generate border cells" % chamber_id)
		_expect(not interior.is_empty(), "%s must generate interior cells" % chamber_id)
		_expect(shrine != null and is_instance_valid(shrine), "%s must instantiate a RelicShrine node" % chamber_id)

func _test_dense_stone_sealing() -> void:
	var chambers: Dictionary = level.call("get_anomaly_chambers")
	var block_layer: TileMapLayer = level.get_node_or_null("BlockLayer") as TileMapLayer
	_expect(block_layer != null, "BlockLayer must exist")

	var pump_chamber: Dictionary = chambers.get("ancient_steam_pump", {})
	var border_cells: Array = pump_chamber.get("border_cells", [])
	var interior_cells: Array = pump_chamber.get("interior_cells", [])

	var borders_solid := true
	for cell_val in border_cells:
		var cell: Vector2i = cell_val
		var source_id: int = block_layer.get_cell_source_id(cell)
		if source_id != 3:
			borders_solid = false
			break
	_expect(borders_solid, "All anomaly border cells must be sealed with dense stone (source id 3)")

	var interior_open := true
	for cell_val in interior_cells:
		var cell: Vector2i = cell_val
		var source_id: int = block_layer.get_cell_source_id(cell)
		if source_id != -1:
			interior_open = false
			break
	_expect(interior_open, "Anomaly chamber interior vault must be hollowed and open for the shrine")

func _test_discovery_cue_and_detection() -> void:
	var chambers: Dictionary = level.call("get_anomaly_chambers")
	var pump_chamber: Dictionary = chambers.get("ancient_steam_pump", {})
	_expect(not bool(pump_chamber.get("discovered")), "Chamber must initially be undiscovered")
	_expect(not bool(pump_chamber.get("unearthed")), "Chamber must initially be un-unearthed")

	var border_cells: Array = pump_chamber.get("border_cells", [])
	if border_cells.is_empty():
		return
	var first_border: Vector2i = border_cells[0]
	var adjacent_exterior := Vector2i(first_border.x - 1, first_border.y)

	level.call("on_cell_dug", adjacent_exterior)
	_expect(bool(pump_chamber.get("discovered")), "Mining adjacent to dense border must trigger discovery")
	_expect(not bool(pump_chamber.get("unearthed")), "Discovery must not prematurely unearth the chamber")
	_expect(int(level.call("get_anomalies_unearthed")) == 0, "No anomalies should be recorded as unearthed before perimeter breach")

func _test_unearthing_and_relic_activation() -> void:
	var chambers: Dictionary = level.call("get_anomaly_chambers")
	var pump_chamber: Dictionary = chambers.get("ancient_steam_pump", {})
	var border_cells: Array = pump_chamber.get("border_cells", [])
	if border_cells.is_empty():
		return
	var breach_cell: Vector2i = border_cells[0]

	level.call("on_cell_dug", breach_cell)
	_expect(bool(pump_chamber.get("unearthed")), "Breaching border cell must unearth the anomaly chamber")
	_expect(int(level.call("get_anomalies_unearthed")) == 1, "anomalies_unearthed must increment to 1")

	var active_mods: Array = level.call("get_active_anomaly_modifiers")
	_expect(active_mods.has("ancient_steam_pump"), "active_anomaly_modifiers must record 'ancient_steam_pump'")

	var shrine: Node = pump_chamber.get("shrine")
	_expect(shrine != null and bool(shrine.get("is_active")), "RelicShrine must transition to active state on unearthing")

func _test_expedition_modifier_buffs() -> void:
	_expect(player.get("active_anomaly_buffs").has("ancient_steam_pump"), "Player must receive 'ancient_steam_pump' buff")
	_expect(float(player.get("anomaly_speed_bonus")) >= 35.0, "Player must gain +35 speed bonus (got %.1f)" % float(player.get("anomaly_speed_bonus")))
	_expect(float(player.get("anomaly_dig_mult")) <= 0.85, "Player must gain dig cadence acceleration (got %.2f)" % float(player.get("anomaly_dig_mult")))

	# Unearth magma seam
	var magma_ok: bool = level.call("unearth_anomaly", "magma_seam")
	_expect(magma_ok, "unearth_anomaly('magma_seam') should succeed")
	_expect(player.get("active_anomaly_buffs").has("magma_seam"), "Player must receive 'magma_seam' buff")
	_expect(int(player.get("anomaly_fire_damage")) == 15, "Player must gain +15 fire damage bonus (got %d)" % int(player.get("anomaly_fire_damage")))

	# Unearth geode shrine
	var geode_ok: bool = level.call("unearth_anomaly", "geode_shrine")
	_expect(geode_ok, "unearth_anomaly('geode_shrine') should succeed")
	_expect(player.get("active_anomaly_buffs").has("geode_shrine"), "Player must receive 'geode_shrine' buff")
	_expect(int(player.get("anomaly_bonus_gems")) == 1, "Player must gain +1 bonus gem drop (got %d)" % int(player.get("anomaly_bonus_gems")))

	_expect(int(level.call("get_anomalies_unearthed")) == 3, "Total anomalies unearthed should reach 3")

func _test_run_summary_score_with_anomalies() -> void:
	var data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	data.set("blocks_mined", 10)
	data.set("total_gems", 5)
	data.set("caches_unlocked", 1)
	data.set("anomalies_unearthed", 3)
	data.set("horn_greed_multiplier", 1.0)

	# 10*10 (100) + 5*25 (125) + 1*200 (200) + 3*300 (900) + 1*500 (500) + 100*15 (1500) = 3325
	var score: int = data.call("calculate_score")
	_expect(score == 3325, "Score with 3 anomalies unearthed should equal 3325 (got %d)" % score)

	var dict: Dictionary = data.call("to_dict")
	_expect(int(dict.get("anomalies_unearthed")) == 3, "to_dict must preserve anomalies_unearthed")
	var restored: RefCounted = SUMMARY_DATA_SCRIPT.call("from_dict", dict)
	_expect(int(restored.get("anomalies_unearthed")) == 3, "from_dict must restore anomalies_unearthed")
