extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

const STOMP_SPRITE_TEXTURES = [
	"res://StompSprite.png",
	"res://StompSprite.webp",
	"res://StompSprite.tres",
	"res://stomp_sprite.png",
	"res://sprites/StompSprite.png",
	"res://assets/StompSprite.png"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep running while tree paused

func setup(has_stomp: bool) -> void:
	var btn_stomp = $Panel/VBoxContainer/ButtonStomp
	if has_stomp:
		btn_stomp.text = "Upgrade Stomp (Level Up)"
	else:
		btn_stomp.text = "Learn Stomp"
	_apply_stomp_sprite_to_button(btn_stomp)
	btn_stomp.call_deferred("grab_focus")

func _load_stomp_texture() -> Texture2D:
	for texture_path in STOMP_SPRITE_TEXTURES:
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture is Texture2D:
				return texture
	return null

func _apply_stomp_sprite_to_button(button: Button) -> void:
	var texture = _load_stomp_texture()
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_spacing", 12)

func _on_button_stomp_pressed() -> void:
	upgrade_selected.emit("stomp")
	hide_and_unpause()

func _on_button_health_pressed() -> void:
	upgrade_selected.emit("health")
	hide_and_unpause()

func _on_button_damage_pressed() -> void:
	upgrade_selected.emit("damage")
	hide_and_unpause()

func hide_and_unpause() -> void:
	get_tree().paused = false
	queue_free()