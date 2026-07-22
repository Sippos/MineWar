extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const CANVAS_PATH := "res://tools/sprite_lab/dome_material_canvas.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14
const PATCH_ORIGIN := Vector2i(LOGICAL_SIZE - PATCH_SIZE, LOGICAL_SIZE - PATCH_SIZE)
const TIERS: Array[String] = ["easy", "medium", "hard", "unmineable