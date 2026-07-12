import os
import re

# 1. Create vs_mode.gd
vs_mode_gd = """extends Control

@onready var level1 = $HBoxContainer/SubViewportContainer1/SubViewport1/Level1
@onready var level2 = $HBoxContainer/SubViewportContainer2/SubViewport2/Level2

func _ready() -> void:
	level1.player_id = 1
	level1.is_vs_mode = true
	level2.player_id = 2
	level2.is_vs_mode = true
	
	# Connect sending enemies
	var hud1 = level1.get_node_or_null("UpgradeMenu")
	if hud1:
		hud1.add_user_signal("send_enemy")
		hud1.connect("send_enemy", Callable(self, "_on_p1_send_enemy"))
		
	var hud2 = level2.get_node_or_null("UpgradeMenu")
	if hud2:
		hud2.add_user_signal("send_enemy")
		hud2.connect("send_enemy", Callable(self, "_on_p2_send_enemy"))

func _on_p1_send_enemy(enemy_type: int) -> void:
	level1.income += 1
	var e = level2.ENEMY_SCENE.instantiate()
	# spawn on level2
	var target_cell = level2.get_farthest_open_cell()
	e.global_position = level2.block_layer.to_global(level2.block_layer.map_to_local(target_cell))
	level2.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)

func _on_p2_send_enemy(enemy_type: int) -> void:
	level2.income += 1
	var e = level1.ENEMY_SCENE.instantiate()
	var target_cell = level1.get_farthest_open_cell()
	e.global_position = level1.block_layer.to_global(level1.block_layer.map_to_local(target_cell))
	level1.add_child(e)
	if e.has_method("initialize"):
		e.initialize(1, false, enemy_type)
"""
with open("vs_mode.gd", "w") as f:
    f.write(vs_mode_gd)

# 2. Create vs_mode.tscn
vs_mode_tscn = """[gd_scene load_steps=3 format=3 uid="uid://c8d8b2e1a2f3"]

[ext_resource type="Script" path="res://vs_mode.gd" id="1_vs"]
[ext_resource type="PackedScene" uid="uid://dl0bto1orfw6t" path="res://level.tscn" id="2_level"]

[node name="VSMode" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_vs")

[node name="HBoxContainer" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 4

[node name="SubViewportContainer1" type="SubViewportContainer" parent="HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
stretch = true

[node name="SubViewport1" type="SubViewport" parent="HBoxContainer/SubViewportContainer1"]
handle_input_locally = false
size = Vector2i(2, 2)
render_target_update_mode = 4

[node name="Level1" parent="HBoxContainer/SubViewportContainer1/SubViewport1" instance=ExtResource("2_level")]

[node name="ColorRect" type="ColorRect" parent="HBoxContainer"]
custom_minimum_size = Vector2(4, 0)
layout_mode = 2
color = Color(0.2, 0.2, 0.2, 1)

[node name="SubViewportContainer2" type="SubViewportContainer" parent="HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
stretch = true

[node name="SubViewport2" type="SubViewport" parent="HBoxContainer/SubViewportContainer2"]
handle_input_locally = false
size = Vector2i(2, 2)
render_target_update_mode = 4

[node name="Level2" parent="HBoxContainer/SubViewportContainer2/SubViewport2" instance=ExtResource("2_level")]
"""
with open("vs_mode.tscn", "w") as f:
    f.write(vs_mode_tscn)

# 3. Patch menu.tscn
with open("scenes/menus/main/menu.tscn", "r") as f:
    menu_tscn = f.read()

menu_tscn = menu_tscn.replace('disabled = true\ntext = "VS Mode (Coming Soon)"', 'text = "VS Mode (Local Split-Screen)"')

with open("scenes/menus/main/menu.tscn", "w") as f:
    f.write(menu_tscn)

# 4. Patch menu.gd
with open("scripts/ui/menus/main/menu.gd", "r") as f:
    menu_gd = f.read()

menu_gd = menu_gd.replace('func _ready() -> void:', 'func _ready() -> void:\n\t$VBoxContainer/VSModeButton.pressed.connect(_on_vs_mode_pressed)')
menu_gd += """
func _on_vs_mode_pressed() -> void:
	get_tree().change_scene_to_file("res://vs_mode.tscn")
"""

with open("scripts/ui/menus/main/menu.gd", "w") as f:
    f.write(menu_gd)

# 5. Patch upgrade_menu.gd
with open("upgrade_menu.gd", "r") as f:
    upg_gd = f.read()

upg_inject = """	if get_parent().is_vs_mode:
		if not has_node("Panel/VBoxContainer/MainContent/VS_Branch"):
			var vs_branch = VBoxContainer.new()
			vs_branch.name = "VS_Branch"
			var lbl = Label.new()
			lbl.text = "--- VS Mode (Send Enemies) ---"
			vs_branch.add_child(lbl)
			
			var btn_rat = Button.new()
			btn_rat.text = "Send Rat (5 Gems) -> +1 Income"
			btn_rat.pressed.connect(Callable(self, "_on_send_rat"))
			vs_branch.add_child(btn_rat)
			
			var btn_spider = Button.new()
			btn_spider.text = "Send Spider (10 Gems) -> +2 Income"
			btn_spider.pressed.connect(Callable(self, "_on_send_spider"))
			vs_branch.add_child(btn_spider)
			
			$Panel/VBoxContainer/MainContent.add_child(vs_branch)
			
			if not has_user_signal("send_enemy"):
				add_user_signal("send_enemy")
"""

# inject into show_menu
upg_gd = re.sub(r'func show_menu\(\):.*?panel.visible = true', 'func show_menu():\n\tupdate_button_texts()\n\tpanel.visible = true\n' + upg_inject, upg_gd, flags=re.DOTALL)

upg_funcs = """
func _on_send_rat():
	if hud.total_gems >= 5:
		hud.add_gems(-5)
		emit_signal("send_enemy", 0) # 0 = Rat

func _on_send_spider():
	if hud.total_gems >= 10:
		hud.add_gems(-10)
		emit_signal("send_enemy", 1) # 1 = Spider
		get_parent().income += 1 # extra income
"""

upg_gd += upg_funcs

with open("upgrade_menu.gd", "w") as f:
    f.write(upg_gd)

print("Done building VS Mode scripts.")
