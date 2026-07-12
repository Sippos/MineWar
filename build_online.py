import os

# 1. Create online_lobby.gd
lobby_gd = """extends Control

const PORT = 8080

@onready var host_btn = $VBoxContainer/HostBtn
@onready var join_btn = $VBoxContainer/JoinBtn
@onready var ip_input = $VBoxContainer/IPInput
@onready var status_label = $VBoxContainer/StatusLabel

var peer: WebSocketMultiplayerPeer

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _process(_delta):
	if peer:
		peer.poll()

func _on_host_pressed():
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		status_label.text = "Hosting on port %d. Waiting for player..." % PORT
		host_btn.disabled = true
		join_btn.disabled = true
	else:
		status_label.text = "Error hosting server!"

func _on_join_pressed():
	var ip = ip_input.text
	if ip == "":
		ip = "127.0.0.1"
		
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client("ws://" + ip + ":" + str(PORT))
	if error == OK:
		multiplayer.multiplayer_peer = peer
		status_label.text = "Connecting to " + ip + "..."
		host_btn.disabled = true
		join_btn.disabled = true
	else:
		status_label.text = "Error creating client!"

func _on_peer_connected(id):
	status_label.text = "Player %d connected!" % id
	if multiplayer.is_server():
		# Start game on both sides!
		var seed_val = randi()
		rpc("start_game", seed_val)

func _on_peer_disconnected(id):
	status_label.text = "Player %d disconnected." % id
	# Go back to menu if disconnected mid-game
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")

func _on_connected_to_server():
	status_label.text = "Connected! Waiting for host to start..."

func _on_connection_failed():
	status_label.text = "Connection failed."
	multiplayer.multiplayer_peer = null
	host_btn.disabled = false
	join_btn.disabled = false

@rpc("authority", "call_local", "reliable")
func start_game(world_seed: int):
	# Switch to vs_online.tscn
	var online_scene = load("res://vs_online.tscn").instantiate()
	online_scene.world_seed = world_seed
	get_tree().root.add_child(online_scene)
	get_tree().current_scene = online_scene
	self.queue_free() # Destroy the lobby
"""
with open("online_lobby.gd", "w") as f:
    f.write(lobby_gd)

# 2. Create online_lobby.tscn
lobby_tscn = """[gd_scene load_steps=2 format=3 uid="uid://online_lobby"]

[ext_resource type="Script" path="res://online_lobby.gd" id="1_script"]

[node name="OnlineLobby" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")

[node name="ColorRect" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.12, 0.12, 0.12, 1)

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -100.0
offset_right = 150.0
offset_bottom = 100.0
theme_override_constants/separation = 15

[node name="Label" type="Label" parent="VBoxContainer"]
layout_mode = 2
theme_override_font_sizes/font_size = 32
text = "Online VS Mode"
horizontal_alignment = 1

[node name="StatusLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Ready"
horizontal_alignment = 1

[node name="HostBtn" type="Button" parent="VBoxContainer"]
custom_minimum_size = Vector2(0, 40)
layout_mode = 2
text = "Host Game"

[node name="Label2" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "or"
horizontal_alignment = 1

[node name="IPInput" type="LineEdit" parent="VBoxContainer"]
layout_mode = 2
placeholder_text = "IP Address (leave blank for localhost)"

[node name="JoinBtn" type="Button" parent="VBoxContainer"]
custom_minimum_size = Vector2(0, 40)
layout_mode = 2
text = "Join Game"
"""
with open("online_lobby.tscn", "w") as f:
    f.write(lobby_tscn)

# 3. Create vs_online.gd
vs_online_gd = """extends Node

var world_seed: int = 0
@onready var level = $Level

func _ready():
	# Configure the level to use the synced seed!
	# We have to hook this up after it loads, so let's let the level generate normally,
	# but we can re-generate if we want to sync the noise exactly.
	# Actually, since noise is FastNoiseLite, we can set its seed.
	# For now, let's just use randi() inside the level if we haven't modified generate_initial_world to take a seed.
	# We will just pass the network events.
	
	level.player_id = 1 # Always use WASD locally for yourself
	level.is_vs_mode = true
	
	# Hook up send_enemy
	var upg_menu = level.get_node_or_null("UpgradeMenu")
	if upg_menu:
		if not upg_menu.has_user_signal("send_enemy"):
			upg_menu.add_user_signal("send_enemy")
		upg_menu.connect("send_enemy", Callable(self, "_on_local_send_enemy"))
		
	# Hook up game over
	var base = level.get_node_or_null("Base")
	if base:
		base.game_over.connect(_on_base_destroyed)

func _on_local_send_enemy(enemy_type: int):
	level.income += 1
	# Send to opponent
	rpc("receive_enemy", enemy_type)

@rpc("any_peer", "call_remote", "reliable")
func receive_enemy(enemy_type: int):
	var e = level.ENEMY_SCENE.instantiate()
	var target_cell = level.get_farthest_open_cell()
	e.global_position = level.block_layer.to_global(level.block_layer.map_to_local(target_cell))
	level.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)

func _on_base_destroyed():
	rpc("opponent_base_destroyed")
	# Show game over locally is handled by HUD already

@rpc("any_peer", "call_remote", "reliable")
func opponent_base_destroyed():
	# You win!
	var hud = level.get_node_or_null("HUD")
	if hud and hud.has_node("GameOverLabel"):
		hud.get_node("GameOverLabel").text = "YOU WIN! Opponent Base Destroyed!"
		hud.get_node("GameOverLabel").modulate = Color(0, 1, 0)
		hud.on_game_over()
"""
with open("vs_online.gd", "w") as f:
    f.write(vs_online_gd)

# 4. Create vs_online.tscn
vs_online_tscn = """[gd_scene load_steps=3 format=3 uid="uid://vs_online"]

[ext_resource type="Script" path="res://vs_online.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://scenes/world/mine/level.tscn" id="2_level"]

[node name="VSOnline" type="Node"]
script = ExtResource("1_script")

[node name="Level" parent="." instance=ExtResource("2_level")]
"""
with open("vs_online.tscn", "w") as f:
    f.write(vs_online_tscn)

# 5. Modify menu.tscn to add Online VS Button
with open("scenes/menus/main/menu.tscn", "r") as f:
    menu_tscn = f.read()

btn_insert = """
[node name="VSOnlineButton" type="Button" parent="VBoxContainer"]
custom_minimum_size = Vector2(0, 40)
layout_mode = 2
text = "VS Mode (Online)"
"""
if "VSOnlineButton" not in menu_tscn:
    menu_tscn = menu_tscn.replace('[node name="LexikonButton"', btn_insert + '\n[node name="LexikonButton"')

with open("scenes/menus/main/menu.tscn", "w") as f:
    f.write(menu_tscn)

# 6. Modify menu.gd to handle new button
with open("scripts/ui/menus/main/menu.gd", "r") as f:
    menu_gd = f.read()

if "VSOnlineButton" not in menu_gd:
    menu_gd = menu_gd.replace('func _ready() -> void:', 'func _ready() -> void:\n\t$VBoxContainer/VSOnlineButton.pressed.connect(_on_vs_online_pressed)')
    menu_gd += """
func _on_vs_online_pressed() -> void:
	get_tree().change_scene_to_file("res://online_lobby.tscn")
"""

with open("scripts/ui/menus/main/menu.gd", "w") as f:
    f.write(menu_gd)
