extends Node

const HERO_ABILITIES_SCRIPT = preload("res://hero_abilities.gd")
const HERO_BALANCE_SCRIPT = preload("res://hero_balance_controller.gd")

func _ready() -> void:
	get_tree().node_added.connect(_try_attach)
	call_deferred("_scan_players")

func _scan_players() -> void:
	for node in get_tree().root.find_children("Player", "CharacterBody2D", true, false):
		_try_attach(node)

func _try_attach(node: Node) -> void:
	if not is_instance_valid(node) or node.name != "Player" or not (node is CharacterBody2D):
		return
	if node.get_node_or_null("HeroAbilities") == null:
		var ability_controller := Node.new()
		ability_controller.name = "HeroAbilities"
		ability_controller.set_script(HERO_ABILITIES_SCRIPT)
		node.add_child(ability_controller)
	if node.get_node_or_null("HeroBalanceController") == null:
		var balance_controller := Node.new()
		balance_controller.name = "HeroBalanceController"
		balance_controller.set_script(HERO_BALANCE_SCRIPT)
		node.add_child(balance_controller)
