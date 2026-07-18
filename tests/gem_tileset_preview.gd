extends Node2D

const FACTORY = preload("res://scripts/systems/preparation/gem_indicator_texture_factory.gd")
const EDGE_PATH := "res://assets/sprites/world/terrain/gem_embedded_edge.svg"
const FRONT_PATH := "res://assets/sprites/world/terrain/gem_embedded_front.svg"

func _ready() -> void:
	var edge_texture := FACTORY.load_svg_texture(EDGE_PATH)
	var front_texture := FACTORY.load_svg_texture(FRONT_PATH)
	$NewGemTop.texture = edge_texture
	$NewGemSide.texture = edge_texture
	$FrontGem.texture = front_texture
