extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/world/mine/level.tscn")
const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const HEROES: Array[String] = ["Dwarf", "Shaman", "Nerubian", "Druid", "Undead King"]

var hero_index := 0
var current_level: Node
var loading := false
var info_label: Label

func _ready() -> void:
	_create_overlay()
	call_deferred("_reload_hero")

func _process(_delta: float) -> void:
	if loading:
		return
	if Input.is_action_just_pressed("ui_right"):
		hero_index = (hero_index + 1) % HEROES.size()
		loading = true
		call_deferred("_reload_hero")
	elif Input.is_action_just_pressed("ui_left"):
		hero_index = posmod(hero_index - 1, HEROES.size())
		loading = true
		call_deferred("_reload_hero")
	elif Input.is_action_just_pressed("ui_accept"):
		_spawn_enemy_pack()

func _create_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 110)
	panel.custom_minimum_size = Vector2(430, 92)
	layer.add_child(panel)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	panel.add_child(info_label)

func _reload_hero() -> void:
	loading = true
	get_tree().paused = false
	if is_instance_valid(current_level):
		current_level.free()
	Global.hero_p1 = HEROES[hero_index]
	Global.current_hero = HEROES[hero_index]
	Global.selected_hero_id = HEROES[hero_index]
	current_level = LEVEL_SCENE.instantiate()
	add_child(current_level)
	await _wait_physics_frames(8)
	var player := current_level.get_node_or_null("Player") as CharacterBody2D
	if player != null:
		_unlock_full_kit(player)
		_spawn_enemy_pack()
	_update_overlay()
	loading = false

func _unlock_full_kit(player: CharacterBody2D) -> void:
	player.set("level", 6)
	player.set("strength", 3)
	player.set("agility", 3)
	player.set("intelligence", 3)
	var abilities: Node = player.get_node_or_null("HeroAbilities")
	if abilities == null:
		return
	match HEROES[hero_index]:
		"Dwarf":
			player.set("stomp_level", 3)
			abilities.set("hammer_level", 3)
			abilities.set("bash_level", 3)
			abilities.set("avatar_level", 1)
		"Shaman":
			abilities.set("totem_level", 3)
			abilities.set("chain_level", 3)
			abilities.set("wisdom_level", 3)
			abilities.set("ascendance_level", 1)
		"Nerubian":
			abilities.set("brood_level", 3)
			abilities.set("web_level", 3)
			abilities.set("carapace_level", 3)
			abilities.set("broodmother_level", 1)
		"Druid":
			abilities.set("mole_level", 3)
			abilities.set("tunnel_level", 3)
			abilities.set("deep_roots_level", 3)
			abilities.set("worldroot_level", 1)
		"Undead King":
			abilities.set("undead_summon_level", 3)
			abilities.set("grave_might_level", 3)
			abilities.set("soul_harvest_level", 3)
			abilities.set("death_march_level", 1)
	abilities.call("_update_ability_hud")

func _spawn_enemy_pack() -> void:
	if not is_instance_valid(current_level):
		return
	var player := current_level.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		return
	var offsets: Array[Vector2] = [Vector2(130, 0), Vector2(210, 55), Vector2(250, -55)]
	for index: int in range(offsets.size()):
		var enemy: Node = ENEMY_SCENE.instantiate()
		current_level.add_child(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = player.global_position + offsets[index]
		if enemy.has_method("initialize"):
			enemy.call("initialize", 3, false, index % 3)

func _update_overlay() -> void:
	if info_label == null:
		return
	info_label.text = "%s — interactive balance review\nMove: WASD  |  Starter: R  |  Secondary: F  |  Ultimate: T  |  Spawn pack: Enter  |  Previous/Next hero: UI Left/Right" % HEROES[hero_index]

func _wait_physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame
