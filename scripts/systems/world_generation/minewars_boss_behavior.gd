extends Node

# Lightweight phase driver for the MineWars finale. The regular enemy script
# still owns movement and combat; this component only announces health phases
# and asks the expedition controller to reshape the assault.

var boss: Node
var expedition_controller: Node
var phase_one_triggered := false
var phase_two_triggered := false

func configure(owner_boss: Node, controller: Node) -> void:
	boss = owner_boss
	expedition_controller = controller
	set_process(true)

func _process(_delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		queue_free()
		return
	if expedition_controller == null or not is_instance_valid(expedition_controller):
		return
	var maximum := maxf(float(boss.get("max_health")), 1.0)
	var ratio := float(boss.get("health")) / maximum
	if not phase_one_triggered and ratio <= 0.68:
		phase_one_triggered = true
		expedition_controller.call_deferred("_on_boss_phase_shift", 1, boss)
	elif not phase_two_triggered and ratio <= 0.34:
		phase_two_triggered = true
		expedition_controller.call_deferred("_on_boss_phase_shift", 2, boss)
