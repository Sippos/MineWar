extends Node2D

@export var mode_scenes: Array[PackedScene] = [
	preload("res://base.tscn"),
	preload("res://vs_mode.tscn"),
	preload("res://maze_vs_lane.tscn")
]
@export var time_per_mode: float = 5.0
@export var camera_speed: float = 200.0

var current_mode_node: Node = null
var current_mode_index: int = 0
var mode_timer: float = 0.0

@onready var camera = $TrailerCamera
@onready var canvas_layer = $CanvasLayer
@onready var text_label = $CanvasLayer/CenterContainer/Label
@onready var color_rect = $CanvasLayer/ColorRect

enum State { FADING_IN, PLAYING, FADING_OUT }
var state: State = State.FADING_OUT

func _ready() -> void:
	color_rect.color = Color(0, 0, 0, 1)
	text_label.modulate.a = 0
	_load_next_mode()

func _process(delta: float) -> void:
	if current_mode_node == null and state == State.PLAYING:
		return
		
	match state:
		State.FADING_IN:
			color_rect.color.a -= delta * 1.5
			if color_rect.color.a <= 0:
				color_rect.color.a = 0
				state = State.PLAYING
				mode_timer = 0.0
				
				# Show text
				var tween = create_tween()
				text_label.modulate.a = 1.0
				tween.tween_property(text_label, "modulate:a", 0.0, 2.0).set_delay(1.5)
				
		State.PLAYING:
			mode_timer += delta
			if is_instance_valid(camera):
				camera.position.x += camera_speed * delta
				camera.position.y += (camera_speed * 0.2) * delta
				
			if mode_timer >= time_per_mode:
				state = State.FADING_OUT
				
		State.FADING_OUT:
			color_rect.color.a += delta * 1.5
			if color_rect.color.a >= 1.0:
				color_rect.color.a = 1.0
				_load_next_mode()

func _load_next_mode() -> void:
	if current_mode_node != null:
		current_mode_node.queue_free()
		current_mode_node = null
		
	if current_mode_index >= mode_scenes.size():
		print("Trailer sequence finished. Quitting.")
		get_tree().quit()
		return
		
	if current_mode_index < mode_scenes.size():
		var scene = mode_scenes[current_mode_index]
		if scene:
			current_mode_node = scene.instantiate()
			add_child(current_mode_node)
			
			# Disable any other cameras in the loaded scene
			_disable_other_cameras(current_mode_node)
			
			# Attempt to hide HUD
			call_deferred("_hide_hud_recursive", current_mode_node)
			
			# Reset camera
			if is_instance_valid(camera):
				camera.position = Vector2(0, 0)
				# Try to find a player to start camera near
				var player = _find_node_by_class(current_mode_node, "Player")
				if not player:
					player = current_mode_node.find_child("Player*", true, false)
				if player and player is Node2D:
					camera.position = player.position
					camera.position.y -= 200 # offset
				
			# Set Mode Text
			var mode_name = scene.resource_path.get_file().get_basename().capitalize()
			text_label.text = mode_name + " Gameplay"
			text_label.modulate.a = 0
			
			if is_instance_valid(camera):
				camera.make_current()
			
			current_mode_index += 1
			state = State.FADING_IN

func _disable_other_cameras(node: Node) -> void:
	if node is Camera2D and node != camera:
		node.enabled = false
	for child in node.get_children():
		_disable_other_cameras(child)

func _hide_hud_recursive(node: Node) -> void:
	if node is CanvasLayer and node != canvas_layer:
		node.visible = false
	elif node is Control and node.name.matchn("*hud*"):
		node.visible = false
	elif node.name.matchn("*ui*"):
		if node.has_method("hide"):
			node.hide()
		elif "visible" in node:
			node.visible = false
			
	for child in node.get_children():
		_hide_hud_recursive(child)

func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.is_class(class_name_str) or node.name.find(class_name_str) != -1:
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null
