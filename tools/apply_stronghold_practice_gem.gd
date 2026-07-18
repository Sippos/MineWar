extends Node

var failures := 0

func _ready() -> void:
	_patch_gem_behavior()
	_patch_player_carry_weight()
	_patch_hub_controller()
	if failures == 0:
		print("STRONGHOLD_PRACTICE_GEM_APPLIED")
		get_tree().quit()
	else:
		push_error("STRONGHOLD_PRACTICE_GEM_FAILED: %d anchors missing" % failures)
		get_tree().quit(1)

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures += 1
		push_error("Cannot read " + path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("Cannot write " + path)
		return
	file.store_string(text)
	file.close()

func _replace_once(source: String, old_text: String, new_text: String, label: String) -> String:
	if source.contains(new_text):
		return source
	var count := source.count(old_text)
	if count != 1:
		failures += 1
		push_error("Patch anchor %s expected once, found %d" % [label, count])
		return source
	return source.replace(old_text, new_text)

func _patch_gem_behavior() -> void:
	var path := "res://scripts/gameplay/collectibles/gems/gem.gd"
	var source := _read(path)
	var anchor := "func set_tutorial_emphasis(enabled: bool) -> void:\n"
	var insertion := "func should_deposit_as_gem() -> bool:\n\treturn not bool(get_meta(\"stronghold_practice_gem\", false))\n\nfunc get_carry_weight() -> int:\n\treturn maxi(1, int(get_meta(\"practice_carry_weight\", 1)))\n\nfunc set_tutorial_emphasis(enabled: bool) -> void:\n"
	source = _replace_once(source, anchor, insertion, "gem practice behavior")
	_write(path, source)

func _patch_player_carry_weight() -> void:
	var path := "res://player.gd"
	var source := _read(path)
	var old_text := "\tfor gem in carried_gems:\n\t\tif is_instance_valid(gem):\n\t\t\tcarry_load += 1\n\treturn carry_load\n"
	var new_text := "\tfor gem in carried_gems:\n\t\tif not is_instance_valid(gem):\n\t\t\tcontinue\n\t\tif gem.has_method(\"get_carry_weight\"):\n\t\t\tcarry_load += maxi(1, int(gem.call(\"get_carry_weight\")))\n\t\telse:\n\t\t\tcarry_load += 1\n\treturn carry_load\n"
	source = _replace_once(source, old_text, new_text, "weighted carried gems")
	_write(path, source)

func _patch_hub_controller() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var source := _read(path)
	source = _replace_once(
		source,
		"const STRONGHOLD_AMBIENCE_SCRIPT := preload(\"res://scripts/systems/stronghold_ambience_controller.gd\")\n",
		"const STRONGHOLD_AMBIENCE_SCRIPT := preload(\"res://scripts/systems/stronghold_ambience_controller.gd\")\nconst STRONGHOLD_PRACTICE_GEM_SCRIPT := preload(\"res://scripts/systems/stronghold_practice_gem_controller.gd\")\n",
		"practice script preload"
	)
	source = _replace_once(
		source,
		"var stronghold_ambience: Node2D\nvar _last_ambience_base_id := \"\"\n",
		"var stronghold_ambience: Node2D\nvar practice_gem_station: Node2D\nvar _last_ambience_base_id := \"\"\n",
		"practice station variable"
	)
	source = _replace_once(
		source,
		"\t_refresh_stronghold_ambience()\n\n\tplayer_camera = player.get_node_or_null(\"Camera2D\") as Camera2D\n",
		"\t_refresh_stronghold_ambience()\n\t_create_practice_gem_station()\n\n\tplayer_camera = player.get_node_or_null(\"Camera2D\") as Camera2D\n",
		"practice station creation call"
	)
	var method_anchor := "func _create_hub_camera() -> void:\n"
	var method_insert := "func _create_practice_gem_station() -> void:\n\tif world == null or player == null:\n\t\treturn\n\tvar existing := world.get_node_or_null(\"StrongholdPracticeYard\") as Node2D\n\tif existing != null:\n\t\tpractice_gem_station = existing\n\t\treturn\n\tvar station := Node2D.new()\n\tstation.name = \"StrongholdPracticeYard\"\n\tstation.set_script(STRONGHOLD_PRACTICE_GEM_SCRIPT)\n\tworld.add_child(station)\n\tpractice_gem_station = station\n\nfunc _create_hub_camera() -> void:\n"
	source = _replace_once(source, method_anchor, method_insert, "practice station method")
	_write(path, source)
