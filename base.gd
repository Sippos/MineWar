extends Area2D

signal gems_deposited(amount)
signal upgrade_requested
signal base_damaged(new_health)
signal game_over

const BASE_TEXTURES = {
	"default_base": preload("res://DwarfBase.png"),
	"shaman_base": preload("res://ShamanBase.png"),
	"nerubian_base": preload("res://NerubianBase.png"),
	"druid_base": preload("res://DruidBase.png"),
	"undead_king_base": preload("res://UndeadKingBase.png")
}
const LOADOUT_SELECTION_MENU = preload("res://scenes/menus/loadout_selection_menu.tscn")
const MINIMUM_GOLD_ACTION_COST := 10
const PROMPT_TEXT := "E / Y  •  UPGRADE BASE"
const HUB_PROMPT_TEXT := "E / Y  •  CHOOSE BASE"
const DEPOSIT_PROMPT_TEXT := "RETURN HERE  •  GEMS AUTO-DEPOSIT"
const DEPOSIT_GUIDE_DISTANCE := 560.0

var max_health := 100
var health := 100
var player_in_zone = false
var spikes_level = 0
var heal_timer = 0.0
var prompt_tween: Tween
var prompt_should_show := false
var loadout_menu_open := false

@onready var prompt = $PromptLabel

func _ready() -> void:
	collision_mask |= 4 # Add layer 3 (enemies)
	prompt.text = PROMPT_TEXT
	prompt.visible = false
	prompt.modulate = Color(1, 1, 1, 0)
	prompt.pivot_offset = prompt.size * 0.5
	prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.58, 1.0))
	prompt.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	prompt.add_theme_constant_override("outline_size", 5)
	call_deferred("refresh_base_sprite")

func refresh_base_sprite() -> void:
	_apply_base_sprite(Global.selected_base_id)

func _get_player_id() -> int:
	var parent = get_parent()
	if parent == null:
		return 1
	var p_id = parent.get("player_id")
	if p_id == null:
		return 1
	return int(p_id)

func _apply_base_sprite(base_id: String) -> void:
	var tex = BASE_TEXTURES.get(base_id, BASE_TEXTURES["default_base"])
	if tex:
		$Sprite2D.texture = tex
		$Sprite2D.modulate = Color(1, 1, 1, 1)
		$Sprite2D.scale = Vector2(128.0 / tex.get_width(), 128.0 / tex.get_height())

func _is_vs_mode() -> bool:
	var world = get_parent()
	return world != null and bool(world.get("is_vs_mode"))

func _is_single_player_hub() -> bool:
	var world := get_parent()
	return world != null and bool(world.get_meta("single_player_hub_active", false))

func _get_minimum_stat_upgrade_cost(player: Node) -> int:
	if player == null:
		return 999999
	var strength_cost: int = max(int(player.get("strength")), 1) * 2 - 1
	var agility_cost: int = max(int(player.get("agility")), 1) * 2 - 1
	var intelligence_cost: int = max(int(player.get("intelligence")), 1) * 2 - 1
	return min(strength_cost, min(agility_cost, intelligence_cost))

func _can_afford_any_base_action() -> bool:
	if _is_single_player_hub() or _is_vs_mode():
		return true
	var world = get_parent()
	if world == null:
		return false
	var hud = world.get_node_or_null("HUD")
	var player = world.get_node_or_null("Player")
	if hud == null or player == null:
		return false
	var gem_cost := _get_minimum_stat_upgrade_cost(player)
	return int(hud.get("total_gems")) >= gem_cost or int(hud.get("total_gold")) >= MINIMUM_GOLD_ACTION_COST

