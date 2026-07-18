extends Node2D

const ENEMY_SCENE := preload("res://enemy.tscn")
const TARGET_SCRIPT := preload("res://tests/combat_smoke_target.gd")

var astar := AStarGrid2D.new()
var topology_revision := 0
var block_layer: TileMapLayer
var base: CharacterBody2D

func _ready() -> void:
	_setup_world()
	await get_tree().process_frame
	for enemy_type in range(5):
		await _exercise_enemy_type(enemy_type)
	await _exercise_boss_transition()
	print("ENEMY_COMBAT_RUNTIME_SMOKE_OK")
	get_tree().quit()

func _setup_world() -> void:
	block_layer = TileMapLayer.new()
	block_layer.name = "BlockLayer"
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	block_layer.tile_set = tile_set
	add_child(block_layer)

	base = CharacterBody2D.new()
	base.name = "Base"
	base.set_script(TARGET_SCRIPT)
	base.global_position = Vector2(0, -64)
	add_child(base)

	astar.region = Rect2i(-12, -12, 25, 25)
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update()

func _exercise_enemy_type(enemy_type: int) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = base.global_position + Vector2(48 + enemy_type * 5, 0)
	enemy.initialize(2, false, enemy_type)
	await get_tree().create_timer(1.9).timeout
	assert(is_instance_valid(enemy))
	enemy.queue_free()
	await get_tree().process_frame

func _exercise_boss_transition() -> void:
	var boss := ENEMY_SCENE.instantiate()
	add_child(boss)
	boss.global_position = Vector2(220, -64)
	boss.initialize(4, true, 4)
	boss.health = 1
	boss.max_health = 1
	boss.take_damage(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var pilot := get_node_or_null("GoblinPilot")
	assert(pilot != null)
	if pilot:
		pilot.queue_free()

func get_enemy_open_space_factor(_world_position: Vector2) -> float:
	return 0.0
