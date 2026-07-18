extends Node2D

const HIT_EFFECT_SCENE := preload("res://combat_hit_effect.tscn")
const DWARF_ATTACK := preload("res://assets/sprites/characters/dwarf/dwarf_attack_pixelart_spritesheet.png")
const RAT_WALK := preload("res://assets/sprites/enemies/rat/rat_walk_pixelart_spritesheet.png")
const MECH_WALK := preload("res://character_sprites/mech_walk_pixelart_spritesheet.png")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111821"))
	_create_sprite(DWARF_ATTACK, Vector2(215, 330), Vector2(1.12, 1.12), 8, 8, 4)
	_create_sprite(RAT_WALK, Vector2(370, 338), Vector2.ONE, 8, 8, 0)
	_create_frozen_effect(Vector2(320, 336), Vector2.RIGHT, 1.2, false, Color(1.0, 0.55, 0.16, 1.0), 0.045)

	_create_sprite(DWARF_ATTACK, Vector2(650, 330), Vector2(1.12, 1.12), 8, 8, 4)
	_create_sprite(MECH_WALK, Vector2(875, 338), Vector2(2.0, 2.0), 8, 8, 0)
	_create_frozen_effect(Vector2(765, 336), Vector2.RIGHT, 1.9, true, Color(1.0, 0.55, 0.16, 1.0), 0.065)
	queue_redraw()

func _create_sprite(texture: Texture2D, position_value: Vector2, scale_value: Vector2, hframes_value: int, vframes_value: int, frame_value: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = position_value
	sprite.scale = scale_value
	sprite.hframes = hframes_value
	sprite.vframes = vframes_value
	sprite.frame = frame_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _create_frozen_effect(position_value: Vector2, direction: Vector2, power: float, lethal: bool, tint: Color, elapsed: float) -> void:
	var effect := HIT_EFFECT_SCENE.instantiate() as Node2D
	add_child(effect)
	effect.position = position_value
	effect.call("configure", direction, power, lethal, tint)
	effect.set("_elapsed", elapsed)
	effect.set_process(false)
	effect.queue_redraw()

func _draw() -> void:
	for x in range(0, 1153, 64):
		draw_line(Vector2(x, 0), Vector2(x, 648), Color(0.17, 0.22, 0.27, 0.38), 1.0)
	for y in range(0, 649, 64):
		draw_line(Vector2(0, y), Vector2(1152, y), Color(0.17, 0.22, 0.27, 0.38), 1.0)
	draw_line(Vector2(560, 90), Vector2(560, 560), Color(0.65, 0.7, 0.75, 0.35), 2.0)
	draw_circle(Vector2(320, 336), 3.0, Color.WHITE)
	draw_circle(Vector2(765, 336), 3.0, Color.WHITE)
