with open('scripts/systems/world_generation/world_terrain_runtime.gd', 'r') as f:
    content = f.read()

content = content.replace(
"""	12: "res://assets/sprites/world/terrain/dome/Hard_Front_Face.png",
	13: "res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg",""",
"""	12: "res://assets/sprites/world/terrain/dome/Hard_Front_Face.png",
	15: "res://assets/sprites/world/terrain/dome/Unmineable_Front_Face.png",
	13: "res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg",""")

with open('scripts/systems/world_generation/world_terrain_runtime.gd', 'w') as f:
    f.write(content)

with open('scripts/systems/world_generation/world.gd', 'r') as f:
    content2 = f.read()

content2 = content2.replace(
"""			var front_id = 10 # Easy Front
			if block_id == 2: front_id = 11
			elif block_id == 3: front_id = 12""",
"""			var front_id = 10 # Easy Front
			if block_id == 2: front_id = 11
			elif block_id == 3: front_id = 12
			elif block_id == 16: front_id = 15""")

with open('scripts/systems/world_generation/world.gd', 'w') as f:
    f.write(content2)
