import re

# Update upgrade_menu.gd
with open('upgrade_menu.gd', 'r') as f:
    gd_content = f.read()

new_texts_logic = """\tvar int_cost = get_upgrade_cost(player.intelligence)
\t$Panel/VBoxContainer/GridContainer/UpgradeIntelligence.text = "%d Gems" % int_cost
\t
\tvar base = get_parent().get_node_or_null("Base")
\tvar spikes_level = base.spikes_level if base else 0
\t$Panel/VBoxContainer/GridContainer/UpgradeSpikes.text = "Upgrade Spikes (Lvl %d) - 20 Gold" % spikes_level"""

gd_content = gd_content.replace(
    '\tvar int_cost = get_upgrade_cost(player.intelligence)\n\t$Panel/VBoxContainer/GridContainer/UpgradeIntelligence.text = "%d Gems" % int_cost',
    new_texts_logic
)

new_func = """func _on_upgrade_spikes_pressed():
\tif hud.total_gold >= 20:
\t\thud.add_gold(-20)
\t\tvar base = get_parent().get_node_or_null("Base")
\t\tif base:
\t\t\tbase.spikes_level += 1
\t\t\tupdate_button_texts()

func _on_swap_hero_pressed():"""

gd_content = gd_content.replace('func _on_swap_hero_pressed():', new_func)

with open('upgrade_menu.gd', 'w') as f:
    f.write(gd_content)


# Update upgrade_menu.tscn
with open('upgrade_menu.tscn', 'r') as f:
    tscn_content = f.read()

button_node = """[node name="UpgradeSpikes" type="Button" parent="Panel/VBoxContainer/GridContainer"]
layout_mode = 2
size_flags_horizontal = 3
text = "Upgrade Spikes (Lvl 0) - 20 Gold"

[node name="SwapHero" type="Button" parent="Panel/VBoxContainer/GridContainer"]"""

tscn_content = tscn_content.replace('[node name="SwapHero" type="Button" parent="Panel/VBoxContainer/GridContainer"]', button_node)

signal_conn = """[connection signal="pressed" from="Panel/VBoxContainer/GridContainer/UpgradeSpikes" to="." method="_on_upgrade_spikes_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/GridContainer/SwapHero" to="." method="_on_swap_hero_pressed"]"""

tscn_content = tscn_content.replace('[connection signal="pressed" from="Panel/VBoxContainer/GridContainer/SwapHero" to="." method="_on_swap_hero_pressed"]', signal_conn)

with open('upgrade_menu.tscn', 'w') as f:
    f.write(tscn_content)

print("Spikes added to upgrade menu.")
