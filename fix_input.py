with open("player.gd", "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if line.strip().startswith("func _input(event: InputEvent) -> void:"):
        skip = True
        continue
    
    if skip:
        # Stop skipping when we reach the next function or EOF
        if line.startswith("func ") and not line.strip().startswith("func _input"):
            skip = False
        else:
            continue

    if not skip:
        new_lines.append(line)

# Now we need to insert the input logic into _physics_process
physics_idx = -1
for i, line in enumerate(new_lines):
    if line.startswith("func _physics_process(delta: float) -> void:"):
        physics_idx = i
        break

input_logic = """
	if Input.is_action_just_pressed("p%d_grab" % player_id):
		for gem in nearby_gems:
			if is_instance_valid(gem) and not carried_gems.has(gem):
				if gem.has_method("tether_to"):
					gem.tether_to(self)
				carried_gems.append(gem)
	elif Input.is_action_just_pressed("p%d_drop" % player_id):
		if carried_gems.size() > 0:
			var gem = carried_gems.pop_back()
			if is_instance_valid(gem) and gem.has_method("untether"):
				gem.untether()
"""

new_lines.insert(physics_idx + 1, input_logic)

with open("player.gd", "w") as f:
    f.writelines(new_lines)

print("Fixed player.gd")
