import re

with open('hud.tscn', 'r') as f:
    content = f.read()

# GemIcon
content = re.sub(
    r'\[node name="GemIcon" type="TextureRect" parent="."\]\noffset_left = 20.0\noffset_top = 10.0\noffset_right = 84.0\noffset_bottom = 74.0\nscale = Vector2\(0.6, 0.6\)\ntexture = ExtResource\("4_gems"\)\nstretch_mode = 5',
    '[node name="GemIcon" type="TextureRect" parent="."]\noffset_left = 20.0\noffset_top = 15.0\noffset_right = 60.0\noffset_bottom = 55.0\ntexture = ExtResource("4_gems")\nexpand_mode = 1\nstretch_mode = 5',
    content
)

# GoldIcon
content = re.sub(
    r'\[node name="GoldIcon" type="TextureRect" parent="."\]\noffset_left = 120.0\noffset_top = 10.0\noffset_right = 184.0\noffset_bottom = 74.0\nscale = Vector2\(0.6, 0.6\)\ntexture = ExtResource\("2_goldcoin"\)\nstretch_mode = 5',
    '[node name="GoldIcon" type="TextureRect" parent="."]\noffset_left = 120.0\noffset_top = 15.0\noffset_right = 160.0\noffset_bottom = 55.0\ntexture = ExtResource("2_goldcoin")\nexpand_mode = 1\nstretch_mode = 5',
    content
)

# BaseHealthBar
content = re.sub(
    r'\[node name="BaseHealthBar" type="TextureProgressBar" parent="."\]\noffset_left = 20.0\noffset_top = 55.0\noffset_right = 440.0\noffset_bottom = 151.0',
    '[node name="BaseHealthBar" type="TextureProgressBar" parent="."]\noffset_left = 20.0\noffset_top = 90.0\noffset_right = 440.0\noffset_bottom = 186.0',
    content
)

# StatsContainer
content = re.sub(
    r'\[node name="StatsContainer" type="HBoxContainer" parent="."\]\noffset_left = 20.0\noffset_top = 110.0\noffset_right = 300.0\noffset_bottom = 150.0',
    '[node name="StatsContainer" type="HBoxContainer" parent="."]\noffset_left = 20.0\noffset_top = 190.0\noffset_right = 300.0\noffset_bottom = 230.0',
    content
)

# PlayerHealthBar
content = re.sub(
    r'\[node name="PlayerHealthBar" type="TextureProgressBar" parent="."\]\nvisible = false\noffset_left = 20.0\noffset_top = 210.0\noffset_right = 440.0\noffset_bottom = 306.0',
    '[node name="PlayerHealthBar" type="TextureProgressBar" parent="."]\nvisible = false\noffset_left = 20.0\noffset_top = 140.0\noffset_right = 440.0\noffset_bottom = 236.0',
    content
)

# XPLabel
content = re.sub(
    r'\[node name="XPLabel" type="Label" parent="."\]\nanchors_preset = 7\nanchor_left = 0.5\nanchor_top = 1.0\nanchor_right = 0.5\nanchor_bottom = 1.0\noffset_left = -105.0\noffset_top = -52.0\noffset_right = 105.0\noffset_bottom = -26.0\ngrow_horizontal = 2\ngrow_vertical = 0\ntheme_override_colors/font_color = Color\(1, 1, 1, 1\)\ntheme_override_font_sizes/font_size = 14\ntext = "Lvl 1: 0 / 100 XP"\nhorizontal_alignment = 1',
    '[node name="XPLabel" type="Label" parent="."]\nanchors_preset = 7\nanchor_left = 0.5\nanchor_top = 1.0\nanchor_right = 0.5\nanchor_bottom = 1.0\noffset_left = -105.0\noffset_top = -80.0\noffset_right = 105.0\noffset_bottom = -60.0\ngrow_horizontal = 2\ngrow_vertical = 0\ntheme_override_colors/font_color = Color(1, 1, 1, 1)\ntheme_override_font_sizes/font_size = 14\ntext = "Lvl 1: 0 / 100 XP"\nhorizontal_alignment = 1\nvertical_alignment = 1',
    content
)

# BaseLabel
content = re.sub(
    r'\[node name="BaseLabel" type="Label" parent="."\]\noffset_left = 30.0\noffset_top = 40.0\noffset_right = 130.0\noffset_bottom = 66.0',
    '[node name="BaseLabel" type="Label" parent="."]\noffset_left = 30.0\noffset_top = 70.0\noffset_right = 130.0\noffset_bottom = 96.0',
    content
)

with open('hud.tscn', 'w') as f:
    f.write(content)

print("HUD updated successfully.")
