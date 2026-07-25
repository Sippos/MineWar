extends "res://scripts/systems/world_generation/world_terrain_runtime.gd"

## Gem visual / indicator layer on top of the terrain runtime.
## Currently a thin extension point — gem border/front art lives in the
## parent TileSet sources (22 / 24) and the shared rock corner rim (25).
## Add gem-specific runtime polish here if needed (sparkle, pulse, etc.).

func _ready() -> void:
	super._ready()
