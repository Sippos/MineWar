import re

with open("upgrade_menu_free.tscn", "r") as f:
    lines = f.readlines()

nodes = {} # path -> {type, x, y, width, height, text}
current_node_path = ""
current_node = {}

for line in lines:
    line = line.strip()
    if line.startswith("[node name="):
        m = re.search(r'name="([^"]+)".*?type="([^"]+)"', line)
        p = re.search(r'parent="([^"]+)"', line)
        if m:
            name = m.group(1)
            ntype = m.group(2)
            parent = p.group(1) if p else ""
            if parent == "":
                path = name
            elif parent == ".":
                path = name
            else:
                path = parent + "/" + name
            # Godot .tscn allows duplicate names if they are unique_id, but usually path is unique
            # wait, if they copy pasted, there might be duplicate paths like GoldPileIcon3/GoldPileIcon3!
            # Let's just store a list of nodes
            current_node = {"name": name, "type": ntype, "parent": parent, "x":0, "y":0, "w":0, "h":0, "text":""}
            nodes[len(nodes)] = current_node
    elif line.startswith("offset_left ="):
        current_node["x"] = float(line.split("=")[1])
    elif line.startswith("offset_top ="):
        current_node["y"] = float(line.split("=")[1])
    elif line.startswith("offset_right ="):
        current_node["w"] = float(line.split("=")[1]) - current_node["x"]
    elif line.startswith("offset_bottom ="):
        current_node["h"] = float(line.split("=")[1]) - current_node["y"]
    elif line.startswith("text ="):
        current_node["text"] = line.split("=")[1].strip().strip('"')
    elif line.startswith("position = Vector2"):
        parts = line.split("Vector2(")[1].split(")")[0].split(",")
        current_node["x"] = float(parts[0])
        current_node["y"] = float(parts[1])

# resolve globals
# This is tricky because of duplicate names in parent string. We'll approximate by finding the last seen node with the exact name.
# Actually, parent path in tscn is exact. "GoldPileIcon3/GoldPileIcon3"
path_to_node = {}
for i, n in nodes.items():
    if n["parent"] == "." or n["parent"] == "":
        n["path"] = n["name"]
    else:
        n["path"] = n["parent"] + "/" + n["name"]
    
    # store in path_to_node (overwrite is fine for now, or use list)
    if n["path"] not in path_to_node:
        path_to_node[n["path"]] = []
    path_to_node[n["path"]].append(n)

# compute globals
for i, n in nodes.items():
    gx = n["x"]
    gy = n["y"]
    parent_path = n["parent"]
    while parent_path and parent_path != ".":
        # find parent node
        if parent_path in path_to_node:
            pnode = path_to_node[parent_path][0] # take first matching
            gx += pnode["x"]
            gy += pnode["y"]
            parent_path = pnode["parent"]
        else:
            break
    n["gx"] = gx
    n["gy"] = gy

for i, n in nodes.items():
    print(f"{n['name']} ({n['type']}) - Global: ({n['gx']}, {n['gy']}) - Text: {n['text']}")

