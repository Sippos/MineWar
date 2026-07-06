import re

with open('upgrade_menu.gd', 'r') as f:
    content = f.read()

content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UpgradeStrength',
    '$Panel/VBoxContainer/MainContent/Stats_Branch/UpgradeStrength'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UpgradeAgility',
    '$Panel/VBoxContainer/MainContent/Stats_Branch/UpgradeAgility'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UpgradeIntelligence',
    '$Panel/VBoxContainer/MainContent/Stats_Branch/UpgradeIntelligence'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UpgradeSpikes',
    '$Panel/VBoxContainer/MainContent/Misc_Branch/UpgradeSpikes'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/SwapHero',
    '$Panel/VBoxContainer/MainContent/Misc_Branch/SwapHero'
)

content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UnlockHealthbar',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockHealthbar'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UnlockBaseHealth',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockBaseHealth'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UnlockStats',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockStats'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UnlockWaveTimer',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockWaveTimer'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UnlockXP',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockXP'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UnlockMinimap',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockMinimap'
)
content = content.replace(
    '$Panel/VBoxContainer/GridContainer/UpgradeMinimap',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UpgradeMinimap'
)

heal_func = """
func _on_heal_player_pressed():
\tif hud.total_gold >= 10 and player.health < player.max_health:
\t\thud.add_gold(-10)
\t\tplayer.health = min(player.health + 20, player.max_health)
\t\thud.update_player_health(player.health, player.max_health)
"""

if "_on_heal_player_pressed" not in content:
    content += heal_func

with open('upgrade_menu.gd', 'w') as f:
    f.write(content)

print("Patched upgrade_menu.gd")
