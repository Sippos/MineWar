extends Node

func _replace(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if not source.contains(old_text):
		push_error("Missing patch target in %s: %s" % [path, old_text.left(100)])
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _ready() -> void:
	_patch_world_generation()
	_patch_expedition_controller()
	print("MINEWARS_CORE_LOOP_REWARDS_APPLIED")
	get_tree().quit()

func _patch_world_generation() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	_replace(path,
		"\t\t\tif y >= 0 and randf() < 0.10:\n\t\t\t\tvar sprite = Sprite2D.new()\n\t\t\t\tsprite.texture = GEM_TOP_TEXTURE\n\t\t\t\tsprite.position = block_layer.map_to_local(cell)\n\t\t\t\tsprite.visible = false\n\t\t\t\tedge_layer.add_child(sprite)\n\t\t\t\t\n\t\t\t\tvar front_sprite = Sprite2D.new()\n\t\t\t\tfront_sprite.texture = GEM_FRONT_TEXTURE\n\t\t\t\tfront_sprite.offset.y = -17 # Visually shift it back up to its intended position\n\t\t\t\tfront_sprite.z_index = FRONT_GEM_Z_INDEX\n\t\t\t\tfront_sprite.visible = false\n\t\t\t\tadd_child(front_sprite)\n\t\t\t\t_position_front_gem_sprite(front_sprite, cell)\n\t\t\t\t\n\t\t\t\tgem_blocks[cell] = { \"top\": sprite, \"front\": front_sprite }\n\t\t\t\t\n\t_ensure_tutorial_gem()",
		"\t\t\tif y >= 0 and randf() < _gem_chance_for_cell(cell, block_type):\n\t\t\t\t_create_gem_block(cell)\n\t\t\t\t\n\t_seed_expedition_motherlodes()\n\t_ensure_tutorial_gem()")

	_replace(path,
		"func generate_initial_world() -> void:\n",
		"func _gem_chance_for_cell(cell: Vector2i, block_type: int) -> float:\n\tvar base_chance := 0.05\n\tif block_type == 2:\n\t\tbase_chance = 0.14\n\telif block_type == 3:\n\t\tbase_chance = 0.28\n\tvar depth_bonus := clampf(float(maxi(cell.y, 0)) / 30.0 * 0.08, 0.0, 0.08)\n\treturn minf(base_chance + depth_bonus, 0.38)\n\nfunc _create_gem_block(cell: Vector2i) -> void:\n\tif gem_blocks.has(cell):\n\t\treturn\n\tvar sprite := Sprite2D.new()\n\tsprite.texture = GEM_TOP_TEXTURE\n\tsprite.position = block_layer.map_to_local(cell)\n\tsprite.visible = false\n\tedge_layer.add_child(sprite)\n\n\tvar front_sprite := Sprite2D.new()\n\tfront_sprite.texture = GEM_FRONT_TEXTURE\n\tfront_sprite.offset.y = -17\n\tfront_sprite.z_index = FRONT_GEM_Z_INDEX\n\tfront_sprite.visible = false\n\tadd_child(front_sprite)\n\t_position_front_gem_sprite(front_sprite, cell)\n\tgem_blocks[cell] = {\"top\": sprite, \"front\": front_sprite}\n\nfunc _seed_expedition_motherlodes() -> void:\n\tif is_vs_mode:\n\t\treturn\n\tvar rng := RandomNumberGenerator.new()\n\trng.randomize()\n\tvar definitions := [\n\t\t{\"stage\": 1, \"depth\": 6, \"count\": 3, \"rock\": 2},\n\t\t{\"stage\": 2, \"depth\": 13, \"count\": 4, \"rock\": 2},\n\t\t{\"stage\": 3, \"depth\": 20, \"count\": 6, \"rock\": 3},\n\t\t{\"stage\": 4, \"depth\": 27, \"count\": 8, \"rock\": 3},\n\t]\n\tvar pattern: Array[Vector2i] = [\n\t\tVector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,\n\t\tVector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)\n\t]\n\tvar motherlodes := {}\n\tfor definition_value in definitions:\n\t\tvar definition: Dictionary = definition_value\n\t\tvar side := -1 if rng.randi_range(0, 1) == 0 else 1\n\t\tvar center := Vector2i(side * rng.randi_range(6, 12), int(definition[\"depth\"]))\n\t\tmotherlodes[int(definition[\"stage\"])] = center\n\t\tfor index in range(int(definition[\"count\"])):\n\t\t\tvar cell := center + pattern[index % pattern.size()]\n\t\t\tif block_layer.get_cell_source_id(cell) == -1:\n\t\t\t\tblock_layer.set_cell(cell, int(definition[\"rock\"]), Vector2i.ZERO)\n\t\t\tif astar.is_in_bounds(cell.x, cell.y):\n\t\t\t\tastar.set_point_solid(cell, true)\n\t\t\t_create_gem_block(cell)\n\tset_meta(\"minewars_motherlodes\", motherlodes)\n\nfunc get_minewars_prospect_hint(stage: int) -> String:\n\tvar motherlodes: Dictionary = get_meta(\"minewars_motherlodes\", {})\n\tif not motherlodes.has(stage):\n\t\treturn \"\"\n\tvar cell: Vector2i = motherlodes[stage]\n\tvar direction := \"west\" if cell.x < 0 else \"east\"\n\treturn \"Prospecting marks point %s near depth %d.\" % [direction, cell.y]\n\nfunc generate_initial_world() -> void:\n")

func _patch_expedition_controller() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	_replace(path,
		"const STAGE_ENEMY_COUNTS := {\n\t1: 3,\n\t2: 5,\n\t3: 7,\n}\n",
		"const STAGE_ENEMY_COUNTS := {\n\t1: 3,\n\t2: 5,\n\t3: 7,\n}\nconst STAGE_ENEMY_ROSTERS := {\n\t1: [0, 0, 0],\n\t2: [0, 1, 0, 1, 2],\n\t3: [1, 2, 3, 1, 3, 2, 4],\n}\nconst STAGE_CLEAR_GEM_REWARDS := {\n\t1: 1,\n\t2: 1,\n\t3: 2,\n}\n")

	_replace(path,
		"\tvar spawn_count := 1 if is_boss else int(STAGE_ENEMY_COUNTS.get(stage_number, 3))\n\tfor index in range(spawn_count):",
		"\tvar roster: Array = [4] if is_boss else STAGE_ENEMY_ROSTERS.get(stage_number, [0, 0, 0])\n\tvar spawn_count := roster.size()\n\tfor index in range(spawn_count):")
	_replace(path,
		"\t\tif enemy.has_method(\"initialize\"):\n\t\t\tvar enemy_type := 4 if is_boss else (0 if stage_number == 1 else int(world.get_random_enemy_type(stage_number * 2)))\n\t\t\tenemy.initialize(stage_number * 2, is_boss, enemy_type)",
		"\t\tif enemy.has_method(\"initialize\"):\n\t\t\tvar enemy_type := int(roster[index])\n\t\t\tenemy.initialize(stage_number * 2, is_boss, enemy_type)")

	_replace(path,
		"func _complete_assault() -> void:\n\tif stage_number >= FINAL_STAGE:",
		"func _complete_assault() -> void:\n\t_award_stage_clear_reward(stage_number)\n\tif stage_number >= FINAL_STAGE:")

	_replace(path,
		"func _begin_next_expedition() -> void:\n",
		"func _award_stage_clear_reward(cleared_stage: int) -> void:\n\tif hud == null or not hud.has_method(\"add_gems\"):\n\t\treturn\n\tvar reward := int(STAGE_CLEAR_GEM_REWARDS.get(cleared_stage, 0))\n\tif reward <= 0:\n\t\treturn\n\thud.add_gems(reward)\n\tif hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"BASTION SALVAGE  +%d GEM%s — one guaranteed build choice earned.\" % [reward, \"S\" if reward != 1 else \"\"], 4.0)\n\nfunc _begin_next_expedition() -> void:\n")

	_replace(path,
		"\tif hud and hud.has_method(\"show_notice\"):\n\t\tvar prefix := \"FINAL DESCENT\" if stage_number == FINAL_STAGE else \"EXPEDITION %d\" % stage_number\n\t\thud.show_notice(\"%s — %s. The deeper haul is richer, but the return is shorter.\" % [prefix, _stage_name(stage_number)], 4.5)",
		"\tif hud and hud.has_method(\"show_notice\"):\n\t\tvar prefix := \"FINAL DESCENT\" if stage_number == FINAL_STAGE else \"EXPEDITION %d\" % stage_number\n\t\tvar prospect := world.get_minewars_prospect_hint(stage_number) if world.has_method(\"get_minewars_prospect_hint\") else \"\"\n\t\tvar message := \"%s — %s. The deeper haul is richer, but the return is shorter.\" % [prefix, _stage_name(stage_number)]\n\t\tif not prospect.is_empty():\n\t\t\tmessage += \"  \" + prospect\n\t\thud.show_notice(message, 5.2)")

	_replace(path,
		"\telif stage_number == FINAL_STAGE:\n\t\thint_label.text = \"This is the final descent. Gather what the build still needs before the boss assault.\"\n\telse:\n\t\thint_label.text = \"Search for a useful haul, not every block. Your next return creates another build decision.\"",
		"\telif stage_number == FINAL_STAGE:\n\t\thint_label.text = \"This is the final descent. Gather what the build still needs before the boss assault.\"\n\telse:\n\t\tvar prospect := world.get_minewars_prospect_hint(stage_number) if world.has_method(\"get_minewars_prospect_hint\") else \"\"\n\t\thint_label.text = prospect if not prospect.is_empty() else \"Search for a useful haul, not every block. Your next return creates another build decision.\"")
