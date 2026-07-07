import re

with open("upgrade_menu.tscn", "r") as f:
    lines = f.readlines()

new_lines = []
skip_node = True
current_node_type = ""
node_name = ""

resources = [l for l in lines if l.startswith("[ext_resource")]
out = ["[gd_scene format=3]\n\n"]
out.extend(resources)
out.append("\n[node name=\"UpgradeMenuFree\" type=\"Control\"]\n")
out.append("layout_mode = 3\n")
out.append("anchors_preset = 15\n")
out.append("anchor_right = 1.0\n")
out.append("anchor_bottom = 1.0\n")
out.append("grow_horizontal = 2\n")
out.append("grow_vertical = 2\n\n")

ignore_types = ["Panel", "VBoxContainer", "HBoxContainer", "ScrollContainer", "GridContainer", "CenterContainer", "CanvasLayer"]

x = 50
y = 50
col_height = 0

for line in lines:
    if line.startswith("[node name="):
        m = re.search(r'name="([^"]+)".*?type="([^"]+)"', line)
        if m:
            node_name = m.group(1)
            current_node_type = m.group(2)
            if current_node_type in ignore_types:
                skip_node = True
            else:
                skip_node = False
                out.append(f'[node name="{node_name}" type="{current_node_type}" parent="."]\n')
                out.append("layout_mode = 0\n")
                out.append(f"offset_left = {x}\n")
                out.append(f"offset_top = {y}\n")
                out.append(f"offset_right = {x + 200}\n")
                out.append(f"offset_bottom = {y + 40}\n")
                
                y += 50
                col_height += 1
                if col_height > 10:
                    y = 50
                    x += 250
                    col_height = 0
        else:
            skip_node = True
    elif line.startswith("[connection"):
        continue
    elif line.startswith("layout_mode"):
        continue
    elif line.startswith("offset_") or line.startswith("anchor_") or line.startswith("grow_"):
        continue
    elif line.startswith("parent="):
        continue
    elif line.startswith("size_flags"):
        continue
    elif line.startswith("script ="):
        continue
    elif line.startswith("[gd_scene") or line.startswith("[ext_resource"):
        continue
    elif line.strip() == "":
        if not skip_node:
            out.append("\n")
    else:
        if not skip_node:
            out.append(line)

with open("upgrade_menu_free.tscn", "w") as f:
    f.writelines(out)
