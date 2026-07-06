import re

with open('enemy.gd', 'r') as f:
    content = f.read()

# Add attack_cooldown_timer
content = content.replace(
    'var current_anim_row = 0',
    'var current_anim_row = 0\nvar attack_cooldown_timer = 0.0'
)

new_physics_process = """func _physics_process(delta: float):
\tpath_timer += delta
\tif path_timer > 1.0:
\t\trecalculate_path()
\t\tpath_timer = 0.0
\t
\tif attack_cooldown_timer > 0.0:
\t\tattack_cooldown_timer -= delta
\t
\tvar is_attacking_base = false
\tfor i in get_slide_collision_count():
\t\tvar col = get_slide_collision(i)
\t\tvar collider = col.get_collider()
\t\tif collider == base:
\t\t\tis_attacking_base = true
\t
\tif base and global_position.distance_to(base.global_position) < 35.0:
\t\tis_attacking_base = true

\tif is_attacking_base:
\t\tvelocity = Vector2.ZERO
\t\tvar sprite = $Sprite2D
\t\tif sprite:
\t\t\twalk_timer = 0.0
\t\t\tsprite.frame = current_anim_row * 8
\t\t
\t\tif attack_cooldown_timer <= 0.0:
\t\t\tif base.has_method("take_damage"):
\t\t\t\tbase.take_damage(damage)
\t\t\tif "spikes_level" in base and base.spikes_level > 0:
\t\t\t\ttake_damage(15 * base.spikes_level)
\t\t\tattack_cooldown_timer = 1.0
\telif path.size() > 0 and current_path_index < path.size():
\t\tvar target_pos = path[current_path_index]
\t\tvar dir = (target_pos - global_position).normalized()
\t\tvar dist = global_position.distance_to(target_pos)
\t\t
\t\tif dist < 5.0:
\t\t\tcurrent_path_index += 1
\t\telse:
\t\t\tvelocity = dir * speed
\t\t\tmove_and_slide()
\t\t\t
\t\t\t# Animation logic
\t\t\tvar angle = dir.angle()
\t\t\tvar PI_8 = PI / 8.0
\t\t\tif angle > -PI_8 and angle <= PI_8:
\t\t\t\tcurrent_anim_row = 6 # Right
\t\t\telif angle > PI_8 and angle <= 3*PI_8:
\t\t\t\tcurrent_anim_row = 7 # Down-Right
\t\t\telif angle > 3*PI_8 and angle <= 5*PI_8:
\t\t\t\tcurrent_anim_row = 0 # Down
\t\t\telif angle > 5*PI_8 and angle <= 7*PI_8:
\t\t\t\tcurrent_anim_row = 1 # Down-Left
\t\t\telif angle > 7*PI_8 or angle <= -7*PI_8:
\t\t\t\tcurrent_anim_row = 2 # Left
\t\t\telif angle > -7*PI_8 and angle <= -5*PI_8:
\t\t\t\tcurrent_anim_row = 3 # Up-Left
\t\t\telif angle > -5*PI_8 and angle <= -3*PI_8:
\t\t\t\tcurrent_anim_row = 4 # Up
\t\t\telif angle > -3*PI_8 and angle <= -PI_8:
\t\t\t\tcurrent_anim_row = 5 # Up-Right
\t\t\t\t
\t\t\tvar sprite = $Sprite2D
\t\t\tif sprite:
\t\t\t\twalk_timer += delta * 12.0
\t\t\t\tsprite.frame = current_anim_row * 8 + (int(walk_timer) % 8)
\t\t\t
\t\t\tfor i in get_slide_collision_count():
\t\t\t\tvar col = get_slide_collision(i)
\t\t\t\tvar collider = col.get_collider()
\t\t\t\tif collider.name == "Player":
\t\t\t\t\tif collider.has_method("take_damage"):
\t\t\t\t\t\tcollider.take_damage(damage)
\telse:
\t\trecalculate_path()
\t\tvar sprite = $Sprite2D
\t\tif sprite:
\t\t\twalk_timer = 0.0
\t\t\tsprite.frame = current_anim_row * 8"""

# Find _physics_process and replace up to take_damage
start_idx = content.find('func _physics_process')
end_idx = content.find('func take_damage')

content = content[:start_idx] + new_physics_process + '\n\n' + content[end_idx:]

with open('enemy.gd', 'w') as f:
    f.write(content)

print("enemy.gd updated.")
