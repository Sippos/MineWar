with open("upgrade_menu_free.tscn", "r") as f:
    lines = f.readlines()

out = []
for line in lines:
    if line.startswith("[gd_scene "):
        out.append(line)
        out.append('\n[ext_resource type="Script" path="res://upgrade_menu.gd" id="1_script"]\n')
    elif line.startswith("[node name=\"UpgradeMenuFree\" type=\"Control\""):
        out.append('[node name="UpgradeMenu" type="CanvasLayer"]\n')
        out.append('script = ExtResource("1_script")\n\n')
        out.append('[node name="Panel" type="Control" parent="."]\n')
        out.append('visible = false\n')
        out.append('layout_mode = 3\n')
        out.append('anchors_preset = 15\n')
        out.append('anchor_right = 1.0\n')
        out.append('anchor_bottom = 1.0\n')
        out.append('grow_horizontal = 2\n')
        out.append('grow_vertical = 2\n')
    elif line.startswith("layout_mode = 3") or line.startswith("anchors_preset = 15") or line.startswith("anchor_right = 1.0") or line.startswith("anchor_bottom = 1.0") or line.startswith("grow_horizontal = 2") or line.startswith("grow_vertical = 2"):
        continue # skip the old root control properties
    elif line.startswith("[node "):
        # Replace parent="." with parent="Panel"
        line = line.replace('parent="."', 'parent="Panel"')
        out.append(line)
    else:
        out.append(line)

connections = """
[connection signal="pressed" from="Panel/UnlockHealthbar" to="." method="_on_unlock_healthbar_pressed"]
[connection signal="pressed" from="Panel/UnlockBaseHealth" to="." method="_on_unlock_base_health_pressed"]
[connection signal="pressed" from="Panel/UnlockWaveTimer" to="." method="_on_unlock_wave_timer_pressed"]
[connection signal="pressed" from="Panel/UnlockXP" to="." method="_on_unlock_xp_pressed"]
[connection signal="pressed" from="Panel/UnlockStats" to="." method="_on_unlock_stats_pressed"]
[connection signal="pressed" from="Panel/UnlockMinimap" to="." method="_on_unlock_minimap_pressed"]
[connection signal="pressed" from="Panel/UpgradeMinimap" to="." method="_on_upgrade_minimap_pressed"]
[connection signal="pressed" from="Panel/UpgradeMaxHealth" to="." method="_on_upgrade_max_health_pressed"]
[connection signal="pressed" from="Panel/HealPlayer" to="." method="_on_heal_player_pressed"]
[connection signal="pressed" from="Panel/UpgradeStrength" to="." method="_on_upgrade_strength_pressed"]
[connection signal="pressed" from="Panel/UpgradeAgility" to="." method="_on_upgrade_agility_pressed"]
[connection signal="pressed" from="Panel/UpgradeIntelligence" to="." method="_on_upgrade_intelligence_pressed"]
[connection signal="pressed" from="Panel/UpgradeSpikes" to="." method="_on_upgrade_spikes_pressed"]
[connection signal="pressed" from="Panel/SwapHero" to="." method="_on_swap_hero_pressed"]
[connection signal="pressed" from="Panel/BuyRail" to="." method="_on_buy_rail_pressed"]
[connection signal="pressed" from="Panel/BuyMinecart" to="." method="_on_buy_minecart_pressed"]
[connection signal="pressed" from="Panel/BuyPeon" to="." method="_on_buy_peon_pressed"]
[connection signal="pressed" from="Panel/Close" to="." method="_on_close_pressed"]
"""

out.append(connections)

with open("upgrade_menu.tscn", "w") as f:
    f.writelines(out)

