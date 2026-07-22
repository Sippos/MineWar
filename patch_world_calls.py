with open('scripts/systems/world_generation/world.gd', 'r') as f:
    content = f.read()

content = content.replace("update_front_wall(cell) # Clean up this cell", "update_front_wall(cell)\n\tupdate_inside_corners(cell) # Clean up this cell")
content = content.replace("update_front_wall(n)", "update_front_wall(n)\n\t\tupdate_inside_corners(n)")
content = content.replace("update_front_wall(refresh_cell)", "update_front_wall(refresh_cell)\n\t\t\t\tupdate_inside_corners(refresh_cell)")
content = content.replace("update_front_wall(Vector2i(x, y))", "update_front_wall(Vector2i(x, y))\n\t\t\tupdate_inside_corners(Vector2i(x, y))")

with open('scripts/systems/world_generation/world.gd', 'w') as f:
    f.write(content)
