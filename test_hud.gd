extends SceneTree

func _init():
    var bar = TextureProgressBar.new()
    bar.texture_over = preload("res://assets/sprites/ui/common/stats/Healthbar.png")
    bar.texture_progress = preload("res://assets/sprites/ui/hud/HealthBarRed.png")
    bar.texture_progress_offset = Vector2(64, 30)
    bar.scale = Vector2(0.5, 0.5)
    bar.value = 100
    bar.nine_patch_stretch = false
    print("Texture over size: ", bar.texture_over.get_size())
    print("Texture progress size: ", bar.texture_progress.get_size())
    print("Bar size after creation: ", bar.size)
    quit()
