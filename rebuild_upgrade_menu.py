import os

tscn_content = """[gd_scene format=3 uid="uid://dmqhra3bkn6uh"]

[ext_resource type="Script" path="res://upgrade_menu.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://braqxpv12iidt" path="res://Gold_Pile.png" id="2_goldpile"]
[ext_resource type="Texture2D" uid="uid://dyf3an1f8lntc" path="res://StatRessources.png" id="3_gems"]
[ext_resource type="Texture2D" path="res://Healthbar.png" id="4_healthbar"]
[ext_resource type="Texture2D" path="res://Strenght.png" id="5_str"]
[ext_resource type="Texture2D" path="res://Agility.png" id="6_agi"]
[ext_resource type="Texture2D" path="res://Int.png" id="7_int"]

[node name="UpgradeMenu" type="CanvasLayer"]
script = ExtResource("1_script")

[node name="Panel" type="Panel" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -250.0
offset_right = 300.0
offset_bottom = 250.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBoxContainer" type="VBoxContainer" parent="Panel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 10

[node name="TitleContainer" type="HBoxContainer" parent="Panel/VBoxContainer"]
layout_mode = 2
alignment = 1

[node name="Title" type="Label" parent="Panel/VBoxContainer/TitleContainer"]
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Base Upgrades"

[node name="GoldPileIcon" type="TextureRect" parent="Panel/VBoxContainer/TitleContainer"]
layout_mode = 2
texture = ExtResource("2_goldpile")
stretch_mode = 5

[node name="MainContent" type="VBoxContainer" parent="Panel/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 20

[node name="TopSection" type="HBoxContainer" parent="Panel/VBoxContainer/MainContent"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 20

[node name="HUD_Branch" type="VBoxContainer" parent="Panel/VBoxContainer/MainContent/TopSection"]
layout_mode = 2
size_flags_horizontal = 3

[node name="BranchTitle" type="Label" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "-- HUD Updates --"
horizontal_alignment = 1

[node name="UnlockHealthbar" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "Player HP (5 Gems)"
icon = ExtResource("4_healthbar")
expand_icon = true

[node name="UnlockBaseHealth" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "Base HP (5 Gems)"
icon = ExtResource("4_healthbar")
expand_icon = true

[node name="UnlockStats" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "Show Stats (5 Gems)"
icon = ExtResource("5_str")
expand_icon = true

[node name="UnlockWaveTimer" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "Wave Timer (5 Gems)"

[node name="UnlockXP" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "XP Bar (5 Gems)"

[node name="UnlockMinimap" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "Unlock Minimap (20 Gold)"

[node name="UpgradeMinimap" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch"]
layout_mode = 2
text = "Minimap: See Enemies (50 Gold)"

[node name="Health_Branch" type="VBoxContainer" parent="Panel/VBoxContainer/MainContent/TopSection"]
layout_mode = 2
size_flags_horizontal = 3

[node name="BranchTitle" type="Label" parent="Panel/VBoxContainer/MainContent/TopSection/Health_Branch"]
layout_mode = 2
text = "-- Health Updates --"
horizontal_alignment = 1

[node name="UpgradeMaxHealth" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/Health_Branch"]
layout_mode = 2
text = "+20 HP (15 Gold)"
icon = ExtResource("4_healthbar")
expand_icon = true

[node name="HealPlayer" type="Button" parent="Panel/VBoxContainer/MainContent/TopSection/Health_Branch"]
layout_mode = 2
text = "Heal +20 HP (10 Gold)"
icon = ExtResource("4_healthbar")
expand_icon = true

[node name="StatsTitle" type="Label" parent="Panel/VBoxContainer/MainContent"]
layout_mode = 2
text = "-- Stat Updates --"
horizontal_alignment = 1

[node name="Stats_Branch" type="HBoxContainer" parent="Panel/VBoxContainer/MainContent"]
layout_mode = 2
size_flags_vertical = 3

[node name="UpgradeStrength" type="Button" parent="Panel/VBoxContainer/MainContent/Stats_Branch"]
layout_mode = 2
size_flags_horizontal = 3
text = "10 Gems"
icon = ExtResource("5_str")
expand_icon = true

[node name="UpgradeAgility" type="Button" parent="Panel/VBoxContainer/MainContent/Stats_Branch"]
layout_mode = 2
size_flags_horizontal = 3
text = "10 Gems"
icon = ExtResource("6_agi")
expand_icon = true

[node name="UpgradeIntelligence" type="Button" parent="Panel/VBoxContainer/MainContent/Stats_Branch"]
layout_mode = 2
size_flags_horizontal = 3
text = "10 Gems"
icon = ExtResource("7_int")
expand_icon = true

[node name="MiscTitle" type="Label" parent="Panel/VBoxContainer/MainContent"]
layout_mode = 2
text = "-- Misc Updates --"
horizontal_alignment = 1

[node name="Misc_Branch" type="HBoxContainer" parent="Panel/VBoxContainer/MainContent"]
layout_mode = 2

[node name="UpgradeSpikes" type="Button" parent="Panel/VBoxContainer/MainContent/Misc_Branch"]
layout_mode = 2
size_flags_horizontal = 3
text = "Upgrade Spikes (Lvl 0) - 20 Gold"

[node name="SwapHero" type="Button" parent="Panel/VBoxContainer/MainContent/Misc_Branch"]
layout_mode = 2
size_flags_horizontal = 3
text = "Swap Hero (Free)"

[node name="Close" type="Button" parent="Panel/VBoxContainer"]
layout_mode = 2
text = "Close"

[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockHealthbar" to="." method="_on_unlock_healthbar_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockBaseHealth" to="." method="_on_unlock_base_health_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockStats" to="." method="_on_unlock_stats_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockWaveTimer" to="." method="_on_unlock_wave_timer_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockXP" to="." method="_on_unlock_xp_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockMinimap" to="." method="_on_unlock_minimap_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UpgradeMinimap" to="." method="_on_upgrade_minimap_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/Health_Branch/UpgradeMaxHealth" to="." method="_on_upgrade_max_health_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/TopSection/Health_Branch/HealPlayer" to="." method="_on_heal_player_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/Stats_Branch/UpgradeStrength" to="." method="_on_upgrade_strength_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/Stats_Branch/UpgradeAgility" to="." method="_on_upgrade_agility_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/Stats_Branch/UpgradeIntelligence" to="." method="_on_upgrade_intelligence_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/Misc_Branch/UpgradeSpikes" to="." method="_on_upgrade_spikes_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/MainContent/Misc_Branch/SwapHero" to="." method="_on_swap_hero_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/Close" to="." method="_on_close_pressed"]
"""

with open("upgrade_menu.tscn", "w") as f:
    f.write(tscn_content)

print("Created upgrade_menu.tscn")
