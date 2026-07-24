extends Node

## Ensures Base.upgrade_requested always opens UpgradeMenu.show_menu in every
## runtime world (Siege, Exploration, Breach, VS). Preparation hubs keep their
## own deliberate disable path.

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")


func _scan_tree() -> void:
	if not is_inside_tree():
		return
	_attach_in_tree(get_tree().root)


func _on_node_added(_node: Node) -> void:
	call_deferred("_scan_tree")


func _attach_in_tree(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_try_attach_level(node)
	for child in node.get_children():
		_attach_in_tree(child)


func _try_attach_level(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Only attach on actual run worlds that carry both Base and UpgradeMenu.
	var base := node.get_node_or_null("Base")
	var upgrade_menu := node.get_node_or_null("UpgradeMenu")
	if base == null or upgrade_menu == null:
		return
	if bool(node.get_meta("upgrade_menu_signal_attached", false)):
		return
	# Preparation hubs intentionally disable the forge prompt.
	if bool(node.get_meta("single_player_hub_active", false)):
		return
	if node.get("preparation_mode") == true or node.get("preparation_active") == true:
		return
	if not base.has_signal("upgrade_requested"):
		return
	if not upgrade_menu.has_method("show_menu"):
		return

	node.set_meta("upgrade_menu_signal_attached", true)

	# Re-enable process/input in case a previous hub disabled the menu.
	upgrade_menu.set_process(true)
	upgrade_menu.set_process_input(true)
	base.set_process(true)
	base.set_process_input(true)

	var callable := Callable(upgrade_menu, "show_menu")
	if not base.upgrade_requested.is_connected(callable):
		base.upgrade_requested.connect(callable)
