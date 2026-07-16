@tool
extends McpTestSuite

func suite_name() -> String:
	return "upgrade_card_ui"

func _label_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for node in root.find_children("*", "Label", true, false):
		texts.append(str(node.text))
	return texts

func test_level_up_card_uses_explicit_icon_and_labels() -> void:
	var script := load("res://scripts/ui/menus/level_up/level_up_menu.gd") as GDScript
	var menu := script.new() as CanvasLayer
	track(menu)
	menu.set("compact", true)
	var option := {
		"id": "stomp",
		"title": "Ground Stomp",
		"description": "Area damage and stun",
		"level": 1,
		"max_level": 3,
		"enabled": true,
		"reason": "",
		"icon_path": "res://ability_icons/placeholder_stomp.svg"
	}
	var card := menu.call("_ability_card", option) as Button
	menu.add_child(card)
	assert_eq(card.text, "", "The card should not rely on Button text/icon rendering")
	var icons := card.find_children("*", "TextureRect", true, false)
	assert_true(icons.size() == 1 and icons[0].texture != null, "The ability icon should be a visible TextureRect child")
	assert_gt(icons[0].custom_minimum_size.x, 0.0, "The ability icon must keep a non-zero runtime size inside CenterContainer")
	assert_true(card.clip_contents, "Card content should remain clipped to its button bounds")
	var labels := card.find_children("*", "Label", true, false)
	assert_true(labels.size() >= 2 and labels[0].autowrap_mode != TextServer.AUTOWRAP_OFF, "Long ability headings should wrap instead of widening the card")
	var texts := _label_texts(card)
	assert_true(texts.has("Ground Stomp  Lv.1/3"), "The card should show the ability name and rank")
	assert_true(texts.has("Area damage and stun"), "The card should show the ability description")

func test_level_up_card_shows_lock_reason_and_disabled_state() -> void:
	var script := load("res://scripts/ui/menus/level_up/level_up_menu.gd") as GDScript
	var menu := script.new() as CanvasLayer
	track(menu)
	var option := {
		"id": "avatar",
		"title": "Avatar",
		"description": "Combat form",
		"level": 0,
		"max_level": 1,
		"enabled": false,
		"reason": "REQUIRES HERO LEVEL 6",
		"icon_path": "res://ability_icons/placeholder_avatar.svg"
	}
	var card := menu.call("_ability_card", option) as Button
	menu.add_child(card)
	assert_true(card.disabled, "Locked abilities should remain disabled")
	assert_true(_label_texts(card).has("REQUIRES HERO LEVEL 6"), "The lock reason should remain visible")

func test_compact_base_upgrade_card_uses_child_content() -> void:
	var script := load("res://compact_vs_upgrade_menu.gd") as GDScript
	var menu := script.new() as CanvasLayer
	track(menu)
	var card := menu.call("_button", "Base HP", "10 gold", "_unused", "res://assets/sprites/ui/upgrades/base_health.png", false) as Button
	menu.add_child(card)
	assert_eq(card.text, "", "Compact upgrade cards should use explicit child controls")
	var texts := _label_texts(card)
	assert_true(texts.has("Base HP"), "The compact card should show its title")
	assert_true(texts.has("10 gold"), "The compact card should show its cost")
	var icons := card.find_children("*", "TextureRect", true, false)
	assert_true(icons.size() == 1 and icons[0].texture != null, "The compact card should show a real icon child")

func test_compact_owned_upgrade_is_disabled_and_labeled() -> void:
	var script := load("res://compact_vs_upgrade_menu.gd") as GDScript
	var menu := script.new() as CanvasLayer
	track(menu)
	var card := menu.call("_button", "Minimap", "20 gold", "_unused", "res://assets/sprites/ui/upgrades/minimap.png", true) as Button
	menu.add_child(card)
	assert_true(card.disabled, "Already-owned upgrades should be disabled")
	assert_true(_label_texts(card).has("OWNED"), "Already-owned upgrades should be labeled instead of showing a stale price")

func test_vs_level_up_input_maps_only_the_active_players_actions() -> void:
	var script := load("res://vs_mode.gd") as GDScript
	var router := script.new() as Control
	track(router)
	assert_eq(router.call("_level_up_ui_action", "p1_down", 1), "ui_down", "Player 1 movement should navigate Player 1's card menu")
	assert_eq(router.call("_level_up_ui_action", "p1_interact", 1), "ui_accept", "Player 1 interact should confirm Player 1's focused card")
	assert_eq(router.call("_level_up_ui_action", "p2_left", 2), "ui_left", "Player 2 movement should navigate Player 2's card menu")
	assert_eq(router.call("_level_up_ui_action", "p2_interact", 2), "ui_accept", "Player 2 interact should confirm Player 2's focused card")
	assert_eq(router.call("_level_up_ui_action", "p1_down", 2), "", "Player 1 actions must not control Player 2's card menu")
	assert_eq(router.call("_level_up_ui_action", "ui_accept", 2), "ui_accept", "Standard UI accept should remain supported for controllers")
