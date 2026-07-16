@tool
extends McpTestSuite

func suite_name() -> String:
	return "lexicon_bases"

func test_lexicon_scene_has_a_base_collection_section() -> void:
	var scene := load("res://scenes/menus/lexicon/lexikon.tscn") as PackedScene
	assert_true(scene != null, "The bestiary scene should load")
	var instance := scene.instantiate()
	track(instance)
	assert_true(instance.has_node("VBoxContainer/ScrollContainer/VBoxContainer/BasesLabel"), "The bestiary should include a Bases heading")
	assert_true(instance.has_node("VBoxContainer/ScrollContainer/VBoxContainer/BasesGrid"), "The bestiary should include a grid for base entries")

func test_all_authored_base_sprites_are_registered() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/menus/lexicon/lexikon.gd")
	assert_true(source.contains("const BASE_ENTRIES"), "The bestiary should define its base collection")
	assert_true(source.contains("func populate_bases()"), "The base collection should populate its own grid")
	assert_true(source.contains("func create_base_entry"), "Bases should render as dedicated labelled cards")
	for texture_name in ["DwarfBase.png", "ShamanBase.png", "NerubianBase.png", "DruidBase.png", "UndeadKingBase.png"]:
		assert_true(source.contains(texture_name), "%s should be represented in the bestiary" % texture_name)

func test_lexicon_script_compiles_with_base_art_references() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/menus/lexicon/lexikon.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "The bestiary script must compile")
	assert_true(source.contains("Unknown base"), "Locked bases should explain how they are revealed")
	assert_true(source.contains("Global.is_hero_playable_in_single_player"), "Playable hero bases should be revealed consistently")
