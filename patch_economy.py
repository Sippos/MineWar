with open('upgrade_menu.gd', 'r') as f:
    content = f.read()

content = content.replace("hud.total_gems >= 5:", "hud.total_gold >= 10:")
content = content.replace("hud.add_gems(-5)", "hud.add_gold(-10)")

with open('upgrade_menu.gd', 'w') as f:
    f.write(content)

print("Economy patched.")
