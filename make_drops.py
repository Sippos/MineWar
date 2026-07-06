import os

coin_gd = """extends Area2D

var gold_value = 10

func _ready() -> void:
\tvar tween = create_tween()
\tscale = Vector2.ZERO
\ttween.tween_property(self, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
\t
\tbody_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
\tif body.name == "Player":
\t\tvar hud = get_parent().get_node_or_null("HUD")
\t\tif hud and hud.has_method("add_gold"):
\t\t\thud.add_gold(gold_value)
\t\tqueue_free()
"""

xp_gd = """extends Area2D

var xp_value = 10

func _ready() -> void:
\tvar tween = create_tween()
\tscale = Vector2.ZERO
\ttween.tween_property(self, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
\t
\tbody_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
\tif body.name == "Player":
\t\tif body.has_method("add_xp"):
\t\t\tbody.add_xp(xp_value)
\t\tqueue_free()
"""

coin_tscn = """[gd_scene load_steps=4 format=3 uid="uid://coindrop"]

[ext_resource type="Script" path="res://coin_drop.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://goldcoin" path="res://GoldCoin.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 16.0

[node name="CoinDrop" type="Area2D"]
collision_layer = 0
collision_mask = 1
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
"""

xp_tscn = """[gd_scene load_steps=4 format=3 uid="uid://xpdrop"]

[ext_resource type="Script" path="res://xp_drop.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://intdrop" path="res://Int.png" id="2_tex"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 16.0

[node name="XPDrop" type="Area2D"]
collision_layer = 0
collision_mask = 1
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
modulate = Color(0, 1, 0.5, 1)
scale = Vector2(0.5, 0.5)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
"""

level_up_menu_gd = """extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

func _ready() -> void:
\tprocess_mode = Node.PROCESS_MODE_ALWAYS # keep running while tree paused

func setup(has_stomp: bool) -> void:
\tvar btn_stomp = $Panel/VBoxContainer/ButtonStomp
\tif has_stomp:
\t\tbtn_stomp.text = "Upgrade Stomp (Level Up)"
\telse:
\t\tbtn_stomp.text = "Learn Stomp"

func _on_button_stomp_pressed() -> void:
\tupgrade_selected.emit("stomp")
\thide_and_unpause()

func _on_button_health_pressed() -> void:
\tupgrade_selected.emit("health")
\thide_and_unpause()

func _on_button_damage_pressed() -> void:
\tupgrade_selected.emit("damage")
\thide_and_unpause()

func hide_and_unpause() -> void:
\tget_tree().paused = false
\tqueue_free()
"""

level_up_menu_tscn = """[gd_scene load_steps=2 format=3 uid="uid://lvlupmenu"]

[ext_resource type="Script" path="res://level_up_menu.gd" id="1_script"]

[node name="LevelUpMenu" type="CanvasLayer"]
script = ExtResource("1_script")

[node name="Panel" type="Panel" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -100.0
offset_right = 150.0
offset_bottom = 100.0
grow_horizontal = 2
grow_vertical = 2

[node name="Label" type="Label" parent="Panel"]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_top = 10.0
offset_bottom = 36.0
grow_horizontal = 2
theme_override_font_sizes/font_size = 24
text = "Level Up!"
horizontal_alignment = 1

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 50.0
offset_right = -20.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 10

[node name="ButtonStomp" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
text = "Learn Stomp"

[node name="ButtonHealth" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
text = "+ Max Health"

[node name="ButtonDamage" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
text = "+ Attack Damage"

[connection signal="pressed" from="Panel/VBoxContainer/ButtonStomp" to="." method="_on_button_stomp_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/ButtonHealth" to="." method="_on_button_health_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/ButtonDamage" to="." method="_on_button_damage_pressed"]
"""

with open("coin_drop.gd", "w") as f: f.write(coin_gd)
with open("coin_drop.tscn", "w") as f: f.write(coin_tscn)
with open("xp_drop.gd", "w") as f: f.write(xp_gd)
with open("xp_drop.tscn", "w") as f: f.write(xp_tscn)
with open("level_up_menu.gd", "w") as f: f.write(level_up_menu_gd)
with open("level_up_menu.tscn", "w") as f: f.write(level_up_menu_tscn)
print("Files created.")
