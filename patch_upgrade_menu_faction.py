import re

tscn_path = "upgrade_menu.tscn"
with open(tscn_path, "r") as f:
    tscn = f.read()

faction_nodes = """[node name="FactionTitle" parent="Panel/VBoxContainer/ScrollContainer/MainContent" type="Label"]
layout_mode = 2
text = "-- Faction Updates --"
horizontal_alignment = 1

[node name="Faction_Branch" parent="Panel/VBoxContainer/ScrollContainer/MainContent" type="HBoxContainer"]
layout_mode = 2
alignment = 1

[node name="BuyRail" parent="Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch" type="Button"]
layout_mode = 2
text = "Buy Rail (10 Gold)"

[node name="BuyMinecart" parent="Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch" type="Button"]
layout_mode = 2
text = "Buy Minecart (50 Gold)"

[node name="BuyPeon" parent="Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch" type="Button"]
layout_mode = 2
text = "Buy Peon (30 Gold)"
"""

faction_signals = """[connection signal="pressed" from="Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch/BuyRail" to="." method="_on_buy_rail_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch/BuyMinecart" to="." method="_on_buy_minecart_pressed"]
[connection signal="pressed" from="Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch/BuyPeon" to="." method="_on_buy_peon_pressed"]
"""

if "FactionTitle" not in tscn:
    # Insert nodes right before CloseContainer
    close_container_idx = tscn.find('[node name="CloseContainer"')
    tscn = tscn[:close_container_idx] + faction_nodes + "\n" + tscn[close_container_idx:]
    
    # Insert signals at the end
    tscn += "\n" + faction_signals
    
    with open(tscn_path, "w") as f:
        f.write(tscn)
    print("Patched tscn.")


gd_path = "upgrade_menu.gd"
with open(gd_path, "r") as f:
    gd = f.read()

update_button_texts_patch = """	var is_dwarf = (Global.current_hero == "Dwarf")
	var is_shaman = (Global.current_hero == "Shaman")
	
	$Panel/VBoxContainer/ScrollContainer/MainContent/FactionTitle.visible = is_dwarf or is_shaman
	$Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch.visible = is_dwarf or is_shaman
	$Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch/BuyRail.visible = is_dwarf
	$Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch/BuyMinecart.visible = is_dwarf
	$Panel/VBoxContainer/ScrollContainer/MainContent/Faction_Branch/BuyPeon.visible = is_shaman
"""

if "is_dwarf =" not in gd:
    idx = gd.find("	$Panel/VBoxContainer/ScrollContainer/MainContent/Misc_Branch/SwapHero.text =")
    end_idx = gd.find("\n", idx)
    gd = gd[:end_idx+1] + update_button_texts_patch + gd[end_idx+1:]
    
    # Add handler functions
    handlers = """
func _on_buy_rail_pressed():
	if hud.total_gold >= 10:
		hud.add_gold(-10)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_rail"):
			base.spawn_rail()

func _on_buy_minecart_pressed():
	if hud.total_gold >= 50:
		hud.add_gold(-50)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_minecart"):
			base.spawn_minecart()

func _on_buy_peon_pressed():
	if hud.total_gold >= 30:
		hud.add_gold(-30)
		var base = get_parent().get_node_or_null("Base")
		if base and base.has_method("spawn_peon"):
			base.spawn_peon()
"""
    gd += handlers
    
    with open(gd_path, "w") as f:
        f.write(gd)
    print("Patched gd.")