func _set_prompt_visible(should_show: bool) -> void:
	if prompt == null or should_show == prompt_should_show:
		return
	prompt_should_show = should_show
	if prompt_tween and prompt_tween.is_running():
		prompt_tween.kill()
	if should_show:
		prompt.visible = true
		prompt.scale = Vector2(0.92, 0.92)
		prompt.modulate = Color(1, 1, 1, 0)
		prompt_tween = create_tween().set_parallel(true)
		prompt_tween.tween_property(prompt, "modulate", Color.WHITE, 0.16)
		prompt_tween.tween_property(prompt, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif prompt.visible:
		prompt_tween = create_tween()
		prompt_tween.tween_property(prompt, "modulate", Color(1, 1, 1, 0), 0.12)
		prompt_tween.tween_callback(func(): prompt.visible = false)

func _refresh_prompt_visibility() -> void:
	var world := get_parent()
	var player := world.get_node_or_null("Player") if world else null
	if _is_single_player_hub() and player_in_zone:
		prompt.text = HUB_PROMPT_TEXT
		_set_prompt_visible(true)
		return
	var carry_load := int(player.get_carry_load()) if player and player.has_method("get_carry_load") else 0
	if carry_load > 0 and player and player.global_position.distance_to(global_position) <= DEPOSIT_GUIDE_DISTANCE:
		prompt.text = DEPOSIT_PROMPT_TEXT
		_set_prompt_visible(true)
		return
	if player_in_zone and _can_afford_any_base_action():
		prompt.text = PROMPT_TEXT
		_set_prompt_visible(true)
		return
	_set_prompt_visible(false)

func _process(delta: float) -> void:
	if player_in_zone:
		var player = get_parent().get_node_or_null("Player")
		if player:
			# Heal player
			heal_timer += delta
			if heal_timer >= 1.0:
				heal_timer = 0.0
				if not player.is_dead and player.health < player.max_health:
					player.health = min(player.health + 5, player.max_health)
					var hud = get_parent().get_node_or_null("HUD")
					if hud and hud.has_method("update_player_health"):
						hud.update_player_health(player.health, player.max_health)
			
			# Auto deposit gems continuously
			if player.has_method("deposit_gems"):
				var deposited = player.deposit_gems()
				if deposited > 0:
					_emit_deposit_feedback(deposited)
					if get_parent().has_method("notify_tutorial_gems_deposited"):
						get_parent().notify_tutorial_gems_deposited(deposited)
					gems_deposited.emit(deposited)
	_refresh_prompt_visibility()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = true
		_refresh_prompt_visibility()
	elif body.is_in_group("gems"):
		# If a gem is thrown or pushed into the base directly!
		body.queue_free()
		_emit_deposit_feedback(1)
		if get_parent().has_method("notify_tutorial_gems_deposited"):
			get_parent().notify_tutorial_gems_deposited(1)
		gems_deposited.emit(1)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_zone = false
		_set_prompt_visible(false)

func _emit_deposit_feedback(amount: int) -> void:
	var deposit_sound_fx := get_node_or_null("/root/SoundFX")
	if deposit_sound_fx:
		deposit_sound_fx.play_deposit(amount)
	var world = get_parent()
	if world and world.has_method("spawn_gem_deposit_feedback"):
		world.spawn_gem_deposit_feedback(global_position, amount)

func _input(event: InputEvent) -> void:
	var p_id = get_parent().get("player_id")
	if p_id == null:
		p_id = 1
	if player_in_zone and event.is_action_pressed("p%d_interact" % p_id):
		if _is_single_player_hub():
			_open_loadout_menu()
			return
		if get_parent().has_method("notify_tutorial_upgrade_opened"):
			get_parent().notify_tutorial_upgrade_opened()
		upgrade_requested.emit()

func _open_loadout_menu() -> void:
	if loadout_menu_open:
		return
	loadout_menu_open = true
	var menu := LOADOUT_SELECTION_MENU.instantiate()
	var world := get_parent()
	var player := world.get_node_or_null("Player") if world else null
	if menu.has_method("setup"):
		menu.setup(world, player, self)
	world.add_child(menu)
	menu.tree_exited.connect(func(): loadout_menu_open = false)

func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("notify_base_damaged"):
		hud.notify_base_damaged(health, max_health)
	base_damaged.emit(health)
	if health <= 0:
		game_over.emit()

func repair(amount: int) -> void:
	health = mini(health + amount, max_health)
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_base_health"):
		hud.update_base_health(health, max_health)

func upgrade_max_health(amount: int) -> void:
	max_health += amount
	health += amount
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("update_base_health"):
		hud.update_base_health(health, max_health)

func spawn_rail():
	var item = preload("res://scenes/entities/collectibles/rail_items/rail_item.tscn").instantiate()
	item.global_position = global_position
	get_parent().call_deferred("add_child", item)

func spawn_peon():
	var peon = preload("res://scenes/entities/workers/peon/peon.tscn").instantiate()
	peon.global_position = global_position
	get_parent().call_deferred("add_child", peon)

func spawn_minecart():
	var existing = get_parent().get_node_or_null("Minecart")
	if existing:
		existing.queue_free()
	var cart = preload("res://scenes/entities/transport/minecart/minecart.tscn").instantiate()
	cart.name = "Minecart"
	cart.global_position = global_position
	get_parent().call_deferred("add_child", cart)
