import re

# 1. Update hud.tscn
with open('hud.tscn', 'r') as f:
    content = f.read()

# StatsContainer to Y=70
content = re.sub(
    r'\[node name="StatsContainer" type="HBoxContainer" parent="."\]\noffset_left = 20.0\noffset_top = 190.0\noffset_right = 300.0\noffset_bottom = 230.0',
    '[node name="StatsContainer" type="HBoxContainer" parent="."]\noffset_left = 20.0\noffset_top = 70.0\noffset_right = 300.0\noffset_bottom = 110.0',
    content
)

# BaseLabel to Y=120
content = re.sub(
    r'\[node name="BaseLabel" type="Label" parent="."\]\noffset_left = 30.0\noffset_top = 70.0\noffset_right = 130.0\noffset_bottom = 96.0',
    '[node name="BaseLabel" type="Label" parent="."]\noffset_left = 30.0\noffset_top = 120.0\noffset_right = 130.0\noffset_bottom = 146.0',
    content
)

# BaseHealthBar to Y=140
content = re.sub(
    r'\[node name="BaseHealthBar" type="TextureProgressBar" parent="."\]\noffset_left = 20.0\noffset_top = 90.0\noffset_right = 440.0\noffset_bottom = 186.0',
    '[node name="BaseHealthBar" type="TextureProgressBar" parent="."]\noffset_left = 20.0\noffset_top = 140.0\noffset_right = 440.0\noffset_bottom = 236.0',
    content
)

# PlayerHealthBar to Y=210, also add PlayerLabel above it
content = re.sub(
    r'\[node name="PlayerHealthBar" type="TextureProgressBar" parent="."\]\nvisible = false\noffset_left = 20.0\noffset_top = 140.0\noffset_right = 440.0\noffset_bottom = 236.0',
    '[node name="PlayerLabel" type="Label" parent="."]\nvisible = false\noffset_left = 30.0\noffset_top = 190.0\noffset_right = 130.0\noffset_bottom = 216.0\ntheme_override_colors/font_color = Color(1, 1, 1, 1)\ntheme_override_font_sizes/font_size = 16\ntext = "Player"\n\n[node name="PlayerHealthBar" type="TextureProgressBar" parent="."]\nvisible = false\noffset_left = 20.0\noffset_top = 210.0\noffset_right = 440.0\noffset_bottom = 306.0',
    content
)

# Fix XPLabel to center inside the XPBar
content = re.sub(
    r'\[node name="XPLabel" type="Label" parent="."\]\nanchors_preset = 7\nanchor_left = 0.5\nanchor_top = 1.0\nanchor_right = 0.5\nanchor_bottom = 1.0\noffset_left = -105.0\noffset_top = -80.0\noffset_right = 105.0\noffset_bottom = -60.0',
    '[node name="XPLabel" type="Label" parent="."]\nanchors_preset = 7\nanchor_left = 0.5\nanchor_top = 1.0\nanchor_right = 0.5\nanchor_bottom = 1.0\noffset_left = -105.0\noffset_top = -60.0\noffset_right = 105.0\noffset_bottom = -12.0',
    content
)

# Add WaveBar below WaveLabel
if "[node name=\"WaveBar\"" not in content:
    wave_label_pattern = r'\[node name="WaveLabel" type="Label" parent="."\].*?horizontal_alignment = 1'
    wave_bar_append = """

[node name="WaveBar" type="TextureProgressBar" parent="."]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -105.0
offset_top = 65.0
offset_right = 315.0
offset_bottom = 161.0
grow_horizontal = 2
scale = Vector2(0.5, 0.5)
value = 50.0
texture_over = ExtResource("3_healthbar")
texture_progress = ExtResource("9_health_purple")
texture_progress_offset = Vector2(64, 30)"""
    content = re.sub(wave_label_pattern, lambda m: m.group(0) + wave_bar_append, content, flags=re.DOTALL)

with open('hud.tscn', 'w') as f:
    f.write(content)


# 2. Update hud.gd
with open('hud.gd', 'r') as f:
    hud_gd = f.read()

hud_gd = hud_gd.replace(
    'func update_wave_info(wave: int, time_left: float, is_boss: bool) -> void:',
    'func update_wave_info(wave: int, time_left: float, max_time: float, is_boss: bool) -> void:'
)
hud_gd = hud_gd.replace(
    'wave_label.text = "Wave %d - Next in %.1fs" % [wave, time_left]',
    'wave_label.text = "Wave %d - Next in %.1fs" % [wave, time_left]\n\t\n\tvar wave_bar = get_node_or_null("WaveBar")\n\tif wave_bar:\n\t\twave_bar.max_value = max_time\n\t\twave_bar.value = max_time - time_left # Fill as time passes, or just time_left if it should shrink'
)
# Let's make the bar shrink as time goes down
hud_gd = hud_gd.replace(
    'wave_bar.value = max_time - time_left # Fill as time passes, or just time_left if it should shrink',
    'wave_bar.value = time_left'
)
hud_gd = hud_gd.replace(
    'func unlock_healthbar() -> void:\n\tplayer_health_bar.visible = true',
    'func unlock_healthbar() -> void:\n\tplayer_health_bar.visible = true\n\tvar pl = get_node_or_null("PlayerLabel")\n\tif pl: pl.visible = true'
)

with open('hud.gd', 'w') as f:
    f.write(hud_gd)


# 3. Update world.gd
with open('scripts/systems/world_generation/world.gd', 'r') as f:
    world_gd = f.read()

world_gd = world_gd.replace(
    'hud.update_wave_info(current_wave_number, max(wave_timer, 0.0), is_boss)',
    'var max_wave_time = wave_interval if current_wave_number > 1 else 45.0\n\t\thud.update_wave_info(current_wave_number, max(wave_timer, 0.0), max_wave_time, is_boss)'
)

with open('scripts/systems/world_generation/world.gd', 'w') as f:
    f.write(world_gd)

print("Updates completed successfully.")
