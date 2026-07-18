extends Node

func _ready() -> void:
	_fix_sound_fx()
	_fix_siege_controller()
	print("IMMERSIVE_COMPILE_FIX_OK")
	get_tree().quit(0)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		get_tree().quit(1)
		return
	file.store_string(content)
	file.close()

func _fix_sound_fx() -> void:
	var path := "res://sound_fx.gd"
	var source := FileAccess.get_file_as_string(path)
	var marker := "func play_mine_awaken() -> void:"
	var first := source.find(marker)
	var second := source.find(marker, first + marker.length()) if first >= 0 else -1
	if second >= 0:
		var next_function := source.find("func _play(", second)
		if next_function < 0:
			push_error("Could not locate end of duplicated sound methods")
			get_tree().quit(1)
			return
		source = source.left(second) + source.substr(next_function)
	_write(path, source)

func _fix_siege_controller() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	var start := source.find("func _spawn_base_signal(")
	var finish := source.find("func _pulse_entrance_marker(", start)
	if start < 0 or finish < 0:
		push_error("Could not locate bastion signal function")
		get_tree().quit(1)
		return
	var block := source.substr(start, finish - start)
	block = block.replace("var signal := Node2D.new()", "var beacon := Node2D.new()")
	block = block.replace("signal.name", "beacon.name")
	block = block.replace("signal.global_position", "beacon.global_position")
	block = block.replace("signal.z_index", "beacon.z_index")
	block = block.replace("world.add_child(signal)", "world.add_child(beacon)")
	block = block.replace("signal.add_child", "beacon.add_child")
	block = block.replace("signal.queue_free", "beacon.queue_free")
	source = source.left(start) + block + source.substr(finish)
	_write(path, source)
