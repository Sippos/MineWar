with open('upgrade_menu.gd', 'r') as f:
    content = f.read()

content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockHealthbar',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UnlockHealthbar'
)
content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockBaseHealth',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UnlockBaseHealth'
)
content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockStats',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UnlockStats'
)
content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockWaveTimer',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UnlockWaveTimer'
)
content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockXP',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UnlockXP'
)
content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UnlockMinimap',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UnlockMinimap'
)
content = content.replace(
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/UpgradeMinimap',
    '$Panel/VBoxContainer/MainContent/TopSection/HUD_Branch/TreeBranches/UpgradeMinimap'
)

with open('upgrade_menu.gd', 'w') as f:
    f.write(content)

print("Paths patched.")
