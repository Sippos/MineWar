@tool
extends McpTestSuite

class ResourceHud:
	extends Node
	var total_gems := 0
	var total_gold := 0

class ResourcePlayer:
	extends Node
	var strength := 1
	var agility := 1
	var intelligence := 1

class TestWorld:
	extends Node2D
	var is_vs_mode := false
	var player_id := 1

func suite_name() -> String:
	return "base_prompt"

func _make_fixture() -> Dictionary:
	var world := TestWorld.new()
	track(world)
	var hud := ResourceHud.new()
	hud.name = "HUD"
	world.add_child(hud)
	var player := ResourcePlayer.new()
	player.name = "Player"
	world.add_child(player)
	var base_script := GDScript.new()
	base_script.source_code = FileAccess.get_file_as_string("res://base.gd")
	base_script.reload()
	var base := base_script.new() as Area2D
	world.add_child(base)
	return {"world": world, "hud": hud, "player": player, "base": base}

func test_base_upgrade_prompt_requires_an_affordable_action() -> void:
	var fixture := _make_fixture()
	var base: Area2D = fixture["base"]
	var hud: Node = fixture["hud"]
	var player: Node = fixture["player"]
	assert_false(base.call("_can_afford_any_base_action"), "An empty starting inventory should not advertise upgrades")

	hud.set("total_gems", 1)
	assert_true(base.call("_can_afford_any_base_action"), "One gem should afford a level-one stat upgrade")

	player.set("strength", 2)
	player.set("agility", 2)
	player.set("intelligence", 2)
	assert_false(base.call("_can_afford_any_base_action"), "The prompt should hide when the next stat costs more than the current gems")

	hud.set("total_gold", 10)
	assert_true(base.call("_can_afford_any_base_action"), "Ten gold should afford at least one base action")

func test_vs_mode_keeps_base_options_prompt_available() -> void:
	var fixture := _make_fixture()
	var world: Node = fixture["world"]
	var base: Area2D = fixture["base"]
	world.set("is_vs_mode", true)
	assert_true(base.call("_can_afford_any_base_action"), "VS mode should preserve access to the Base Options prompt")
