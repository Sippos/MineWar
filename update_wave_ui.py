import re

# 1. Update hud.gd
with open('hud.gd', 'r') as f:
    content = f.read()

content = content.replace(
    'wave_label.text = "BOSS WAVE %d! - Next in %.1fs" % [wave, time_left]',
    'wave_label.text = "BOSS WAVE %d!" % wave'
)

content = content.replace(
    'wave_label.text = "Wave %d - Next in %.1fs" % [wave, time_left]',
    'wave_label.text = "Wave %d" % wave'
)

with open('hud.gd', 'w') as f:
    f.write(content)

# 2. Update hud.tscn
with open('hud.tscn', 'r') as f:
    tscn = f.read()

# Swap WaveLabel and WaveBar positions.
# Current WaveLabel: offset_top = 20.0, offset_bottom = 60.0
# Current WaveBar: offset_top = 65.0, offset_bottom = 161.0

# First, temporarily rename WaveLabel offsets
tscn = re.sub(
    r'\[node name="WaveLabel" type="Label" parent="."\](.*?)offset_top = 20\.0(.*?)offset_bottom = 60\.0',
    r'[node name="WaveLabel" type="Label" parent="."]\1offset_top = 75.0\2offset_bottom = 115.0',
    tscn, flags=re.DOTALL
)

# Then rename WaveBar offsets
tscn = re.sub(
    r'\[node name="WaveBar" type="TextureProgressBar" parent="."\](.*?)offset_top = 65\.0(.*?)offset_bottom = 161\.0',
    r'[node name="WaveBar" type="TextureProgressBar" parent="."]\1offset_top = 20.0\2offset_bottom = 116.0',
    tscn, flags=re.DOTALL
)

# Also update the font size of WaveLabel to be a bit smaller if it's a subheading, or keep 32. Keep 32 for now.

with open('hud.tscn', 'w') as f:
    f.write(tscn)

print("Wave UI updated.")
