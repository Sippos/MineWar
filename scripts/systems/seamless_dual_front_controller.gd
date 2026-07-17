extends "res://scripts/systems/dual_front_controller.gd"

const SEAMLESS_SURFACE_POSITION := Vector2(0.0, -680.0)
const SEAMLESS_BOARD_RECT := Rect2(-408.0, -180.0, 816.0, 360.0)
const ENTRY_RETURN_MARGIN := 80.0

func _setup() -> void:
	super._setup()
	if surface_maze and is_instance_valid(surface_maze):
		# Place the LineWars field physically above the preparation room. Its lower
		# portal now meets the shaft the peon just carved instead of existing as a
		# disconnected board elsewhere in the mine scene.
		surface_maze.position = SEAMLESS_SURFACE_POSITION

func _begin_dual_front_run() -> void:
	run_started = true

	# Preserve the peon's breakthrough position. The movement bounds include the
	# full board plus a short return lip below its portal, so the player can walk
	# straight from the freshly dug shaft onto the battlefield without a snap.
	var board_top_left := surface_maze.to_global(SEAMLESS_BOARD_RECT.position)
	var board_bottom := board_top_left.y + SEAMLESS_BOARD_RECT.size.y
	var entry_bottom := maxf(board_bottom + ENTRY_RETURN_MARGIN, builder_peon.global_position.y + 48.0)
	builder_peon.set("movement_bounds", Rect2(
		board_top_left,
		Vector2(SEAMLESS_BOARD_RECT.size.x, entry_bottom - board_top_left.y)
	))

	hero.position = HERO_MINE_START
	hero.velocity = Vector2.ZERO
	dual_front_hud.visible = true
	active_front = Front.PEON
	_apply_front_control()

	# Unlike switching between fronts, this handoff intentionally keeps the held
	# Up input: the same movement that dug the shaft carries the peon through the
	# lower portal and onto the board.
	builder_peon.set("awaiting_neutral_input", false)
	last_surface_status = "Breakthrough complete. Keep moving north onto the board, then carve the longest route you can."
	_update_interface()
